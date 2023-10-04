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
    
    subscript(key: String) -> String? {
        items[key]
    }
}

extension UserScriptMetadata {
    init?(content: String) throws {
        guard
            content.hasPrefix("// ==UserScript=="),
            let startIndex = content.firstRange(of: "// ==UserScript==")?.upperBound,
            let endIndex = content.firstRange(of: "// ==/UserScript==")?.lowerBound
        else {
            return nil
        }
        self.items = try content[startIndex...endIndex]
            .split(separator: Regex { .newlineSequence })
            .reduce(into: [ : ]) { result, row in
                let trimmed = row.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                let rowPattern = /\/\/ *@(.+?) +(.+?) */
                guard let (_, key, value) = try rowPattern.wholeMatch(in: trimmed)?.output else { return }
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
