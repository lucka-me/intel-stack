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
    @State private var method = Method.remote
    @State private var pluginInformation: ExternalPluginInformation? = nil
    @State private var taskError: TaskError? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Picker("AddPluginView.Method", selection: $method) {
                    ForEach(Method.allCases, id: \.rawValue) { method in
                        Text(method.titleKey)
                            .tag(method)
                    }
                }
                .pickerStyle(.segmented)
#if !os(macOS)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
#endif
                
                switch method {
                case .remote:
                    RemoteSection($pluginInformation) { error in
                        taskError = error
                        isAlertPresented = true
                    }
                case .code:
                    CodeSection($pluginInformation)
                }
                
                if let pluginInformation {
                    Section {
                        sectionContent(of: pluginInformation)
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
#if !os(macOS)
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
        .onChange(of: method) {
            pluginInformation = nil
        }
    }
    
    @ViewBuilder
    private var cancelButton : some View {
#if os(macOS)
        Button("AddPluginView.Cancel") {
            dismiss()
        }
#else
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
        Button("AddPluginView.Add") {
            trySave(information: information)
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
            self.taskError = .localized(error: error)
            self.isAlertPresented = true
            return
        } catch {
            self.taskError = .generic(error: error)
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

fileprivate enum Method : Int, CaseIterable {
    case remote
    case code
    
    var titleKey: LocalizedStringKey {
        switch self {
        case .remote:
            return "AddPluginView.Method.Remote"
        case .code:
            return "AddPluginView.Method.Code"
        }
    }
}

fileprivate enum TaskError: Error, LocalizedError {
    case externalLocationUnavailable
    case invalidHTTPResponse(statusCode: Int)
    case invalidMetadata(key: String)
    case invalidURL
    case metadataUnavailable
    case localized(error: LocalizedError)
    case generic(error: Error)
    
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
        case .localized(let error):
            return error.errorDescription
        case .generic(let error):
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
        case .localized(let error):
            return error.failureReason
        case .generic(let error):
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
#if !os(macOS)
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
            onError(.localized(error: error))
        } catch {
            onError(.generic(error: error))
        }
    }
}

fileprivate struct CodeSection: View {
    @Binding private var pluginInformation: ExternalPluginInformation?
    
    @FocusState private var isCodeEditorFocused: Bool
    
    @State private var filename = ""
    @State private var code = ""
    
    init(_ pluginInformation: Binding<ExternalPluginInformation?>) {
        self._pluginInformation = pluginInformation
    }
    
    var body: some View {
        Section {
            TextEditor(text: $code)
                .monospaced()
                .focused($isCodeEditorFocused)
#if !os(iOS)
                // On iOS, the height of row will increase beyond the frame height
                // This bug exists on visionOS but will not occurs if paste directly
                .frame(height: 180)
#endif
#if os(visionOS)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
#endif
            TextField("AddPluginView.CodeSection.Filename", text: $filename)
        }
        .onAppear {
            isCodeEditorFocused = true
        }
        .onChange(of: code, initial: false, updateInformation)
    }
    
    private func updateInformation() {
        guard
            let metadata = try? UserScriptMetadata(content: code),
            let id = metadata["id"],
            let categoryText = metadata["category"],
            let category = Plugin.Category(rawValue: categoryText)
        else {
            pluginInformation = nil
            return
        }
        if filename.isEmpty {
            filename = metadata.name.components(separatedBy: "/\\:?%*|\"<>").joined()
        }
        pluginInformation = .init(
            metadata: metadata,
            filename: filename,
            provider: .code(code: code),
            id: id,
            category: category,
            author: metadata["author"],
            version: metadata["version"]
        )
    }
}
