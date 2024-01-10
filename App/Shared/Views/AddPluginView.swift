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
    
    @State private var isAlertPresented = false
    @State private var pluginInformation: ExternalPluginInformation? = nil
    @State private var taskError: TaskError? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                RemoteSection($pluginInformation) { error in
                    taskError = error
                    isAlertPresented = true
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
        LabeledContent("AddPluginView.PluginInformation.Name", value: information.metadata.name)
        LabeledContent("AddPluginView.PluginInformation.ID") {
            Text(information.id)
                .monospaced()
        }
        LabeledContent("AddPluginView.PluginInformation.Category", value: information.category.rawValue)
        if let author = information.author {
            LabeledContent("AddPluginView.PluginInformation.Author", value: author)
        }
        if let version = information.version {
            LabeledContent("AddPluginView.PluginInformation.Version") {
                Text(version)
                    .monospaced()
            }
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
        
        do {
            try information.provider.save(to: destinationURL)
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
        } catch let error as LocalizedError {
            self.taskError = .localizedError(error: error)
            self.isAlertPresented = true
            return
        } catch {
            self.taskError = .genericError(error: error)
            self.isAlertPresented = true
            return
        }
    }
}

fileprivate enum CodeProvider {
    case temporaryFile(url: URL)
    case code(code: String)
    
    func save(to destination: URL) throws {
        switch self {
        case .temporaryFile(let url):
            let fileManager = FileManager.default
            try fileManager.moveItem(at: url, to: destination)
        case .code(let code):
            try code.write(to: destination, atomically: true, encoding: .utf8)
        }
    }
}

fileprivate enum TaskError: Error, LocalizedError {
    case externalLocationUnavailable
    case invalidHTTPResponse(statusCode: Int)
    case invalidMetadata(key: String)
    case invalidURL
    case metadataUnavailable
    case localizedError(error: LocalizedError)
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
        case .localizedError(let error):
            return error.errorDescription
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
        case .localizedError(let error):
            return error.failureReason
        case .genericError(let error):
            return error.localizedDescription
        }
    }
}

fileprivate struct ExternalPluginInformation {
    let metadata: UserScriptMetadata

    let filename: String
    let provider: CodeProvider
    
    let id: String
    let category: Plugin.Category
    
    var author: String? = nil
    var version: String? = nil
}

fileprivate struct RemoteSection: View {
    @Binding private var pluginInformation: ExternalPluginInformation?
    
    @FocusState private var isTextFieldFocused: Bool
    
    @State private var isDownloading = false
    @State private var urlText: String = ""
    
    private let onError: (TaskError) -> Void
    
    init(_ pluginInformation: Binding<ExternalPluginInformation?>, onError: @escaping (TaskError) -> Void) {
        self._pluginInformation = pluginInformation
        self.onError = onError
    }
    
    var body: some View {
        Section {
            TextField("AddPluginView.URL", text: $urlText, prompt: Text("AddPluginView.URL.Prompt"))
                .lineLimit(1)
    #if os(iOS)
                .keyboardType(.URL)
    #endif
                .disableAutocorrection(true)
                .focused($isTextFieldFocused)
                .onSubmit {
                    Task { await tryDownload() }
                }
                .disabled(isDownloading)
            
            Button("AddPluginView.Download") {
                Task { await tryDownload() }
            }
            .disabled(urlText.isEmpty || isDownloading || pluginInformation != nil)
        }
        .onAppear {
            isTextFieldFocused = true
        }
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
            
            self.pluginInformation = .init(
                metadata: metadata,
                filename: filename,
                provider: .temporaryFile(url: temporaryURL),
                id: id,
                category: category,
                author: metadata["author"],
                version: metadata["version"]
            )
        } catch let error as TaskError {
            onError(error)
        } catch let error as LocalizedError {
            onError(.localizedError(error: error))
        } catch {
            onError(.genericError(error: error))
        }
    }
}
