//
//  UserScript.swift
//  IntelStack
//
//  Created by Lucka on 2023-09-18.
//

import Foundation

struct MainScriptMetadata : Decodable {
    var name: String
    
    var description: String?
    var version: String
}

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
