//
//  CommunityPluginListView.swift
//  Intel Stack
//
//  Created by Lucka on 2024-01-26.
//

import SwiftData
import SwiftUI

struct CommunityPluginListView: View {
    @Environment(\.alert) private var alert
    @Environment(\.modelContext) private var modelContext
    
    @State private var isFetching: Bool = true
    @State private var previews: [ PluginPreview ] = [ ]
    @State private var searchText: String = ""
    @State private var sorting: Sorting = .byName
    
    var body: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: [ .init(.adaptive(minimum: 300, maximum: .infinity)) ]) {
                ForEach(presentedPreviews, content: card(of:))
            }
        }
        .searchable(text: $searchText)
        .contentMargins(15, for: .scrollContent)
        .overlay(alignment: .center) {
            if isFetching {
                ProgressView()
            }
        }
        .navigationTitle("CommunityPluginsView.Title")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Picker("CommunityPluginsView.Sort", systemImage: "arrow.up.arrow.down", selection: $sorting) {
                    ForEach(Sorting.allCases) { item in
                        Text(item.titleKey)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .task {
            await tryFetchPreviews()
        }
        .onChange(of: sorting, initial: false) {
            previews.sort(by: sorting.method)
        }
    }
    
    private var presentedPreviews: [ PluginPreview ] {
        if searchText.isEmpty { return previews }
        
        // Make search
        let words = searchText
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
        return previews.filter { item in
            for word in words {
                if item.metadata.name.lowercased().contains(word) {
                    return true
                }
                if item.metadata.category.rawValue.lowercased() == word {
                    return true
                }
                if let author = item.metadata.author, author.lowercased().contains(word) {
                    return true
                }
                if let description = item.metadata.description, description.lowercased().contains(word) {
                    return true
                }
            }
            return false
        }
    }
    
    @ViewBuilder
    private func card(of preview: PluginPreview) -> some View {
        GroupBox {
            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline) {
                    Label(preview.metadata.category.rawValue, systemImage: preview.metadata.category.icon)
                        .capsule(.pink)
                    if let version = preview.metadata.version {
                        Text(version)
                            .monospaced()
                            .capsule(.blue)
                    }
                }
                .font(.caption)
                .lineLimit(1)
                
                Spacer()
                
                Text(preview.metadata.description ?? .init(localized: "PluginListView.NoDescriptions"))
                    .italic(preview.metadata.description == nil)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3, reservesSpace: true)
                
                HStack {
                    Spacer()
                    Text("PluginListView.Author \(preview.author)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .italic()
                        .lineLimit(1, reservesSpace: true)
                }
            }
        } label: {
            HStack(alignment: .top) {
                Text(preview.metadata.name)
                Spacer()
                switch preview.state {
                case .available:
                    Button("CommunityPluginsView.Add", systemImage: "plus.circle.fill") {
                        Task { await trySave(preview) }
                    }
                    .buttonStyle(.borderless)
                case .saving:
                    Label("CommunityPluginsView.Saving", systemImage: "arrow.down.circle.dotted")
                        .foregroundStyle(.primary)
                        .symbolRenderingMode(.multicolor)
                        .symbolEffect(.pulse, options: .repeating)
                case .saved:
                    Label("CommunityPluginsView.Added", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .labelStyle(.iconOnly)
        }
        .fixedSize(horizontal: false, vertical: false)
#if os(macOS)
        .groupBoxStyle(.card)
#endif
    }
}

fileprivate enum Sorting : Hashable, CaseIterable, Identifiable {
    case byAuthor
    case byCategory
    case byName
    
    var id: Self { self }
    
    var method: (PluginPreview, PluginPreview) -> Bool {
        switch self {
        case .byAuthor:
            { $0.metadata.author ?? $0.author < $1.metadata.author ?? $1.author }
        case .byCategory:
            { $0.metadata.category.rawValue < $1.metadata.category.rawValue }
        case .byName:
            { $0.metadata.name.localizedStandardCompare($1.metadata.name) == .orderedAscending }
        }
    }
    
    var titleKey: LocalizedStringKey {
        switch self {
        case .byAuthor:
            "CommunityPluginListView.Sorting.ByAuthor"
        case .byCategory:
            "CommunityPluginListView.Sorting.ByCategory"
        case .byName:
            "CommunityPluginListView.Sorting.ByName"
        }
    }
}

@Observable
fileprivate class PluginPreview : Identifiable {
    enum State {
        case available
        case saving
        case saved
    }
    
    let author: String
    let filename: String
    let metadata: PluginMetadata
    
    var state: State
    
    init(author: String, filename: String, isSaved: Bool, metadata: PluginMetadata) {
        self.author = author
        self.filename = filename
        self.state = isSaved ? .saved : .available
        self.metadata = metadata
    }
    
    var id: String {
        "\(author)/\(filename)"
    }
}

fileprivate extension CommunityPluginListView {
    private static var indexURL : URL {
        .init(string: "https://lucka-me.github.io/iitc-community-plugins-index/")!
    }
    private static var repository : String { "IITC-CE/Community-plugins" }
    
    @MainActor
    private func tryFetchPreviews() async {
        defer { isFetching = false }
        do {
            let index = try await URLSession.shared.decoded(
                [ String : [ String ] ].self, from: Self.indexURL, by: JSONDecoder()
            )
            
            previews = await withTaskGroup(of: PluginPreview?.self) { group in
                for authorAndFilename in index {
                    for filename in authorAndFilename.value {
                        group.addTask {
                            guard
                                let metadata = try? await metadata(
                                    of: authorAndFilename.key, filename: filename
                                )
                            else {
                                return nil
                            }
                            return .init(
                                author: authorAndFilename.key,
                                filename: filename,
                                isSaved: await ScriptManager.shared.isExistingPlugin(metadata.id),
                                metadata: metadata
                            )
                        }
                    }
                }
                return await group
                    .compactMap { $0 }
                    .reduce(into: [ ]) { $0.append($1) }
            }
            .sorted(by: sorting.method)
        } catch let error as LocalizedError {
            alert?(.localized(error: error))
        } catch {
            alert?(.generic(error: error))
        }
    }
    
    private func metadata(of author: String, filename: String) async throws -> PluginMetadata? {
        let data = try await GitHub.raw(
            in: Self.repository,
            branch: "master",
            path: "dist/\(author)/\(filename)" + FileConstants.scriptMetadataFilenameSuffix
        )
        guard let content = String(data: data, encoding: .utf8) else {
            return nil
        }
        return try UserScriptMetadataDecoder().decode(PluginMetadata.self, from: content)
    }
}

fileprivate extension CommunityPluginListView {
    @MainActor
    func trySave(_ preview: PluginPreview) async {
        preview.state = .saving
        do {
            let temporaryURL = try await GitHub.downloadRaw(
                in: Self.repository,
                branch: "master",
                path: "dist/\(preview.author)/\(preview.filename)" + FileConstants.userScriptFilenameSuffix
            )
            
            let fileManager = FileManager.default
            var succeed = false
            defer {
                preview.state = succeed ? .saved : .available
                if !succeed {
                    try? fileManager.removeItem(at: temporaryURL)
                }
            }
            
            guard
                let externalURL = UserDefaults.shared.externalScriptsBookmarkURL,
                externalURL.startAccessingSecurityScopedResource()
            else {
                return
            }
            defer {
                externalURL.stopAccessingSecurityScopedResource()
            }
            
            let destinationURL = externalURL
                .appending(path: preview.filename)
                .appendingPathExtension(FileConstants.userScriptExtension)
            
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            
            let plugin = Plugin(
                metadata: preview.metadata, isInternal: false, filename: preview.filename
            )
            modelContext.insert(plugin)
            try modelContext.save()
            
            succeed = true
        } catch let error as LocalizedError {
            alert?(.localized(error: error))
        } catch {
            alert?(.generic(error: error))
        }
    }
}

fileprivate extension ScriptManager {
    func isExistingPlugin(_ id: String) -> Bool {
        let descriptor = FetchDescriptor<Plugin>(predicate: #Predicate {
            !$0.isInternal && $0.idendifier == id
        })
        guard let count = try? modelContext.fetchCount(descriptor) else {
            return false
        }
        return count > 0
    }
}

fileprivate struct GitHub {
    private static var rawContent: URL { .init(string: "https://raw.githubusercontent.com/")! }
}

fileprivate extension GitHub {
    static func raw(in repository: String, branch: String, path: String) async throws -> Data {
        try await URLSession.shared.data(
            from: rawContentURL(in: repository, branch: branch, path: path)
        )
    }
    
    static func downloadRaw(in repository: String, branch: String, path: String) async throws -> URL {
        try await URLSession.shared.download(
            from: rawContentURL(in: repository, branch: branch, path: path)
        )
    }
    
    private static func rawContentURL(in repository: String, branch: String, path: String) -> URL {
        rawContent
            .appending(path: repository)
            .appending(path: branch)
            .appending(path: path)
    }
}
