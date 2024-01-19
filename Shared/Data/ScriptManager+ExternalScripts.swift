//
//  ScriptManager+ExternalScripts.swift
//  App
//
//  Created by Lucka on 2023-09-25.
//

import Foundation
import SwiftData

extension ScriptManager {
    static func sync(in externalURL: URL, with context: ModelContext = .init(.default)) throws {
        guard FileManager.default.fileExists(at: externalURL) else {
            UserDefaults.shared.externalScriptsBookmarkURL = nil
            try context.delete(model: Plugin.self, where: Plugin.externalPredicate)
            return
        }
        
        var metadatas: [ String : (String, PluginMetadata) ] = try FileManager.default
            .contentsOfDirectory(at: externalURL, includingPropertiesForKeys: nil)
            .filter { fileURL in
                fileURL.isFileURL && fileURL.lastPathComponent.hasSuffix(FileConstants.userScriptFilenameSuffix)
            }
            .reduce(into: [ : ]) { result, url in
                guard
                    let content = try? String(contentsOf: url),
                    let metadata = try? UserScriptMetadataDecoder().decode(PluginMetadata.self, from: content)
                else {
                    return
                }
                result[metadata.id] = (
                    url.lastPathComponent.replacing(FileConstants.userScriptFilenameSuffix, with: ""),
                    metadata
                )
            }
        let plugins = try context.fetch(.init(predicate: Plugin.externalPredicate))
        for plugin in plugins {
            guard let value = metadatas.removeValue(forKey: plugin.idendifier) else {
                context.delete(plugin)
                continue
            }
            plugin.filename = value.0
            plugin.update(from: value.1)
        }
        for metadata in metadatas {
            guard
                let plugin = Plugin(metadata: metadata.value.1, isInternal: false, filename: metadata.value.0)
            else {
                continue
            }
            context.insert(plugin)
        }
        try context.save()
    }
    
    @discardableResult
    static func sync(with context: ModelContext = .init(.default)) throws -> URL? {
        guard let externalURL = UserDefaults.shared.externalScriptsBookmarkURL else {
            try context.delete(model: Plugin.self, where: Plugin.externalPredicate)
            return nil
        }
        
        let isAccessingSecurityScopedResource = externalURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessingSecurityScopedResource {
                externalURL.stopAccessingSecurityScopedResource()
            }
        }
        try sync(in: externalURL, with: context)
        
        return externalURL
    }
}
