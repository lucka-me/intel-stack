//
//  ContentView.swift
//  App
//
//  Created by Lucka on 2023-09-17.
//

import SwiftUI

struct ContentView: View {
    private enum SidebarSelection : Hashable {
        case settings
        case plugins(category: Plugin.Category)
    }
    
    @AppStorage(UserDefaults.Key.scriptsEnabled) private var scriptsEnabled = false
    
    @Environment(\.scriptManager) private var scriptManager
    
    @State private var mainScriptVersion: String? = nil
    @State private var sidebarSelection: SidebarSelection? = nil
    
    var body: some View {
        NavigationSplitView {
            List(selection: $sidebarSelection) {
                sidebarContent
            }
            #if os(macOS)
            .listStyle(.sidebar)
            #else
            .listStyle(.insetGrouped)
            #endif
            .navigationTitle("Intel Stack")
            .refreshable {
                await tryDownloadScripts()
            }
        } detail: {
            NavigationStack {
                switch sidebarSelection {
                case .settings:
                    SettingsView()
                case .plugins(let category):
                    PluginListView(category: category)
                case nil:
                    OnboardingView()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: scriptManager.status, initial: true) {
            if scriptManager.status == .idle {
                mainScriptVersion = ScriptManager.fetchMainScriptVersion()
            }
        }
    }
    
    @ViewBuilder
    private var sidebarContent: some View {
        Section {
            if scriptManager.status == .idle, let mainScriptVersion {
                Toggle("Enabled", systemImage: "power", isOn: $scriptsEnabled)
                Label(mainScriptVersion, systemImage: "scroll")
                    .monospaced()
            } else {
                switch scriptManager.status {
                case .idle:
                    Label("Unavailable", systemImage: "xmark.octagon")
                        .symbolRenderingMode(.multicolor)
                    Button("Download", systemImage: "arrow.down") {
                        Task {
                            await tryDownloadScripts()
                        }
                    }
                case .downloading:
                    Label("Downloading", systemImage: "arrow.down.circle.dotted")
                        .symbolRenderingMode(.multicolor)
                        .symbolEffect(.pulse, options: .repeating)
                    ProgressView(scriptManager.downloadProgress)
                }
            }
        } header: {
            Text("IITC Script")
        }
        
        Section {
            NavigationLink(value: SidebarSelection.settings) {
                Label("Settings", systemImage: "gear")
            }
        }
        
        Section {
            if mainScriptVersion != nil {
                ForEach(Plugin.Category.allCases, id: \.rawValue) { category in
                    NavigationLink(value: SidebarSelection.plugins(category: category)) {
                        Label(category.rawValue, systemImage: category.icon)
                    }
                }
            }
        } header: {
            Text("Plugins")
        }
    }
    
    @MainActor
    private func tryDownloadScripts() async {
        guard scriptManager.status == .idle else { return }
        do {
            try await scriptManager.downloadScripts()
        } catch {
            print(error)
        }
    }
}

#Preview {
    ContentView()
}
