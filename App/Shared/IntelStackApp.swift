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
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var mainScriptVersion: String? = ""
    @State private var monitor: ExternalFileMonitor? = nil
    @State private var updateStatus: UpdateStatus = .idle
    
    private let scriptManager = ScriptManager.shared
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
        .environment(\.mainScriptVersion, mainScriptVersion)
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
                updateMainScriptVersion()
            default:
                monitor = nil
            }
        }
        .updatable(action: updatePlugins)
    }
    
    private func engageMonitor() async {
        guard let externalURL = try? await scriptManager.sync() else {
            await MainActor.run { monitor = nil }
            return
        }
        await MainActor.run {
            monitor = .init(url: externalURL) { url in
                Task(priority: .background) {
                    do {
                        try await scriptManager.sync(in: url)
                    } catch {
                        print(error)
                    }
                }
            }
        }
    }
    
    private func updateMainScriptVersion() {
        var version: String? = nil
        defer {
            mainScriptVersion = version
        }
        
        let fileManager = FileManager.default
        guard
            fileManager.fileExists(at: FileConstants.mainScriptURL),
            let content = try? String(contentsOf: FileConstants.mainScriptURL),
            let metadata = try? UserScriptMetadataDecoder().decode(MainScriptMetadata.self, from: content)
        else {
            return
        }
        version = metadata.version
    }
    
    @MainActor
    private func updatePlugins() async throws {
        guard updateStatus == .idle else { return }
        updateStatus = .updating
        defer { updateStatus = .idle }
        try await scriptManager.updateScripts(reporting: updateProgress)
        updateMainScriptVersion()
    }
}
