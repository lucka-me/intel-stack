//
//  UpdateProgressEnvironmentKey.swift
//  Intel Stack
//
//  Created by Lucka on 2024-01-25.
//

import SwiftUI

extension EnvironmentValues {
    var updateProgress: Progress {
        get { self[UpdateProgressEnvironmentKey.self] }
        set { self[UpdateProgressEnvironmentKey.self] = newValue }
    }
}

fileprivate struct UpdateProgressEnvironmentKey: EnvironmentKey {
    static let defaultValue: Progress = .init()
}
