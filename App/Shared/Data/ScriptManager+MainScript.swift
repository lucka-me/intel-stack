//
//  ScriptManager+MainScript.swift
//  Intel Stack
//
//  Created by Lucka on 2023-09-25.
//

import Foundation

extension ScriptManager {
    static func fetchMainScriptVersion() -> String? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(at: FileConstants.internalScriptsDirectoryURL) else {
            try? fileManager.createDirectory(at: FileConstants.internalScriptsDirectoryURL, withIntermediateDirectories: true)
            try? fileManager.createDirectory(at: FileConstants.internalPluginsDirectoryURL, withIntermediateDirectories: true)
            return nil
        }
        guard
            fileManager.fileExists(at: FileConstants.mainScriptURL),
            let content = try? String(contentsOf: FileConstants.mainScriptURL),
            let metadata = try? UserScriptMetadata(content: content)
        else {
            return nil
        }
        return metadata["version"]
    }
}
