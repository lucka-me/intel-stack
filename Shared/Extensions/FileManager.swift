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
    func fileExists(at url: URL) -> Bool {
        fileExists(atPath: url.path(percentEncoded: false))
    }
}
