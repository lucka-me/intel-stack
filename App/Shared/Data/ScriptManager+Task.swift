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
        
        let internalPlugins = try Self.internalPluginNames
        downloadProgress.completedUnitCount = 0
        downloadProgress.totalUnitCount = .init(1 + internalPlugins.count + externalPlugins.count)
        
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
            
            try await group.waitForAll()
        }
    }
}

extension ScriptManager {
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
            // TODO: Throw an error
            print("Download main script resulted in \(httpResponse.statusCode)")
            return
        }
        
        let content = try String(contentsOf: temporaryURL)
        guard let metadata = try UserScriptMetadata(content: content) else {
            // TODO: Throw an error
            print("Unable to fetch metadata from main script")
            return
        }
        guard let _ = metadata["version"] else {
            // TODO: Throw an error
            print("Unable to get version of main script")
            return
        }
        
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
            // TODO: Throw an error
            print("Download plugin \(filename) resulted in \(httpResponse.statusCode)")
            return
        }
        
        let content = try String(contentsOf: temporaryURL)
        guard
            let metadata = try UserScriptMetadata(content: content),
            metadata.readyForPlugin
        else {
            // TODO: Throw an error
            print("Unable to fetch metadata from \(downloadURL)")
            return
        }
        
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
}

fileprivate extension ModelExecutor {
    func updateInternalPlugin(with metadata: UserScriptMetadata, filename: String) throws {
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
    
    private func updateExternal(plugin: Plugin, in externalURL: URL) async throws {

    }
}
