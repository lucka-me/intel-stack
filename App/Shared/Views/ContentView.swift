//
//  ContentView.swift
//  App
//
//  Created by Lucka on 2023-09-17.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scriptManager) private var scriptManager
    
    @State private var mainScriptVersion: String? = nil
    @State private var sidebarSelection: SidebarView.Selection? = nil
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $sidebarSelection)
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
        .onAppear {
            scriptManager.updateMainScriptVersion()
            isOnboardingSheetPresented = scriptManager.mainScriptVersion == nil
        }
    }
}

#Preview {
    ContentView()
}
