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

    enum TaskError: Error, LocalizedError {
        case invalidHTTPResponse(statusCode: Int)
        
        var errorDescription: String? {
            switch self {
            case .invalidHTTPResponse(let statusCode):
                return .init(localized: "ScriptManager.TaskError.InvalidHTTPResponse \(statusCode)")
            }
        }
        
        var failureReason: String? {
            switch self {
            case .invalidHTTPResponse(let statusCode):
                return HTTPURLResponse.localizedString(forStatusCode: statusCode)
            }
        }
    }
}

extension ScriptManager {
    static var internalPluginNames: [ String ] {
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

extension ScriptManager {
    func updateScripts() async throws {
        guard status == .idle else { return }
        status = .downloading
        defer {
            status = .idle
            downloadProgress.completedUnitCount = 0
        }
        
        try Self.ensureInternalDirectories()
        
        let internalPlugins = try Self.internalPluginNames
        
        let externalPlugins = try await ModelExecutor.shared.allUpdatableExternalPlugins.filter {
            !self.updatingPluginIds.contains($0.uuid)
        }
        
        let uuids = Set(externalPlugins.map { $0.uuid })
        self.updatingPluginIds.formUnion(uuids)
        
        downloadProgress.completedUnitCount = 0
        downloadProgress.totalUnitCount = .init(1 + internalPlugins.count + externalPlugins.count)
        
        let externalURL = UserDefaults.shared.externalScriptsBookmarkURL
        var accessingSecurityScopedResource = false
        defer {
            if accessingSecurityScopedResource {
                externalURL?.stopAccessingSecurityScopedResource()
            }
        }
        
        defer { updatingPluginIds.subtract(uuids) }
        
        let channel = UserDefaults.shared.buildChannel
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await Self.downloadMainScript(from: channel)
                await MainActor.run { self.downloadProgress.completedUnitCount += 1 }
            }
            
            for filename in internalPlugins {
                group.addTask {
                    try await Self.downloadInternalPlugin(filename, from: channel)
                    await MainActor.run { self.downloadProgress.completedUnitCount += 1 }
                }
            }
            
            if !externalPlugins.isEmpty, let externalURL {
                accessingSecurityScopedResource = externalURL.startAccessingSecurityScopedResource()
                for plugin in externalPlugins {
                    group.addTask {
                        try await self.updateExternalPlugin(plugin, in: externalURL)
                        await MainActor.run { self.downloadProgress.completedUnitCount += 1 }
                    }
                }
            }
            
            try await group.waitForAll()
        }
    }
}

