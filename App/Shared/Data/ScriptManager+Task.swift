//
//  Persistence+Tasks.swift
//  App
//
//  Created by Lucka on 2023-09-19.
//

import Foundation
import SwiftData

extension ScriptManager {
    enum BuildChannel: String, CaseIterable {
        case release = "release"
        case beta = "beta"
    }
}

extension ScriptManager {
    func updateScripts(reporting progress: Progress, currentMainScriptVersion: String?) async throws {
        defer {
            progress.completedUnitCount = 0
        }
        
        try Self.ensureInternalDirectories()
        
        let internalPlugins = try internalPluginNames
        
        let externalPlugins = try allUpdatableExternalPlugins
        
        progress.completedUnitCount = 0
        progress.totalUnitCount = .init(1 + internalPlugins.count + externalPlugins.count)
        
        let externalURL = UserDefaults.shared.externalScriptsBookmarkURL
        var accessingSecurityScopedResource = false
        defer {
            if accessingSecurityScopedResource {
                externalURL?.stopAccessingSecurityScopedResource()
            }
        }
        
        let channel = UserDefaults.shared.buildChannel
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await Self.downloadMainScript(from: channel, currentVersion: currentMainScriptVersion)
                await MainActor.run { progress.completedUnitCount += 1 }
            }
            
            for filename in internalPlugins {
                group.addTask {
                    try await self.downloadInternalPlugin(filename, from: channel)
                    await MainActor.run { progress.completedUnitCount += 1 }
                }
            }
            
            if !externalPlugins.isEmpty, let externalURL {
                accessingSecurityScopedResource = externalURL.startAccessingSecurityScopedResource()
                for plugin in externalPlugins {
                    group.addTask {
                        try await self.updateExternal(plugin: plugin, in: externalURL)
                        await MainActor.run { progress.completedUnitCount += 1 }
                    }
                }
            }
            
            try await group.waitForAll()
        }
        
        try modelContext.save()
    }
}

extension ScriptManager {
    static func ensureInternalDirectories() throws {
        let fileManager = FileManager.default
        let internalScriptsDirectoryURL = fileManager.internalScriptsDirectoryURL
        if !fileManager.fileExists(at: internalScriptsDirectoryURL) {
            try fileManager.createDirectory(at: internalScriptsDirectoryURL, withIntermediateDirectories: true)
        }
        let internalPluginsDirectoryURL = fileManager.internalPluginsDirectoryURL
        if !fileManager.fileExists(at: internalPluginsDirectoryURL) {
            try fileManager.createDirectory(at: internalPluginsDirectoryURL, withIntermediateDirectories: true)
        }
    }
    
