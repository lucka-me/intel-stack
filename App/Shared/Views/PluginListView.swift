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
        @Bindable var plugin = plugin
        GroupBox {
            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline) {
                    if let version = plugin.version {
                        Text(version)
                            .monospaced()
                            .capsule(.blue)
                            
                    }
                    if plugin.isInternal {
                        Text("PluginCardView.Internal")
                            .capsule(.purple)
                    } else {
                        Label("PluginCardView.External", systemImage: "arrow.up.right")
                            .capsule(.indigo)
                            .onTapGesture {
                                open(plugin)
                            }
                        if scriptManager.updatingPluginIds.contains(plugin.uuid) {
                            Text("PluginCardView.Updating")
                                .capsule(.pink)
                        }
                    }
                }
                .font(.caption)
                .lineLimit(1)
                
                Spacer()
                
                Text(plugin.scriptDescription ?? .init(localized: "PluginCardView.NoDescriptions"))
                    .italic(plugin.scriptDescription == nil)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3, reservesSpace: true)
                
                HStack {
                    Spacer()
                    Text("PluginCardView.Author \(plugin.author ?? "")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .italic()
                        .lineLimit(1, reservesSpace: true)
                        .opacity(plugin.author != nil ? 1.0 : 0.0)
                }
            }
        } label: {
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
        }
        .fixedSize(horizontal: false, vertical: false)
        #if os(macOS)
        .groupBoxStyle(.card)
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
