//
//  Plugin+Category.swift
//  IntelStack
//
//  Created by Lucka on 2024-01-26.
//

import Foundation

extension Plugin {
    enum Category {
        case `default`(value: Default)
        case customized(value: String)
    }
    
    var category: Category {
        get { .init(rawValue: categoryValue) }
        set { categoryValue = newValue.rawValue }
    }
}

extension Plugin.Category {
    enum Default: String {
        case cache = "Cache"
        case controls = "Controls"
        case debug = "Debug"
        case draw = "Draw"
        case highlighter = "Highlighter"
        case info = "Info"
        case layer = "Layer"
        case mapTiles = "Map Tiles"
        case misc = "Misc"
        case portalInfo = "Portal Info"
        case tweaks = "Tweaks"
    }
}

extension Plugin.Category : RawRepresentable {
    init(rawValue: String) {
        if let value = Default(rawValue: rawValue) {
            self = .default(value: value)
        } else {
            self = .customized(value: rawValue)
        }
    }
    
    var rawValue: String {
        switch self {
        case .default(let value):
            return value.rawValue
        case .customized(let value):
            return value
        }
    }
}

extension Plugin.Category : Decodable {
    
}
