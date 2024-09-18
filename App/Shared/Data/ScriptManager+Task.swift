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
        try Self.ensureInternalDirectories()
        
        let externalURL = UserDefaults.shared.externalScriptsBookmarkURL
        var accessingSecurityScopedResource = false
        defer {
            if accessingSecurityScopedResource {
                externalURL?.stopAccessingSecurityScopedResource()
            }
        }
        
        let internalPlugins = try fetchInternalPlugins()
        
        let externalPlugins: [ ExternalPluginUpdateInformation ]
        if let externalURL {
            externalPlugins = try fetchUpdatableExternalPlugins(externalURL: externalURL)
        } else {
            externalPlugins = [ ]
        }
        
        progress.completedUnitCount = 0
        progress.totalUnitCount = .init(1 + internalPlugins.count + externalPlugins.count)
        
        let channel = UserDefaults.shared.buildChannel
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                print("updateMainScript start")
                try await self.updateMainScript(since: currentMainScriptVersion, from: channel)
                print("updateMainScript end")
                await MainActor.run { progress.completedUnitCount += 1 }
            }
            
            for internalPlugin in internalPlugins {
                group.addTask {
                    print("downloadInternalPlugin \(internalPlugin.filename) start")
                    try await self.update(internalPlugin: internalPlugin, from: channel)
                    print("downloadInternalPlugin \(internalPlugin.filename) end")
                    await MainActor.run { progress.completedUnitCount += 1 }
                }
            }
            
            if let externalURL, !externalPlugins.isEmpty {
                accessingSecurityScopedResource = externalURL.startAccessingSecurityScopedResource()
                for plugin in externalPlugins {
                    group.addTask {
                        print("updateExternal \(plugin.uuid) start")
                        try await self.update(externalPlugin: plugin)
                        print("updateExternal \(plugin.uuid) end")
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
}

fileprivate struct VersionedMetadata : Decodable {
    var version: String
}

fileprivate extension ScriptManager {
    typealias ExternalPluginUpdateInformation = (
        uuid: UUID, currentVersion: String?, updateURL: URL?, downloadURL: URL, destination: URL
    )
    typealias InternalPluginUpdateInformation = (filename: String, currentVersion: String?)
    
    static var websiteBuildURL: URL { .init(string: "https://iitc.app/build/")! }
    
    func fetchInternalPlugins() throws -> [ InternalPluginUpdateInformation ] {
        try JSONDecoder().decode(
            [ String ].self,
            from: try Data(contentsOf: Bundle.main.url(forResource: "InternalPlugins", withExtension: "json")!)
        ).map { filename in
            var descriptor = FetchDescriptor<Plugin>(
                predicate: #Predicate { $0.isInternal && $0.filename == filename }
            )
            descriptor.fetchLimit = 1
            descriptor.propertiesToFetch = [ \.version ]
            return (filename, try modelContext.fetch(descriptor).first?.version)
        }
    }
    
    func fetchUpdatableExternalPlugins(externalURL: URL) throws -> [ ExternalPluginUpdateInformation ] {
        var descriptor = FetchDescriptor<Plugin>(
            predicate: #Predicate {
                !$0.isInternal && $0.version != nil && ($0.downloadURL != nil || $0.updateURL != nil)
            }
        )
        descriptor.propertiesToFetch = [ \.downloadURL, \.filename, \.updateURL, \.uuid, \.version ]
        return try modelContext.fetch(descriptor)
            .compactMap { plugin in
                guard let downloadURL = plugin.downloadURL else {
                    return nil
                }
                return (
                    plugin.uuid,
                    plugin.version,
                    plugin.updateURL,
                    downloadURL,
                    externalURL
                        .appending(path: plugin.filename)
                        .appendingPathExtension(FileConstants.userScriptExtension)
                )
            }
    }
    
    func update(externalPlugin uuid: UUID, metadata: PluginMetadata) throws {
        var descriptor = FetchDescriptor<Plugin>(predicate: #Predicate { $0.uuid == uuid })
        descriptor.fetchLimit = 1
        try modelContext.fetch(descriptor).first?.update(from: metadata)
    }
    
    func update(internalPlugin filename: String, metadata: PluginMetadata) throws {
        var descriptor = FetchDescriptor<Plugin>(
            predicate: #Predicate { $0.isInternal && $0.filename == filename }
        )
        descriptor.fetchLimit = 1
        let item = try modelContext.fetch(descriptor).first
        if let item {
            item.update(from: metadata)
        } else {
            let item = Plugin(metadata: metadata, isInternal: true, filename: filename)
            modelContext.insert(item)
        }
    }

    func versionOf(internalPlugin filename: String) throws -> String? {
        var descriptor = FetchDescriptor<Plugin>(predicate: #Predicate { $0.isInternal && $0.filename == filename })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.version
    }

    nonisolated func updateAvailable(in url: URL, since currentVersion: String) async -> Bool {
        // Allow all errors
        guard
            let data = try? await URLSession.shared.data(from: url),
            let content = String(data: data, encoding: .utf8),
            let updateVersion = try? UserScriptMetadataDecoder()
                .decode(VersionedMetadata.self, from: content)
                .version
        else {
            return false
        }
        return updateVersion != currentVersion
    }
    
    nonisolated func update(externalPlugin information: ExternalPluginUpdateInformation) async throws {
        print("updateExternal entered \(information.uuid)")
        if let currentVersion = information.currentVersion, let updateURL = information.updateURL {
            // Check version from update URL
            guard await updateAvailable(in: updateURL, since: currentVersion) else {
                return
            }
        }

        let temporaryURL = try await URLSession.shared.download(from: information.downloadURL)

        let fileManager = FileManager.default
        defer { try? fileManager.removeItem(at: temporaryURL) }

        guard fileManager.fileExists(at: information.destination) else { return }

        let content = try String(contentsOf: temporaryURL)
        let metadata = try UserScriptMetadataDecoder().decode(PluginMetadata.self, from: content)

        guard let newVersion = metadata.version, newVersion != information.currentVersion else {
            return
        }

        try fileManager.replaceItem(
            at: information.destination, withItemAt: temporaryURL, backupItemName: nil, resultingItemURL: nil
        )
        
        try await update(externalPlugin: information.uuid, metadata: metadata)
    }
    
    nonisolated func update(
        internalPlugin information: InternalPluginUpdateInformation, from channel: BuildChannel
    ) async throws {
        print("updateInternalPlugin \(information.filename) entered")
        let pluginURL = Self.websiteBuildURL
            .appending(path: channel.rawValue)
            .appending(path: "plugins")
            .appending(path: information.filename)
        if let currentVersion = information.currentVersion {
            // Check version from metadata
            guard await updateAvailable(
                in: pluginURL.appendingPathExtension(FileConstants.scriptMetadataExtension), since: currentVersion
            ) else {
                print("updateInternalPlugin \(information.filename) update not available")
                return
            }
        }
        print("updateInternalPlugin \(information.filename) update available")
        
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
            .appending(path: information.filename)
            .appendingPathExtension(FileConstants.userScriptExtension)
        if fileManager.fileExists(at: destinationURL) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        
        try await update(internalPlugin: information.filename, metadata: metadata)

        succeed = true
    }
    
    nonisolated func updateMainScript(since currentVersion: String?, from channel: BuildChannel) async throws {
        let scriptURL = Self.websiteBuildURL
            .appending(path: channel.rawValue)
            .appending(path: FileConstants.mainScriptFilename)
        if let currentVersion {
            // Check version from metadata
            guard await updateAvailable(
                in: scriptURL.appendingPathExtension(FileConstants.scriptMetadataExtension),
                since: currentVersion
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
}
