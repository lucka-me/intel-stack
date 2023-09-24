//
//  IntelStackApp.swift
//  App
//
//  Created by Lucka on 2023-09-17.
//

import SwiftData
import SwiftUI

@main
struct IntelStackApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .defaultAppStorage(.shared)
                .environment(\.scriptManager, ScriptManager.shared)
                .modelContainer(ModelContainer.default)
        }
    }
}
