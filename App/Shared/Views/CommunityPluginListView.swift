//
//  CommunityPluginListView.swift
//  Intel Stack
//
//  Created by Lucka on 2024-01-26.
//

import SwiftData
import SwiftUI

@MainActor
struct CommunityPluginListView: View {
    @Environment(\.alert) private var alert
    @Environment(\.modelContext) private var modelContext
    
    @State private var viewModel = ViewModel()
    
    var body: some View {
        let presentedPreviews = viewModel.presentedPreviews
        ScrollView(.vertical) {
            LazyVGrid(columns: [ .init(.adaptive(minimum: 300, maximum: .infinity)) ]) {
                Section {
                    ForEach(presentedPreviews) { preview in
                        card(of: preview)
                    }
                } footer: {
                    if !viewModel.isFetching && !viewModel.isSearching {
                        Text("CommunityPluginListView.Footer \(viewModel.previews.count)")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                            .padding(.horizontal, 10)
                    }
                }
            }
        }
        .searchable(
            text: $viewModel.searchText,
            tokens: $viewModel.searchTokens,
            prompt: Text("CommunityPluginListView.SearchPrompt")
        ) { token in
            Label(token.text, systemImage: token.icon)
        }
        .searchSuggestions {
            if viewModel.searchText == "#" {
                searchSuggestions
            }
        }
        .contentMargins(15, for: .scrollContent)
        .overlay(alignment: .center) {
            if viewModel.isFetching {
                ProgressView()
            } else if presentedPreviews.isEmpty {
                if viewModel.isSearching {
                    ContentUnavailableView.search
                }
            }
        }
        .navigationTitle("CommunityPluginsView.Title")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Menu("CommunityPluginsView.Option", systemImage: "slider.vertical.3") {
                    Picker("CommunityPluginsView.Option.Sort", selection: $viewModel.sorting) {
                        ForEach(Sorting.allCases) { item in
                            Text(item.titleKey)
                        }
                    }
                    .pickerStyle(.inline)
                    Toggle(
                        "CommunityPluginsView.Option.HideAddedPlugins",
                        isOn: $viewModel.hideAddedPlugins
                    )
                }
            }
        }
        .task {
            do {
                try await viewModel.fetchPreviews()
            } catch let error as LocalizedError {
                alert?(.localized(error: error))
            } catch {
                alert?(.generic(error: error))
            }
        }
        .onChange(of: viewModel.sorting, initial: false, viewModel.sort)
    }
    
    @ViewBuilder
    private var searchSuggestions: some View {
        if !viewModel.searchTokens.contains(where: { $0.target == .category }) {
            Section {
                ForEach(viewModel.availableCategories, id: \.self) { category in
                    let token = SearchToken(target: .category, text: category)
                    Label(category, systemImage: token.icon)
                        .searchCompletion(token)
                }
            } header: {
                Text(SearchToken.Target.category.titleKey)
            }
        }
        if !viewModel.searchTokens.contains(where: { $0.target == .author }) {
            Section {
                ForEach(viewModel.availableAuthors, id: \.self) { author in
                    let token = SearchToken(target: .author, text: author)
                    Label(author, systemImage: token.icon)
                        .searchCompletion(token)
                }
            } header: {
                Text(SearchToken.Target.author.titleKey)
            }
        }
    }
    
    @ViewBuilder
    private func card(of preview: PluginPreview) -> some View {
        GroupBox {
            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline) {
                    Label(preview.metadata.category.rawValue, systemImage: preview.metadata.category.icon)
                        .capsule(.pink)
                        .onTapGesture {
                            viewModel.addToken(for: .category, text: preview.metadata.category.rawValue)
                        }
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
                        .onTapGesture {
                            viewModel.addToken(for: .author, text: preview.author)
                        }
                }
            }
        } label: {
            HStack(alignment: .top) {
                Text(preview.metadata.name)
                Spacer()
                switch preview.state {
                case .available:
                    Button("CommunityPluginsView.Add", systemImage: "plus.circle.fill") {
                        Task {
                            do {
                                try await viewModel.save(preview, with: modelContext)
                            } catch let error as LocalizedError {
                                alert?(.localized(error: error))
                            } catch {
                                alert?(.generic(error: error))
                            }
                        }
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

fileprivate struct SearchToken : Identifiable {
    enum Target {
        case author
        case category
    }
    
    var target: Target
    var text: String
    
    var id: Target { target }
    
    var icon: String {
        switch target {
        case .author:
            "signature"
        case .category:
            Plugin.Category(rawValue: text).icon
        }
    }
    
    func matches(_ preview: PluginPreview) -> Bool {
        switch target {
        case .author:
            preview.author == text
        case .category:
            preview.metadata.category.rawValue == text
        }
    }
}

fileprivate extension SearchToken.Target {
    var titleKey: LocalizedStringKey {
        switch self {
        case .author:
            "CommunityPluginListView.SearchToken.Target.Author"
        case .category:
            "CommunityPluginListView.SearchToken.Target.Category"
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

@MainActor
@Observable
fileprivate class ViewModel {
    var isFetching: Bool = true
    
    var hideAddedPlugins: Bool = false
    var sorting: Sorting = .byName
    
    var previews: [ PluginPreview ] = [ ]
    
    var searchText: String = ""
    var searchTokens: [ SearchToken ] = [ ]
}

fileprivate extension ViewModel {
    func sort() { previews.sort(by: sorting.method) }
}

fileprivate extension ViewModel {
    var presentedPreviews: [ PluginPreview ] {
        var result = previews
        if hideAddedPlugins {
            result = result.filter { $0.state != .saved }
        }
        
        if searchText.isEmpty && searchTokens.isEmpty { return result }
        
        // Make search
        let words = searchText
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
        return previews.filter { item in
            for token in searchTokens {
                if !token.matches(item) {
                    return false
                }
            }
            guard !words.isEmpty else {
                return true
            }
            for word in words {
                if item.metadata.name.lowercased().contains(word) {
                    return true
                }
                if let description = item.metadata.description, description.lowercased().contains(word) {
                    return true
                }
            }
            return false
        }
    }
}

fileprivate extension ViewModel {
    var availableAuthors: [ String ] {
        previews
            .reduce(into: Set<String>()) { $0.insert(($1.author)) }
            .sorted()
    }
    
    var availableCategories: [ String ] {
        previews
            .reduce(into: Set<String>()) { $0.insert($1.metadata.category.rawValue) }
            .sorted()
    }
    
    var isSearching: Bool {
        !searchText.isEmpty || !searchTokens.isEmpty
    }
    
    func addToken(for target: SearchToken.Target, text: String) {
        guard !searchTokens.contains(where: { $0.target == target }) else {
            return
        }
        searchTokens.append(.init(target: target, text: text))
    }
}

fileprivate extension ViewModel {
    private static var indexURL : URL {
        .init(string: "https://lucka-me.github.io/iitc-community-plugins-index/")!
    }
    private static var repository : String { "IITC-CE/Community-plugins" }
    
    func fetchPreviews() async throws {
        defer { isFetching = false }
        
        let index = try await URLSession.shared.decoded(
            [ String : [ String ] ].self, from: Self.indexURL, by: JSONDecoder()
        )
        
        previews = await withTaskGroup(of: PluginPreview?.self) { group in
            for authorAndFilename in index {
                for filename in authorAndFilename.value {
                    group.addTask {
                        guard
                            let metadata = try? await self.metadata(
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

fileprivate extension ViewModel {
    func save(_ preview: PluginPreview, with modelContext: ModelContext) async throws {
        preview.state = .saving
        var succeed = false
        defer { preview.state = succeed ? .saved : .available }
        
        let temporaryURL = try await GitHub.downloadRaw(
            in: Self.repository,
            branch: "master",
            path: "dist/\(preview.author)/\(preview.filename)" + FileConstants.userScriptFilenameSuffix
        )
        
        let fileManager = FileManager.default
        defer {
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
