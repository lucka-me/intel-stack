//
//  SidebarView.swift
//  Intel Stack
//
//  Created by Lucka on 2023-10-05.
//

import SwiftUI
#if os(macOS)
import SafariServices
#endif

struct SidebarView: View {
    enum Selection : Hashable {
        case settings
        case plugins(category: Plugin.Category)
    }
    
    static private let extensionId = "dev.lucka.IntelStack.WebExtension"
    
    @AppStorage(UserDefaults.Key.scriptsEnabled) private var scriptsEnabled = false
    
    @Binding private var selection: Selection?
    
    @Environment(\.scriptManager) private var scriptManager
    #if os(macOS)
    @Environment(\.scenePhase) private var scenePhase : ScenePhase
    #endif
    
    #if os(macOS)
    @State private var extensionEnabled: Bool? = nil
    #endif
    
    init(selection: Binding<Selection?>) {
        self._selection = selection
    }
    
    var body: some View {
        List(selection: $selection) {
            sidebarContent
        }
        #if os(macOS)
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task {
                        await tryUpdateScripts()
                    }
                }
                .disabled(scriptManager.status != .idle)
            }
        }
        #else
        .listStyle(.insetGrouped)
        .refreshable {
            await tryUpdateScripts()
        }
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                if scriptManager.status == .downloading {
                    ProgressView(scriptManager.downloadProgress)
                }
            }
        }
        .navigationTitle("Intel Stack")
    }
    
    @ViewBuilder
    private var sidebarContent: some View {
        Section {
            scriptSectionContent
        } header: {
            Text("IITC Script")
        } footer: {
            Text("Pull to downlaod / update scripts.")
        }
        
        #if os(macOS)
        Section {
            Button(extensionStateTextKey, systemImage: extensionStateIcon) {
                SFSafariApplication.showPreferencesForExtension(withIdentifier: Self.extensionId)
            }
            .buttonStyle(.link)
            .foregroundStyle(extensionSateColor)
            .onChange(of: scenePhase, initial: true, fetchExtensionState)
        } header: {
            Text("Safari Extension")
        }
        #endif
        
        Section {
            ForEach(Plugin.Category.allCases, id: \.rawValue) { category in
                NavigationLink(value: Selection.plugins(category: category)) {
                    Label(category.rawValue, systemImage: category.icon)
                }
            }
        } header: {
            Text("Plugins")
        }
    }
    
    @ViewBuilder
    private var scriptSectionContent: some View {
        let version = scriptManager.mainScriptVersion
        Toggle("Enabled", systemImage: "power", isOn: $scriptsEnabled)
            #if os(macOS)
            .toggleStyle(.switch)
            #endif
            .disabled(version == nil)
        if scriptManager.status == .downloading {
            Label("Downloading", systemImage: "arrow.down.circle.dotted")
                .symbolRenderingMode(.multicolor)
                .symbolEffect(.pulse, options: .repeating)
        } else if let version {
            if scriptManager.status == .idle {
                Label(version, systemImage: "scroll")
                    .monospaced()
            }
        } else {
            Label("Unavailable", systemImage: "xmark.octagon")
                .symbolRenderingMode(.multicolor)
        }
        
        NavigationLink(value: Selection.settings) {
            Label("Settings", systemImage: "gear")
        }
    }
    
    #if os(macOS)
    private var extensionStateTextKey: LocalizedStringKey {
        switch extensionEnabled {
        case true: "Enabled"
        case false: "Disabled"
        default: "Unknown"
        }
    }

    private var extensionStateIcon: String {
        switch extensionEnabled {
        case true: "checkmark.circle"
        case false: "xmark.octagon"
        default: "questionmark.diamond"
        }
    }
    
    private var extensionSateColor: Color {
        switch extensionEnabled {
        case true: .green
        case false: .red
        default: .orange
        }
    }
    #endif
    
    @MainActor
    private func tryUpdateScripts() async {
        do {
            try await scriptManager.updateScripts()
        } catch {
            print(error)
        }
    }
    
    #if os(macOS)
    private func fetchExtensionState() {
        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: Self.extensionId) { state, error in
            DispatchQueue.main.async {
                extensionEnabled = state?.isEnabled
            }
        }
    }
    #endif
}
