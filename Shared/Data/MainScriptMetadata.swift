//
//  MainScriptMetadata.swift
//  IntelStack
//
//  Created by Lucka on 2024-01-26.
//

import Foundation

struct MainScriptMetadata : Decodable {
    var name: String
    
    var description: String?
    var version: String
}
