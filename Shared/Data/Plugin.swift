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
    
    @Attribute(originalName: "idendifier")  // A typo, consider to remove in future version
    var identifier: String
    
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
    
    init(
        uuid: UUID = .init(),
        identifier: String,
        name: String,
        category: Category,
        isInternal: Bool,
        filename: String
    ) {
        self.uuid = uuid
        self.identifier = identifier
        self.name = name
        self.categoryValue = category.rawValue
        self.isInternal = isInternal
        self.filename = filename
    }
}

extension Plugin {
    static let externalPredicate = #Predicate<Plugin> { !$0.isInternal }
}

extension Plugin {
    var displayName: String {
        name.replacing(/^ *IITC +Plugin: */.ignoresCase()) { _ in "" }
    }
    
    var filenameWithExtension: String {
        filename + FileConstants.userScriptFilenameSuffix
    }
}
