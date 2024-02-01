//
//  FileManager.swift
//  IntelStack
//
//  Created by Lucka on 2023-09-17.
//

import Foundation

extension FileManager {
    static let applicationGroupIdentifier = "group.dev.lucka.IntelStack"
    
    var applicationGroupContainerURL: URL {
        containerURL(forSecurityApplicationGroupIdentifier: Self.applicationGroupIdentifier)!
    }
}

extension FileManager {
    var internalScriptsDirectoryURL: URL {
        applicationGroupContainerURL
            .appending(path: "scripts", directoryHint: .isDirectory)
    }
    
    var internalPluginsDirectoryURL: URL {
        internalScriptsDirectoryURL
            .appending(path: "plugins", directoryHint: .isDirectory)
    }
    
    var mainScriptURL: URL {
        internalScriptsDirectoryURL
            .appending(path: FileConstants.mainScriptFilename)
            .appendingPathExtension(FileConstants.userScriptExtension)
    }
}

extension FileManager {
    func fileExists(at url: URL) -> Bool {
        fileExists(atPath: url.path(percentEncoded: false))
    }
}
