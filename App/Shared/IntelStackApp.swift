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
    @AppStorage(UserDefaults.Key.externalScriptsBookmark) private var bookmark: Data?
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var monitor: ExternalFileMonitor? = nil
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .defaultAppStorage(.shared)
                .environment(\.scriptManager, ScriptManager.shared)
                .modelContainer(.default)
                .task(id: bookmark) {
                    // TODO: Be ware of the scenePhase, task should not run if not active
                    guard let externalURL = try? ScriptManager.sync() else {
                        monitor = nil
                        return
                    }
                    monitor = .init(url: externalURL) { url in
                        do {
                            try ScriptManager.sync(in: url)
                        } catch {
                            print(error)
                        }
                    }
                }
        }
    }
}
