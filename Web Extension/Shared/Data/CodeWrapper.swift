//
//  CodeWrapper.swift
//  Web Extension
//
//  Created by Lucka on 2023-09-27.
//

import Foundation

struct CodeWrapper {
    static func wrap(code: String, plugin: Plugin) -> String {
        return wrap(
            code: code,
            name: plugin.name,
            description: plugin.scriptDescription,
            version: plugin.version
        )
    }
    
    static func wrap(code: String, metadata: MainScriptMetadata) -> String {
        return wrap(
            code: code,
            name: metadata.name,
            description: metadata.description,
            version: metadata.version
        )
    }
    
    static func wrap(code: String, metadata: PluginMetadata) -> String {
        return wrap(
            code: code,
            name: metadata.name,
            description: metadata.description,
            version: metadata.version
        )
    }
    
    private static func wrap(code: String, name: String, description: String?, version: String?) -> String {
        let info = GreasemonkeyInfomation(
            script: .init(name: name, description: description, version: version)
        )
        let encoder = JSONEncoder()
        guard
            let encodedInfo = try? encoder.encode(info),
            let encodedInfoString = String(data: encodedInfo, encoding: .utf8)
        else {
            return "(function() { \n\(code)\n })();"
        }
        return "(function() { const GM_info = \(encodedInfoString); (function() { \n\(code)\n })(); })();"
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
