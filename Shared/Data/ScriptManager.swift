//
//  ScriptManager.swift
//  App
//
//  Created by Lucka on 2023-09-17.
//

import SwiftData

@ModelActor
actor ScriptManager {
    static let shared = ScriptManager(modelContainer: .default)
}

extension ScriptManager {
    func save() throws {
        try modelContext.save()
    }
}
