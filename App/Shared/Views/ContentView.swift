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
            .frame(minWidth: 200)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        Task {
                            await tryDownloadScripts()
                        }
                    }
                    .disabled(scriptManager.status != .idle)
                }
            }
            #else
            .listStyle(.insetGrouped)
            .refreshable {
                await tryDownloadScripts()
            }
            #endif
            .navigationTitle("Intel Stack")
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
            #if os(macOS)
            .frame(minWidth: 450)
            #endif
        }
        #if os(macOS)
        .frame(minHeight: 450)
        #endif
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
                #if os(macOS)
                    .toggleStyle(.switch)
                #endif
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
        } footer: {
            Text("Pull to downlaod / update scripts.")
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
