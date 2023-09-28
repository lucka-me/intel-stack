//
//  PluginListView.swift
//  App
//
//  Created by Lucka on 2023-09-17.
//

import SwiftData
import SwiftUI

struct PluginListView: View {
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
                ForEach(plugins, id: \.uuid) { plugin in
                    PluginCardView(plugin: plugin)
                }
            }
        }
        .contentMargins(15, for: .scrollContent)
        .navigationTitle(title)
    }
}

fileprivate struct PluginCardView: View {
    #if !os(macOS)
    @Environment(\.openURL) private var openURL
    #endif
    
    @State private var enabled = false
    
    let plugin: Plugin
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading) {
                Spacer()
                
                HStack(alignment: .firstTextBaseline) {
                    if let version = plugin.version {
                        Text(version)
                            .monospaced()
                            .capsule(.blue)
                            
                    }
                    if plugin.isInternal {
                        Text("Internal")
                            .capsule(.purple)
                    } else {
                        Label("External", systemImage: "arrow.up.right")
                            .capsule(.purple)
                            .onTapGesture(perform: openFile)
                    }
                }
                .font(.caption)
                .lineLimit(1)
                
                Text(plugin.scriptDescription ?? "No description")
                    .italic(plugin.scriptDescription == nil)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3, reservesSpace: true)
                
                HStack {
                    Spacer()
                    Text("By \(plugin.author ?? "Anonymous")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .italic()
                        .lineLimit(1)
                }
            }
        } label: {
            Toggle(isOn: $enabled) {
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
        .onAppear {
            enabled = plugin.enabled
        }
        .onChange(of: enabled) {
            plugin.enabled = enabled
        }
        #if os(macOS)
        .groupBoxStyle(.card)
        #endif
    }
    
    private func openFile() {
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