extension ScriptManager {
    static func ensureInternalDirectories() throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(at: FileConstants.internalScriptsDirectoryURL) {
            try fileManager.createDirectory(at: FileConstants.internalScriptsDirectoryURL, withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(at: FileConstants.internalPluginsDirectoryURL) {
            try fileManager.createDirectory(at: FileConstants.internalPluginsDirectoryURL, withIntermediateDirectories: true)
        }
    }
    
    static func downloadMainScript(from channel: BuildChannel) async throws {
        let downloadURL = Self.websiteBuildURL
            .appending(path: channel.rawValue)
            .appending(path: FileConstants.mainScriptFilename)
            .appendingPathExtension("user.js")
        let (temporaryURL, response) = try await URLSession.shared.download(from: downloadURL)
        
        let fileManager = FileManager.default
        var succeed = false
        defer {
            if !succeed {
                try? fileManager.removeItem(at: temporaryURL)
            }
        }
        
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard httpResponse.statusCode == 200 else {
            throw TaskError.invalidHTTPResponse(statusCode: httpResponse.statusCode)
        }
        
        let content = try String(contentsOf: temporaryURL)
        let _ = try UserScriptMetadataDecoder().decode(MainScriptMetadata.self, from: content)
        
        if fileManager.fileExists(at: FileConstants.mainScriptURL) {
            try fileManager.removeItem(at: FileConstants.mainScriptURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: FileConstants.mainScriptURL)
        succeed = true
    }
    
    static func downloadInternalPlugin(_ filename: String, from channel: BuildChannel) async throws {
        let downloadURL = Self.websiteBuildURL
            .appending(path: channel.rawValue)
            .appending(path: "plugins")
            .appending(path: filename)
            .appendingPathExtension("user.js")
        
        let (temporaryURL, response) = try await URLSession.shared.download(from: downloadURL)
        
        let fileManager = FileManager.default
        var succeed = false
        defer {
            if !succeed {
                try? fileManager.removeItem(at: temporaryURL)
            }
        }
        
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard httpResponse.statusCode == 200 else {
            throw TaskError.invalidHTTPResponse(statusCode: httpResponse.statusCode)
        }
        
        let content = try String(contentsOf: temporaryURL)
        let metadata = try UserScriptMetadataDecoder().decode(PluginMetadata.self, from: content)
        
        let destinationURL = FileConstants.internalPluginsDirectoryURL
            .appending(path: filename)
            .appendingPathExtension(FileConstants.userScriptExtension)
        if fileManager.fileExists(at: destinationURL) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        
        try await ModelExecutor.shared.updateInternalPlugin(with: metadata, filename: filename)
        
        succeed = true
    }
}

fileprivate extension ScriptManager {
    static let websiteBuildURL = URL(string: "https://iitc.app/build/")!
    
    private func updateExternalPlugin(_ information: ExternalPluginUpdateInformation, in externalURL: URL) async throws {
        // TODO: Use updateURL to fetch metadata
        guard let downloadURL = information.downloadURL else { return }

        let (temporaryURL, response) = try await URLSession.shared.download(from: downloadURL)

        let fileManager = FileManager.default
        defer { try? fileManager.removeItem(at: temporaryURL) }
        
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard httpResponse.statusCode == 200 else {
            throw TaskError.invalidHTTPResponse(statusCode: httpResponse.statusCode)
        }
        
        let destinationURL = externalURL
            .appending(path: information.filename)
            .appendingPathExtension(FileConstants.userScriptExtension)
        guard fileManager.fileExists(at: destinationURL) else { return }
        
        let content = try String(contentsOf: temporaryURL)
        let metadata = try UserScriptMetadataDecoder().decode(PluginMetadata.self, from: content)
        
        guard let newVersion = metadata.version, newVersion != information.version else {
            return
        }
        
        try fileManager.replaceItem(at: destinationURL, withItemAt: temporaryURL, backupItemName: nil, resultingItemURL: nil)
        try await ModelExecutor.shared.updateExternalPlugin(information.identifier, with: metadata)
    }
}

fileprivate extension ModelExecutor {
    var allUpdatableExternalPlugins: [ ExternalPluginUpdateInformation ] {
        get throws {
            try modelContext.fetch(
                FetchDescriptor<Plugin>(
                    predicate: #Predicate { !$0.isInternal && $0.version != nil && ($0.downloadURL != nil || $0.updateURL != nil) }
                )
            ).map {
                .init($0)
            }
        }
    }
    
    func updateInternalPlugin(with metadata: PluginMetadata, filename: String) throws {
        let predicate = #Predicate<Plugin> {
            $0.isInternal && $0.filename == filename
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        if let item = try modelContext.fetch(descriptor).first {
            item.update(from: metadata)
        } else {
            let item = Plugin(metadata: metadata, isInternal: true, filename: filename)!
            modelContext.insert(item)
        }
        try modelContext.save()
    }
    
    func updateExternalPlugin(_ identifier: PersistentIdentifier, with metadata: PluginMetadata) throws {
        guard let item = self[identifier, as: Plugin.self] else { return }
        item.update(from: metadata)
        try modelContext.save()
    }
}

fileprivate struct ExternalPluginUpdateInformation {
    let identifier: PersistentIdentifier
    let uuid: UUID
    let filename: String
    let version: String
    let updateURL: URL?
    let downloadURL: URL?
    
    init(_ plugin: Plugin) {
        identifier = plugin.persistentModelID
        uuid = plugin.uuid
        filename = plugin.filename
        version = plugin.version!
        updateURL = plugin.updateURL
        downloadURL = plugin.downloadURL
    }
}
