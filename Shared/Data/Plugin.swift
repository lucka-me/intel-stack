//
//  Script.swift
//  IntelStack
//
//  Created by Lucka on 2023-09-17.
//

import Foundation
import RegexBuilder
import SwiftData

@Model
class Plugin {
    var uuid: UUID
    
    var idendifier: String
    
    var enabled: Bool = false
    
    var name: String
    var categoryValue: Category.RawValue
    var isInternal: Bool
    var filename: String
    
    var author: String?
    var scriptDescription: String?
    var version: String?
    
    var downloadURL: URL?
    var updateURL: URL?
    
    init(uuid: UUID = .init(), idendifier: String, name: String, category: Category, isInternal: Bool, filename: String) {
        self.uuid = uuid
        self.idendifier = idendifier
        self.name = name
        self.categoryValue = category.rawValue
        self.isInternal = isInternal
        self.filename = filename
    }
    
    var category: Category {
        get { .init(rawValue: categoryValue) ?? .misc }
        set { categoryValue = newValue.rawValue }
    }
}

extension Plugin {
    enum Category: String, CaseIterable, Codable {
        case cache = "Cache"
        case controls = "Controls"
        case draw = "Draw"
        case highlighter = "Highlighter"
        case info = "Info"
        case layer = "Layer"
        case mapTiles = "Map Tiles"
        case portalInfo = "Portal Info"
        case tweaks = "Tweaks"
        case misc = "Misc"
        case debug = "Debug"
    }
}

extension Plugin {
    static let externalPredicate = #Predicate<Plugin> { !$0.isInternal }
}

extension Plugin {
    convenience init?(metadata: UserScriptMetadata, isInternal: Bool, filename: String) {
        guard
            let idendifier = metadata["id"],
            let categoryString = metadata["category"],
            let category = Category(rawValue: categoryString)
        else {
            return nil
        }
        
        self.init(idendifier: idendifier, name: metadata.name, category: category, isInternal: isInternal, filename: filename)
        
        self.author = metadata["author"]
        self.scriptDescription = metadata["description"]
        self.version = metadata["version"]
        if let downloadURL = metadata["downloadURL"] {
            self.downloadURL = URL(string: downloadURL)
        }
        if let updateURL = metadata["updateURL"] {
            self.updateURL = URL(string: updateURL)
        }
    }
    
    func update(from metadata: UserScriptMetadata) {
        if let idendifier = metadata["id"] {
            self.idendifier = idendifier
        }
        if let categoryString = metadata["category"],
           let category = Category(rawValue: categoryString) {
            self.category = category
        }
        self.author = metadata["author"]
        self.scriptDescription = metadata["description"]
        self.version = metadata["version"]
        if let downloadURL = metadata["downloadURL"] {
            self.downloadURL = URL(string: downloadURL)
        }
        if let updateURL = metadata["updateURL"] {
            self.updateURL = URL(string: updateURL)
        }
    }
}

extension Plugin {
    var displayName: String {
        name.replacing(/^ *IITC +Plugin: */.ignoresCase()) { _ in "" }
    }
}
