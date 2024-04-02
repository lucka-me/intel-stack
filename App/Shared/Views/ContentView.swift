//
//  ContentView.swift
//  App
//
//  Created by Lucka on 2023-09-17.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.mainScriptVersion) private var mainScriptVersion
    
    @State private var columnVisibility = NavigationSplitViewVisibility.doubleColumn
    @State private var isOnboardingSheetPresented = false
    @State private var searchText = ""
    @State private var sidebarSelection: SidebarView.Selection? = nil
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            if !searchText.isEmpty && horizontalSizeClass == .compact {
                PluginListView(searchText: searchText)
            } else {
                SidebarView(selection: $sidebarSelection)
#if os(macOS)
                    .frame(minWidth: 200)
#endif
            }
        } detail: {
            NavigationStack {
                if !searchText.isEmpty && horizontalSizeClass != .compact {
                    PluginListView(searchText: searchText)
                } else {
                    switch sidebarSelection {
                    case .settings:
                        SettingsView()
                    case .plugins(let category):
                        PluginListView(category: category)
                    case .communityPlugins:
                        CommunityPluginListView()
                    case nil:
                        Text("ContentView.EmptyHint")
                    }
                }
            }
        }
        .searchable(
            text: $searchText,
            placement: .sidebar,
            prompt: Text("ContentView.SearchPrompt")
        )
        .alertable()
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $isOnboardingSheetPresented) {
            OnboardingView()
                .interactiveDismissDisabled()
                .alertable()
        }
        .onChange(of: mainScriptVersion, initial: false) {
            isOnboardingSheetPresented = mainScriptVersion == nil
        }
        .onChange(of: horizontalSizeClass, initial: true) {
#if os(macOS)
            sidebarSelection = .settings    // horizontalSizeClass is always nil on macOS, maybe a bug?
#else
            if horizontalSizeClass == .regular, sidebarSelection == nil {
                sidebarSelection = .settings
            }
#endif
        }
    }
}

#Preview {
    ContentView()
}
