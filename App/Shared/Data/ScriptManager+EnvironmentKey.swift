//
//  Persistence+EnvironmentKey.swift
//  App
//
//  Created by Lucka on 2023-09-18.
//

import SwiftUI

fileprivate struct ScriptManagerEnvironmentKey: EnvironmentKey {
    static let defaultValue: ScriptManager = .shared
}

extension EnvironmentValues {
    var scriptManager: ScriptManager {
        get { self[ScriptManagerEnvironmentKey.self] }
        set { self[ScriptManagerEnvironmentKey.self] = newValue }
    }
}
