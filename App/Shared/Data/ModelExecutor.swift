//
//  ModelExecutor.swift
//  Intel Stack
//
//  Created by Lucka on 2023-10-11.
//

import SwiftData

@ModelActor
actor ModelExecutor {
    static let shared = ModelExecutor(modelContainer: .default)
}
