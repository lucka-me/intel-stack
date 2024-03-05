//
//  PluginMetadata.swift
//  IntelStack
//
//  Created by Lucka on 2023-09-18.
//

import Foundation

struct PluginMetadata : Decodable {
    var id: String
    var name: String
    var category: Plugin.Category
    
    var author: String?
    var description: String?
    var downloadURL: URL?
    var updateURL: URL?
    var version: String?
    
    var homepageURL: URL?
}

extension Plugin {
    convenience init(metadata: PluginMetadata, isInternal: Bool, filename: String) {
        self.init(
            identifier: metadata.id,
            name: metadata.name,
            category: metadata.category,
            isInternal: isInternal,
            filename: filename
        )
        
        self.author = metadata.author
        self.scriptDescription = metadata.description
        self.version = metadata.version
        self.downloadURL = metadata.downloadURL
        self.updateURL = metadata.updateURL
    }
    
    func update(from metadata: PluginMetadata) {
        self.identifier = metadata.id
        self.category = metadata.category
        self.author = metadata.author
        self.scriptDescription = metadata.description
        self.version = metadata.version
        self.downloadURL = metadata.downloadURL
        self.updateURL = metadata.updateURL
    }
}
