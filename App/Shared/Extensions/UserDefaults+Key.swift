//
//  UserDefaults+Key.swift
//  App
//
//  Created by Lucka on 2023-09-20.
//

import Foundation

extension UserDefaults.Key {
    static let buildChannel = "BuildChannel"
}

extension UserDefaults {
    var buildChannel: ScriptManager.BuildChannel {
        guard
            let rawValue = string(forKey: Key.buildChannel),
            let value = ScriptManager.BuildChannel(rawValue: rawValue)
        else {
            return .release
        }
        return value
    }
}
