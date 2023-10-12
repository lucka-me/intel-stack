//
//  ScriptManager+MainScript.swift
//  Intel Stack
//
//  Created by Lucka on 2023-09-25.
//

import Foundation

extension ScriptManager {
    @MainActor
    func updateMainScriptVersion() {
        var version: String? = nil
        defer {
            mainScriptVersion = version
        }
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(at: FileConstants.internalScriptsDirectoryURL) else {
            try? fileManager.createDirectory(at: FileConstants.internalScriptsDirectoryURL, withIntermediateDirectories: true)
            try? fileManager.createDirectory(at: FileConstants.internalPluginsDirectoryURL, withIntermediateDirectories: true)
            return
        }
        guard
            fileManager.fileExists(at: FileConstants.mainScriptURL),
            let content = try? String(contentsOf: FileConstants.mainScriptURL),
            let metadata = try? UserScriptMetadata(content: content)
        else {
            return
        }
        version = metadata["version"]
    }
}
