//
//  UpdateStatusEnvironmentKey.swift
//  Intel Stack
//
//  Created by Lucka on 2024-01-25.
//

import SwiftUI

enum UpdateStatus: Equatable {
    case idle
    case updating
}

extension EnvironmentValues {
    var updateStatus: UpdateStatus {
        get { self[UpdateStatusEnvironmentKey.self] }
        set { self[UpdateStatusEnvironmentKey.self] = newValue }
    }
}

fileprivate struct UpdateStatusEnvironmentKey: EnvironmentKey {
    static let defaultValue: UpdateStatus = .idle
}

