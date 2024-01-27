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
    var downloadURL: String?
    var updateURL: String?
    var version: String?
}

extension Plugin {
    convenience init(metadata: PluginMetadata, isInternal: Bool, filename: String) {
        self.init(
            idendifier: metadata.id,
            name: metadata.name,
            category: metadata.category,
            isInternal: isInternal,
            filename: filename
        )
        
        self.author = metadata.author
        self.scriptDescription = metadata.description
        self.version = metadata.version
        if let downloadURL = metadata.downloadURL {
            self.downloadURL = URL(string: downloadURL)
        }
        if let updateURL = metadata.updateURL {
            self.updateURL = URL(string: updateURL)
        }
    }
    
    func update(from metadata: PluginMetadata) {
        self.idendifier = metadata.id
        self.category = metadata.category
        self.author = metadata.author
        self.scriptDescription = metadata.description
        self.version = metadata.version
        if let downloadURL = metadata.downloadURL {
            self.downloadURL = URL(string: downloadURL)
        }
        if let updateURL = metadata.updateURL {
            self.updateURL = URL(string: updateURL)
        }
    }
}
