//
//  UpdatableEnvironmentKey.swift
//  Intel Stack
//
//  Created by Lucka on 2024-01-25.
//

import SwiftUI

typealias UpdateScriptAction = () async throws -> Void

extension EnvironmentValues {
    var updateScripts: UpdateScriptAction? {
        get { self[UpdatableEnvironmentKey.self] }
        set { self[UpdatableEnvironmentKey.self] = newValue }
    }
}

extension Scene {
    func updatable(action: @escaping () async throws -> Void) -> some Scene {
        environment(\.updateScripts, action)
    }
}

fileprivate struct UpdatableEnvironmentKey: EnvironmentKey {
    static let defaultValue: UpdateScriptAction? = nil
}
