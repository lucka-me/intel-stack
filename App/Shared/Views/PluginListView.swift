//
//  PluginListView.swift
//  App
//
//  Created by Lucka on 2023-09-17.
//

import SwiftData
import SwiftUI

struct PluginListView: View {
    @Environment(\.scriptManager) private var scriptManager
    
#if !os(macOS)
    @Environment(\.openURL) private var openURL
#endif
    
    @Query private var plugins: [ Plugin ]
    
    private let title: String
    
    init(category: Plugin.Category) {
        self._plugins = Query(
            filter: #Predicate { $0.categoryValue == category.rawValue },
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
        GroupBox {
            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline) {
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
                }
                .font(.caption)
                .lineLimit(1)
                
                Spacer()
                
                Text(plugin.scriptDescription ?? .init(localized: "PluginListView.NoDescriptions"))
                    .italic(plugin.scriptDescription == nil)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3, reservesSpace: true)
                
                HStack {
                    Spacer()
                    Text("PluginListView.Author \(plugin.author ?? "")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .italic()
                        .lineLimit(1, reservesSpace: true)
                        .opacity(plugin.author != nil ? 1.0 : 0.0)
                }
            }
        } label: {
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
            .lineLimit(2)
#if os(macOS)
            .toggleStyle(.switch)
#endif
#endif
        }
        .fixedSize(horizontal: false, vertical: false)
#if os(macOS)
        .groupBoxStyle(.card)
#elseif os(visionOS)
        .onTapGesture {
            plugin.enabled.toggle()
        }
#endif
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

fileprivate extension View {
    func capsule(_ color: Color) -> some View {
        self
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.gradient, in: Capsule(style: .continuous))
    }
}
