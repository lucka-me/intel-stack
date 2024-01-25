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
    @AppStorage(UserDefaults.Key.externalScriptsBookmark, store: .shared) private var bookmark: Data?
    @Environment(\.scriptManager) private var scriptManager
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var monitor: ExternalFileMonitor? = nil
    @State private var updateStatus: UpdateStatus = .idle
    
    private let updateProgress = Progress()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
#if os(macOS)
                .frame(minWidth: 600, minHeight: 400)
#elseif os(visionOS)
                .frame(minWidth: 800, minHeight: 600)
#endif
        }
        .windowResizability(.contentSize)
        .modelContainer(.default)
        .defaultAppStorage(.shared)
        .environment(\.updateProgress, updateProgress)
        .environment(\.updateStatus, updateStatus)
        .onChange(of: bookmark, initial: false) {
            Task(priority: .background) {
                await engageMonitor()
            }
        }
        .onChange(of: scenePhase, initial: true) {
            switch scenePhase {
            case .active:
                if monitor == nil {
                    Task(priority: .background) {
                        await engageMonitor()
                    }
                }
            default:
                monitor = nil
            }
        }
        .updatable(action: updatePlugins)
    }
    
    private func engageMonitor() async {
        guard let externalURL = try? ScriptManager.sync() else {
            await MainActor.run { monitor = nil }
            return
        }
        await MainActor.run {
            monitor = .init(url: externalURL) { url in
                do {
                    try ScriptManager.sync(in: url)
                } catch {
                    print(error)
                }
            }
        }
    }
    
    @MainActor
    private func updatePlugins() async throws {
        guard updateStatus == .idle else { return }
        updateStatus = .updating
        defer { updateStatus = .idle }
        try await scriptManager.updateScripts(reporting: updateProgress)
        scriptManager.updateMainScriptVersion()
    }
}
