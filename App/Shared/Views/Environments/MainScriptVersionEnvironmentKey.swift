//
//  MainScriptVersionEnvironmentKey.swift
//  Intel Stack
//
//  Created by Lucka on 2024-01-25.
//

import SwiftUI

extension EnvironmentValues {
    var mainScriptVersion: String? {
        get { self[MainScriptVersionEnvironmentKey.self] }
        set { self[MainScriptVersionEnvironmentKey.self] = newValue }
    }
}

fileprivate struct MainScriptVersionEnvironmentKey: EnvironmentKey {
    static let defaultValue: String? = nil
}
