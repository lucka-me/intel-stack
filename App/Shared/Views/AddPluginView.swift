//
//  AddPluginView.swift
//  Intel Stack
//
//  Created by Lucka on 2024-01-05.
//

import SwiftUI

struct AddPluginView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @FocusState private var isURLTextFieldFocused: Bool
    
    @State private var pluginInformation: ExternalPluginInformation? = nil
    
    @State private var isAlertPresented = false
    @State private var isDownloading = false
    @State private var taskError: TaskError? = nil
    @State private var urlText: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("AddPluginView.URL", text: $urlText, prompt: Text("AddPluginView.URL.Prompt"))
                        .lineLimit(1)
#if os(iOS)
                        .keyboardType(.URL)
#endif
                        .disableAutocorrection(true)
                        .focused($isURLTextFieldFocused)
                        .onSubmit {
                            Task { await tryDownload() }
                        }
                        .disabled(isDownloading)
                    
                    Button("AddPluginView.Download") {
                        Task { await tryDownload() }
                    }
                    .disabled(urlText.isEmpty || isDownloading || pluginInformation != nil)
                }
                
                if let pluginInformation {
                    Section {
                        sectionContent(of: pluginInformation)
                        Button("AddPluginView.Add") {
                            trySave(information: pluginInformation)
                        }
                    } header: {
                        Text("AddPluginView.PluginInformation.Title")
                    }
                }
            }
#if os(macOS)
            .frame(minWidth: 360, minHeight: 360)
#endif
            .formStyle(.grouped)
            .navigationTitle("AddPluginView.Title")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .alert(isPresented: $isAlertPresented, error: taskError) { _ in } message: { error in
                if let reason = error.failureReason {
                    Text(reason)
                }
            }
            .onAppear {
                isURLTextFieldFocused = true
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    cancelButton
                }
            }
        }
    }
    
    @ViewBuilder
    private var cancelButton : some View {
#if os(iOS)
        Button {
            dismiss()
        } label: {
            Label("AddPluginView.Cancel", systemImage: "xmark")
                .labelStyle(.iconOnly)
                .fontWeight(.bold)
        }
        .foregroundStyle(.secondary)
        .buttonStyle(.bordered)
        .mask {
            Circle()
        }
#elseif os(macOS)
        Button("AddPluginView.Cancel") {
            dismiss()
        }
#endif
    }
    
    @ViewBuilder
    private func sectionContent(of information: ExternalPluginInformation) -> some View {
        row(of: "AddPluginView.PluginInformation.Name", content: information.metadata.name)
        row(of: "AddPluginView.PluginInformation.ID", content: Text(information.id).monospaced())
        row(of: "AddPluginView.PluginInformation.Category", content: information.category.rawValue)
        if let author = information.author {
            row(of: "AddPluginView.PluginInformation.Author", content: author)
        }
        if let version = information.version {
            row(of: "AddPluginView.PluginInformation.Version", content: Text(version).monospaced())
        }
    }
    
    @ViewBuilder
    private func row(of titleKey: LocalizedStringKey, content: String) -> some View {
        row(of: titleKey, content: Text(content))
    }
    
    @ViewBuilder
    private func row(of titleKey: LocalizedStringKey, content: Text) -> some View {
        HStack {
            Text(titleKey)
            Spacer()
            content
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
    }

    @MainActor
    private func tryDownload() async {
        isDownloading = true
        defer { isDownloading = false }
        
        var urlText = urlText
        // If the URL contains no scheme, URLComponents will generate url as scheme:host, without the slashes
        if !urlText.starts(with: /.*?\/\//) {
            urlText = "https://" + urlText
        }
        
        do {
            guard let downloadURL = URL(string: urlText) else {
                throw TaskError.invalidURL
            }
            let filename = downloadURL.lastPathComponent.replacing(
                FileConstants.userScriptFilenameSuffix, with: ""
            )
            guard !filename.isEmpty else {
                throw TaskError.invalidURL
            }
            
            let (temporaryURL, response) = try await URLSession.shared.download(from: downloadURL)
            
            let fileManager = FileManager.default
            defer {
                if (self.pluginInformation == nil) {
                    try? fileManager.removeItem(at: temporaryURL)
                }
            }
            
            guard let httpResponse = response as? HTTPURLResponse else { return }
            guard httpResponse.statusCode == 200 else {
                throw TaskError.invalidHTTPResponse(statusCode: httpResponse.statusCode)
            }
            
            let content = try String(contentsOf: temporaryURL)
            guard let metadata = try UserScriptMetadata(content: content) else {
                throw TaskError.metadataUnavailable
            }
            guard let id = metadata["id"] else {
                throw TaskError.invalidMetadata(key: "id")
            }
            guard
                let categoryString = metadata["category"],
                let category = Plugin.Category(rawValue: categoryString)
            else {
                throw TaskError.invalidMetadata(key: "category")
            }
            
            var information = ExternalPluginInformation(
                metadata: metadata,
                filename: filename,
                temporaryURL: temporaryURL,
                id: id,
                category: category
            )
            
            information.author = metadata["author"]
            information.version = metadata["version"]
            
            self.pluginInformation = information
        } catch let error as TaskError {
            self.taskError = error
            self.isAlertPresented = true
        } catch {
            self.taskError = .genericError(error: error)
            self.isAlertPresented = true
        }
    }
    
    private func trySave(information: ExternalPluginInformation) {
        guard
            let externalURL = UserDefaults.shared.externalScriptsBookmarkURL,
            externalURL.startAccessingSecurityScopedResource()
        else {
            self.taskError = .externalLocationUnavailable
            self.isAlertPresented = true
            return
        }
        defer {
            externalURL.stopAccessingSecurityScopedResource()
        }
        
        let destinationURL = externalURL
            .appending(path: information.filename)
            .appendingPathExtension(FileConstants.userScriptExtension)
        
        let fileManager = FileManager.default
        do {
            try fileManager.moveItem(at: information.temporaryURL, to: destinationURL)
            guard
                let plugin = Plugin(
                    metadata: information.metadata, isInternal: false, filename: information.filename
                )
            else {
                return
            }
            modelContext.insert(plugin)
            try modelContext.save()
            dismiss()
        } catch {
            self.taskError = .genericError(error: error)
            self.isAlertPresented = true
            return
        }
    }
}

