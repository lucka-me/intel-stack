//
//  UserScript.swift
//  IntelStack
//
//  Created by Lucka on 2023-09-18.
//

import Foundation
import RegexBuilder

struct UserScriptMetadata {
    let name: String
    let description: String?
    
    let items: [ String : String ]
    
    private init(name: String, description: String? = nil, items: [String : String]) {
        self.name = name
        self.description = description
        self.items = items
    }
    
    subscript(key: String) -> String? {
        items[key]
    }
}

extension UserScriptMetadata {
    init?(content: String) throws {
        let metadataPattern = Regex {
            /\/\/ +==UserScript== *\n/
            Capture { OneOrMore(.any) }
            /\/\/ +==\/UserScript== */
        }
        guard let (_, metadata) = try metadataPattern.prefixMatch(in: content)?.output else { return nil }
        self.items = try metadata.split(separator: "\n").reduce(into: [ : ]) { result, row in
            let rowPattern = /\/\/ *@(.+?) +(.+?) */
            guard let (_, key, value) = try rowPattern.wholeMatch(in: row)?.output else { return }
            result[String(key)] = String(value)
        }
        self.name = items["name"] ?? ""
        self.description = items["description"]
    }
}

extension UserScriptMetadata {
    var readyForPlugin: Bool {
        guard
            let _ = items["id"],
            let categoryString = items["category"],
            let _ = Plugin.Category(rawValue: categoryString)
        else {
            return false
        }
        return true
    }
}