    static func downloadMainScript(from channel: BuildChannel, currentVersion: String?) async throws {
        let scriptURL = Self.websiteBuildURL
            .appending(path: channel.rawValue)
            .appending(path: FileConstants.mainScriptFilename)
        if let currentVersion {
            // Check version from metadata
            guard await checkUpdate(
                from: scriptURL.appendingPathExtension(FileConstants.scriptMetadataExtension),
                currentVersion: currentVersion
            ) else {
                return
            }
        }

        let temporaryURL = try await URLSession.shared.download(
            from: scriptURL.appendingPathExtension(FileConstants.userScriptExtension)
        )
        
        let fileManager = FileManager.default
        var succeed = false
        defer {
            if !succeed {
                try? fileManager.removeItem(at: temporaryURL)
            }
        }
        
        let content = try String(contentsOf: temporaryURL)
        let _ = try UserScriptMetadataDecoder().decode(MainScriptMetadata.self, from: content)
        
        let mainScriptURL = fileManager.mainScriptURL
        if fileManager.fileExists(at: mainScriptURL) {
            try fileManager.removeItem(at: mainScriptURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: mainScriptURL)
        succeed = true
    }
    
    func downloadInternalPlugin(_ filename: String, from channel: BuildChannel) async throws {
        let predicate = #Predicate<Plugin> {
            $0.isInternal && $0.filename == filename
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        let item = try modelContext.fetch(descriptor).first
        
        let pluginURL = Self.websiteBuildURL
            .appending(path: channel.rawValue)
            .appending(path: "plugins")
            .appending(path: filename)
        if let currentVersion = item?.version {
            // Check version from metadata
            guard await Self.checkUpdate(
                from: pluginURL.appendingPathExtension(FileConstants.scriptMetadataExtension),
                currentVersion: currentVersion
            ) else {
                return
            }
        }
        
        let temporaryURL = try await URLSession.shared.download(
            from: pluginURL.appendingPathExtension(FileConstants.userScriptExtension)
        )
        
        let fileManager = FileManager.default
        var succeed = false
        defer {
            if !succeed {
                try? fileManager.removeItem(at: temporaryURL)
            }
        }
        
        let content = try String(contentsOf: temporaryURL)
        let metadata = try UserScriptMetadataDecoder().decode(PluginMetadata.self, from: content)
        
        let destinationURL = fileManager.internalPluginsDirectoryURL
            .appending(path: filename)
            .appendingPathExtension(FileConstants.userScriptExtension)
        if fileManager.fileExists(at: destinationURL) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        
        if let item {
            item.update(from: metadata)
        } else {
            let item = Plugin(metadata: metadata, isInternal: true, filename: filename)
            modelContext.insert(item)
        }
        
        succeed = true
    }
}

fileprivate extension ScriptManager {
    var internalPluginNames: [ String ] {
        get throws {
            try JSONDecoder().decode(
                [ String ].self,
                from: try Data(
                    contentsOf: Bundle.main.url(
                        forResource: "InternalPlugins", withExtension: "json"
                    )!
                )
            )
        }
    }
}

fileprivate extension ScriptManager {
    static var websiteBuildURL: URL { .init(string: "https://iitc.app/build/")! }
    
    private func updateExternal(plugin: Plugin, in externalURL: URL) async throws {
        if let updateURL = plugin.updateURL {
            // Check version from update URL
            guard await Self.checkUpdate(from: updateURL, currentVersion: plugin.version) else {
                return
            }
        }
        
        guard let downloadURL = plugin.downloadURL else { return }
        let temporaryURL = try await URLSession.shared.download(from: downloadURL)

        let fileManager = FileManager.default
        defer { try? fileManager.removeItem(at: temporaryURL) }
        
        let destinationURL = externalURL
            .appending(path: plugin.filename)
            .appendingPathExtension(FileConstants.userScriptExtension)
        guard fileManager.fileExists(at: destinationURL) else { return }
        
        let content = try String(contentsOf: temporaryURL)
        let metadata = try UserScriptMetadataDecoder().decode(PluginMetadata.self, from: content)
        
        guard let newVersion = metadata.version, newVersion != plugin.version else {
            return
        }
        
        try fileManager.replaceItem(
            at: destinationURL, withItemAt: temporaryURL, backupItemName: nil, resultingItemURL: nil
        )
        plugin.update(from: metadata)
    }
}

fileprivate extension ScriptManager {
    var allUpdatableExternalPlugins: [ Plugin ] {
        get throws {
            try modelContext.fetch(
                FetchDescriptor<Plugin>(
                    predicate: #Predicate {
                        !$0.isInternal && $0.version != nil && ($0.downloadURL != nil || $0.updateURL != nil)
                    }
                )
            )
        }
    }
}

fileprivate extension ScriptManager {
    static func checkUpdate(from url: URL, currentVersion: String?) async -> Bool {
        // Allow all errors
        guard
            let data = try? await URLSession.shared.data(from: url),
            let content = String(data: data, encoding: .utf8)
        else {
            return false
        }
        let updateVersion = try? UserScriptMetadataDecoder()
            .decode(VersionedMetadata.self, from: content).version
        return updateVersion != currentVersion
    }
}

fileprivate struct VersionedMetadata : Decodable {
    var version: String?
}