fileprivate struct ExternalPluginInformation {
    let metadata: UserScriptMetadata

    let filename: String
    let temporaryURL: URL
    
    let id: String
    let category: Plugin.Category
    
    var author: String? = nil
    var version: String? = nil
}

fileprivate enum TaskError: Error, LocalizedError {
    case externalLocationUnavailable
    case invalidHTTPResponse(statusCode: Int)
    case invalidMetadata(key: String)
    case invalidURL
    case metadataUnavailable
    case genericError(error: Error)
    
    var errorDescription: String? {
        switch self {
        case .externalLocationUnavailable:
            return .init(localized: "AddPluginView.TaskError.ExternalLocationUnavailable")
        case .invalidHTTPResponse(let statusCode):
            return .init(localized: "AddPluginView.TaskError.InvalidHTTPResponse \(statusCode)")
        case .invalidMetadata(let key):
            return .init(localized: "AddPluginView.TaskError.InvalidMetadata \(key)")
        case .invalidURL:
            return .init(localized: "AddPluginView.TaskError.InvalidURL")
        case .metadataUnavailable:
            return .init(localized: "AddPluginView.TaskError.MetadataUnavailable")
        case .genericError(let error):
            return error.localizedDescription
        }
    }
    
    var failureReason: String? {
        switch self {
        case .externalLocationUnavailable:
            return .init(localized: "AddPluginView.TaskError.ExternalLocationUnavailable.Reason")
        case .invalidHTTPResponse(let statusCode):
            return .init(localized: "AddPluginView.TaskError.InvalidHTTPResponse.Reason \(statusCode)")
        case .invalidMetadata(let key):
            return .init(localized: "AddPluginView.TaskError.InvalidMetadata.Reason \(key)")
        case .invalidURL:
            return .init(localized: "AddPluginView.TaskError.InvalidURL.Reason")
        case .metadataUnavailable:
            return .init(localized: "AddPluginView.TaskError.MetadataUnavailable.Reason")
        case .genericError(let error):
            return error.localizedDescription
        }
    }
}
