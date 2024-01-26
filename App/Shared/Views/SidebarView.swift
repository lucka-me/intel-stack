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
    
#if os(macOS)
    static private let extensionId = "dev.lucka.IntelStack.WebExtension"
#endif
    
    @AppStorage(UserDefaults.Key.externalScriptsBookmark) private var externalScriptsBookmark: Data?
    @AppStorage(UserDefaults.Key.scriptsEnabled) private var scriptsEnabled = false
    
    @Binding private var selection: Selection?
    
    @Environment(\.alert) private var alert
    @Environment(\.mainScriptVersion) private var mainScriptVersion
    @Environment(\.updateProgress) private var updateProgress
    @Environment(\.updateScripts) private var updateScripts
    @Environment(\.updateStatus) private var updateStatus
#if os(macOS)
    @Environment(\.controlActiveState) private var controlActiveState
#endif
    
    @State private var isAddPluginDialogPresented = false
#if os(macOS)
    @State private var bottomBlockHeight: CGFloat = 0.0
    @State private var isExtensionEnabled: Bool? = nil
#endif
    
    init(selection: Binding<Selection?>) {
        self._selection = selection
    }
    
    var body: some View {
        List(selection: $selection) {
            Section {
                scriptSectionContent
            } header: {
                Text("SidebarView.Script")
            } footer: {
                Text("SidebarView.Script.Footer")
            }
            
#if os(macOS)
            Section {
                Button(extensionStateTextKey, systemImage: extensionStateIcon) {
                    SFSafariApplication.showPreferencesForExtension(withIdentifier: Self.extensionId)
                }
                .buttonStyle(.link)
                .foregroundStyle(extensionSateColor)
                .onChange(of: controlActiveState, initial: true) {
                    Task { await updateExtensionState() }
                }
            } header: {
                Text("SidebarView.Extension")
            }
#endif
            
            Section {
                ForEach(Plugin.Category.allCases, id: \.rawValue) { category in
                    NavigationLink(value: Selection.plugins(category: category)) {
                        Label(category.rawValue, systemImage: category.icon)
                    }
                }
#if os(iOS)
                if externalScriptsBookmark != nil {
                    addPluginButton
                }
#endif
            } header: {
                Text("SidebarView.Plugins")
            }
        }
#if os(iOS)
        .listStyle(.insetGrouped)
#else
        .listStyle(.sidebar)
#endif
#if !os(macOS)
        .refreshable {
            await tryUpdateScripts()
        }
#endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                if updateStatus == .updating {
                    ProgressView(updateProgress)
                }
            }
#if os(macOS)
            ToolbarItem(placement: .primaryAction) {
                Button("SidebarView.Update", systemImage: "arrow.clockwise") {
                    Task {
                        await tryUpdateScripts()
                    }
                }
                .disabled(updateStatus != .idle)
            }
#endif
#if os(visionOS)
            ToolbarItem(placement: .bottomBar) {
                if externalScriptsBookmark != nil {
                    addPluginButton
                }
            }
#endif
        }
#if os(macOS)
        .safeAreaPadding(.bottom, bottomBlockHeight)
#endif
        .navigationTitle("SidebarView.Title")
        .sheet(isPresented: $isAddPluginDialogPresented) {
            AddPluginView()
                .alertable()
        }
#if os(macOS)
        .overlay(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Divider()
                    .layoutPriority(2)
                HStack {
                    addPluginButton
                        .buttonStyle(.borderless)
                        .labelStyle(.iconOnly)
                        .disabled(externalScriptsBookmark == nil)
                }
                .padding(8)
            }
            .readSize(height: $bottomBlockHeight)
        }
#endif
    }
    
    @ViewBuilder
    private var addPluginButton: some View {
        Button("SidebarView.Plugins.Add", systemImage: "plus") {
            isAddPluginDialogPresented = true
        }
    }
    
    @ViewBuilder
    private var scriptSectionContent: some View {
        Toggle("SidebarView.Script.Enabled", systemImage: "power", isOn: $scriptsEnabled)
#if os(macOS)
            .toggleStyle(.switch)
#endif
            .disabled(mainScriptVersion == nil)
        if updateStatus == .updating {
            Label("SidebarView.Script.Updating", systemImage: "arrow.down.circle.dotted")
                .symbolRenderingMode(.multicolor)
                .symbolEffect(.pulse, options: .repeating)
        } else if let mainScriptVersion {
            if updateStatus == .idle {
                Label(mainScriptVersion, systemImage: "scroll")
                    .monospaced()
            }
        } else {
            Label("SidebarView.Script.Unavailable", systemImage: "xmark.octagon")
                .symbolRenderingMode(.multicolor)
        }
        
        NavigationLink(value: Selection.settings) {
            Label("SidebarView.Settings", systemImage: "gear")
        }
    }
    
#if os(macOS)
    private var extensionStateTextKey: LocalizedStringKey {
        switch isExtensionEnabled {
        case true: "SidebarView.Extension.Enabled"
        case false: "SidebarView.Extension.Disabled"
        default: "SidebarView.Extension.Unknown"
        }
    }

    private var extensionStateIcon: String {
        switch isExtensionEnabled {
        case true: "checkmark.circle"
        case false: "xmark.octagon"
        default: "questionmark.diamond"
        }
    }
    
    private var extensionSateColor: Color {
        switch isExtensionEnabled {
        case true: .green
        case false: .red
        default: .orange
        }
    }
#endif
    
    @MainActor
    private func tryUpdateScripts() async {
        do {
            try await updateScripts?()
        } catch let error as LocalizedError {
            alert?(.localized(error: error))
        } catch {
            alert?(.generic(error: error))
        }
    }
    
#if os(macOS)
    @MainActor
    private func updateExtensionState() async {
        guard controlActiveState == .key else { return }
        guard
            let state = try? await SFSafariExtensionManager.stateOfSafariExtension(
                withIdentifier: Self.extensionId
            )
        else {
            isExtensionEnabled = nil
            return
        }
        isExtensionEnabled = state.isEnabled
    }
#endif
}
