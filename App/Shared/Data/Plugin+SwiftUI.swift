//
//  Plugin+SwiftUI.swift
//  App
//
//  Created by Lucka on 2023-09-18.
//

import Foundation

extension Plugin.Category {
    var icon: String {
        switch self {
        case .default(let value):
            switch value {
            case .cache:
                "tray"
            case .controls:
                "dpad"
            case .draw:
                "scribble"
            case .highlighter:
                "target"
            case .info:
                "info"
            case .layer:
                "square.3.layers.3d"
            case .mapTiles:
                "map"
            case .portalInfo:
                "selection.pin.in.out"
            case .tweaks:
                "wrench.and.screwdriver"
            case .misc:
                "ellipsis"
            case .debug:
                "ladybug"
            }
        default:
            "puzzlepiece.extension"
        }
    }
}

extension Plugin.Category : Hashable {
    
}
