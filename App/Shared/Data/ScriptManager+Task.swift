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

    @MainActor
    func downloadScripts() async throws {
        guard let internalPluginsURL = Bundle.main.url(forResource: "InternalPlugins", withExtension: "json") else {
            return
        }
        let internalPluginsData = try Data(contentsOf: internalPluginsURL)
        let decoder = JSONDecoder()
        let internalPlugins = try decoder.decode([ String ].self, from: internalPluginsData)
        
        // TODO: Fetch external scripts
        
        var doneCount = 0
        downloadProgress = .init(totalUnitCount: Int64(internalPlugins.count + 1))
        status = .downloading
        defer {
            status = .idle
        }
        
        let channel = UserDefaults.shared.buildChannel
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await self.downloadMainScript(from: channel)
                await MainActor.run {
                    self.downloadProgress.completedUnitCount += 1
                }
            }
            
            for filename in internalPlugins {
                group.addTask {
                    try await self.downloadInternalPlugin(from: channel, filename: filename)
                    await MainActor.run {
                        doneCount += 1
                        self.downloadProgress.completedUnitCount += 1
                    }
                }
            }
            
            try await group.waitForAll()
        }
    }
}

fileprivate extension ScriptManager {
    static let websiteBuildURL = URL(string: "https://iitc.app/build/")!
    
    private func downloadMainScript(from channel: BuildChannel) async throws {
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
            print("Download main script resulted in \(httpResponse.statusCode)")
            return
        }
        
        let content = try String(contentsOf: temporaryURL)
        guard let metadata = try UserScriptMetadata(content: content) else {
            print("Unable to fetch metadata from main script")
            return
        }
        guard let _ = metadata["version"] else {
            print("Unable to get version of main script")
            return
        }
        
        if fileManager.fileExists(at: FileConstants.mainScriptURL) {
            try fileManager.removeItem(at: FileConstants.mainScriptURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: FileConstants.mainScriptURL)
        succeed = true
    }
    
    private func downloadInternalPlugin(from channel: BuildChannel, filename: String) async throws {
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
            print("Download plugin \(filename) resulted in \(httpResponse.statusCode)")
            return
        }
        
        let content = try String(contentsOf: temporaryURL)
        guard
            let metadata = try UserScriptMetadata(content: content),
            metadata.readyForPlugin
        else {
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
        
        try await MainActor.run {
            let predicate = #Predicate<Plugin> {
                $0.isInternal && $0.filename == filename
            }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1
            let context = ModelContainer.default.mainContext
            if let item = try context.fetch(descriptor).first {
                item.update(from: metadata)
            } else {
                let item = Plugin(metadata: metadata, isInternal: true, filename: filename)!
                context.insert(item)
            }
        }
        
        succeed = true
    }
}
