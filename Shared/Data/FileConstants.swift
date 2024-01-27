//
//  FileConstants.swift
//  IntelStack
//
//  Created by Lucka on 2023-09-22.
//

import Foundation

struct FileConstants {
    static let mainScriptFilename = "total-conversion-build"
    static let userScriptExtension = "user.js"
    static let userScriptFilenameSuffix = "." + userScriptExtension
    
    static let scriptMetadataExtension = "meta.js"
    static let scriptMetadataFilenameSuffix = "." + scriptMetadataExtension
    
    static let internalScriptsDirectoryURL = FileManager.default
        .applicationGroupContainerURL
        .appending(path: "scripts", directoryHint: .isDirectory)
    static let internalPluginsDirectoryURL = internalScriptsDirectoryURL
        .appending(path: "plugins", directoryHint: .isDirectory)
    static let mainScriptURL = internalScriptsDirectoryURL
        .appending(path: mainScriptFilename)
        .appendingPathExtension(userScriptExtension)
    
    private init() { }
}
