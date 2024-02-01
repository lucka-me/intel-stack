//
//  PluginListView.swift
//  App
//
//  Created by Lucka on 2023-09-17.
//

import SwiftData
import SwiftUI

struct PluginListView: View {    
#if !os(macOS)
    @Environment(\.openURL) private var openURL
#endif
    
    @Query private var plugins: [ Plugin ]
    
    private let title: String
    
    init(category: Plugin.Category) {
        let categoryValue = category.rawValue
        self._plugins = Query(
            filter: #Predicate { $0.categoryValue == categoryValue },
            sort: \.name,
            animation: .default
        )
        self.title = category.rawValue
    }
    
    var body: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: [ .init(.adaptive(minimum: 300, maximum: .infinity)) ]) {
                ForEach(plugins, id: \.uuid, content: card(of:))
            }
        }
        .contentMargins(15, for: .scrollContent)
        .navigationTitle(title)
    }
    
    @ViewBuilder
    private func card(of plugin: Plugin) -> some View {
#if !os(visionOS)
        @Bindable var plugin = plugin
#endif
        PluginCardView(description: plugin.scriptDescription) {
#if os(visionOS)
            // Temporary fix for visionOS
            // - Toggle leads to UI freezing, always
            // - .animation(:value:) also leads to UI freezing with high possibility
            HStack(alignment: .top) {
                Text(plugin.displayName)
                Spacer()
                if plugin.enabled {
                    Label("PluginListView.Enabled", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("PluginListView.Disabled", systemImage: "circle")
                        .foregroundStyle(.gray)
                }
            }
            .labelStyle(.iconOnly)
#else
            Toggle(isOn: $plugin.enabled) {
                Text(plugin.displayName)
#if os(macOS)
                    .frame(maxWidth: .infinity, alignment: .leading)
#endif
            }
#if os(macOS)
            .toggleStyle(.switch)
#endif
#endif
        } labels: {
            if let version = plugin.version {
                Text(version)
                    .monospaced()
                    .capsule(.blue)
            }
            if plugin.isInternal {
                Text("PluginListView.Internal")
                    .capsule(.purple)
            } else {
                Label("PluginListView.External", systemImage: "arrow.up.right")
                    .capsule(.indigo)
                    .onTapGesture {
                        open(plugin)
                    }
            }
        } footer: {
            Spacer()
            Text("PluginListView.Author \(plugin.author ?? "")")
                .opacity(plugin.author != nil ? 1.0 : 0.0)
        }
    }
    
    private func open(_ plugin: Plugin) {
        guard
            let url = UserDefaults.shared.externalScriptsBookmarkURL?
                .appending(path: plugin.filename)
                .appendingPathExtension(FileConstants.userScriptExtension)
        else {
            return
        }
#if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting([ url ])
#else
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        components.scheme = "shareddocuments"
        guard let urlForFileApp = components.url else { return }
        openURL(urlForFileApp)
#endif
    }
}
