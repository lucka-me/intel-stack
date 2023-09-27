//
//  UserScriptMetadata+Code.swift
//  Web Extension
//
//  Created by Lucka on 2023-09-27.
//

import Foundation

extension UserScriptMetadata {
    static func wrap(code: String, name: String, description: String?, version: String?) -> String {
        let info = GreasemonkeyInfomation(
            script: .init(name: name, description: description, version: version)
        )
        let encoder = JSONEncoder()
        guard
            let encodedInfo = try? encoder.encode(info),
            let encodedInfoString = String(data: encodedInfo, encoding: .utf8)
        else {
            return "(function() { \(code) })();"
        }
        return "(function() { const GM_info = \(encodedInfoString); (function() { \(code) })(); })();"
    }
    
    func wrap(code: String) -> String {
        Self.wrap(code: code, name: name, description: description, version: items["version"])
    }
}

fileprivate struct GreasemonkeyInfomation: Encodable {
    var script: Script
}

fileprivate extension GreasemonkeyInfomation {
    struct Script: Encodable {
        var name: String
        var description: String?
        var version: String?
    }
}
