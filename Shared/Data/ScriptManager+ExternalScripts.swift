//
//  ScriptManager+ExternalScripts.swift
//  App
//
//  Created by Lucka on 2023-09-25.
//

import Foundation
import SwiftData

extension ScriptManager {
    @discardableResult
    static func sync(with context: ModelContext = .init(.default)) throws -> URL? {
        guard
            let externalURL = UserDefaults.shared.externalScriptsBookmarkURL,
            externalURL.startAccessingSecurityScopedResource()
        else {
            try context.delete(model: Plugin.self, where: Plugin.externalPredicate)
            return nil
        }
        
        defer {
            externalURL.stopAccessingSecurityScopedResource()
        }
        guard FileManager.default.fileExists(at: externalURL) else {
            UserDefaults.shared.externalScriptsBookmarkURL = nil
            try context.delete(model: Plugin.self, where: Plugin.externalPredicate)
            return nil
        }
        
        var metadatas: [ String : (String, UserScriptMetadata) ] = try FileManager.default
            .contentsOfDirectory(at: externalURL, includingPropertiesForKeys: nil)
            .filter { fileURL in
                fileURL.isFileURL && fileURL.lastPathComponent.hasSuffix(FileConstants.userScriptFilenameSuffix)
            }
            .reduce(into: [ : ]) { result, url in
                guard
                    let content = try? String(contentsOf: url),
                    let metadata = try? UserScriptMetadata(content: content),
                    metadata.readyForPlugin
                else {
                    return
                }
                result[metadata["id"]!] = (
                    url.lastPathComponent.replacing(FileConstants.userScriptFilenameSuffix, with: ""),
                    metadata
                )
            }
        let scripts = try context.fetch(.init(predicate: Plugin.externalPredicate))
        for script in scripts {
            guard
                let value = metadatas.removeValue(forKey: script.idendifier) else {
                context.delete(script)
                continue
            }
            script.filename = value.0
            script.update(from: value.1)
        }
        for metadata in metadatas {
            guard
                let plugin = Plugin(metadata: metadata.value.1, isInternal: false, filename: metadata.value.0)
            else {
                continue
            }
            context.insert(plugin)
        }
        
        return externalURL
    }
}
