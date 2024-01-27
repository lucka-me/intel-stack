//
//  AddPluginView.swift
//  Intel Stack
//
//  Created by Lucka on 2024-01-05.
//

import SwiftUI

struct AddPluginView: View {
    @Environment(\.alert) private var alert
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var method = Method.remote
    @State private var pluginInformation: ExternalPluginInformation? = nil
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
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
                        RemoteSection($pluginInformation)
                    case .code:
                        CodeSection($pluginInformation)
                    }
                    
                    if let pluginInformation {
                        Section {
                            sectionContent(of: pluginInformation)
                                .lineLimit(1)
                        } header: {
                            Text("AddPluginView.PluginInformation.Title")
                        } footer: {
                            Text("AddPluginView.PluginInformation.Footer")
                        }
                    }
                }
                .onChange(of: pluginInformation, initial: false) { oldValue, newValue in
                    if oldValue == nil, newValue != nil {
                        // The bug of TextEditor / TextField in Form / List makes the height unlimited,
                        // When parsing successes, scroll to bottom
                        proxy.scrollTo(FormPosition.saveButton, anchor: .bottom)
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
            Text(information.metadata.id)
                .monospaced()
        }
        LabeledContent(
            "AddPluginView.PluginInformation.Category",
            value: information.metadata.category.rawValue
        )
        if let author = information.metadata.author {
            LabeledContent("AddPluginView.PluginInformation.Author", value: author)
        }
        if let version = information.metadata.version {
            LabeledContent("AddPluginView.PluginInformation.Version") {
                Text(version)
                    .monospaced()
            }
        }
        Button("AddPluginView.Add") {
            trySave(information: information)
        }
        .id(FormPosition.saveButton)
    }
    
    private func trySave(information: ExternalPluginInformation) {
        guard
            let externalURL = UserDefaults.shared.externalScriptsBookmarkURL,
            externalURL.startAccessingSecurityScopedResource()
        else {
            alert?(.localized(error: TaskError.externalLocationUnavailable))
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
            alert?(.localized(error: error))
            return
        } catch {
            alert?(.generic(error: error))
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

fileprivate enum FormPosition : Int, Hashable {
    case saveButton
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
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .externalLocationUnavailable:
            return .init(localized: "AddPluginView.TaskError.ExternalLocationUnavailable")
        case .invalidURL:
            return .init(localized: "AddPluginView.TaskError.InvalidURL")
        }
    }
    
    var failureReason: String? {
        switch self {
        case .externalLocationUnavailable:
            return .init(localized: "AddPluginView.TaskError.ExternalLocationUnavailable.Reason")
        case .invalidURL:
            return .init(localized: "AddPluginView.TaskError.InvalidURL.Reason")
        }
    }
}

fileprivate struct ExternalPluginInformation : Equatable {
    static func == (lhs: ExternalPluginInformation, rhs: ExternalPluginInformation) -> Bool {
        lhs.metadata.id == rhs.metadata.id &&
        lhs.metadata.category == rhs.metadata.category &&
        lhs.filename == rhs.filename
    }
    
    let metadata: PluginMetadata
    let provider: CodeProvider
    
    var filename: String
}

fileprivate struct RemoteSection: View {
    @Binding private var pluginInformation: ExternalPluginInformation?
    
    @Environment(\.alert) private var alert
    
    @FocusState private var isTextFieldFocused: Bool
    
    @State private var isDownloading = false
    @State private var urlText: String = ""
    
    init(_ pluginInformation: Binding<ExternalPluginInformation?>) {
        self._pluginInformation = pluginInformation
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
            
            let temporaryURL = try await URLSession.shared.download(from: downloadURL)
            
            let fileManager = FileManager.default
            defer {
                if (self.pluginInformation == nil) {
                    try? fileManager.removeItem(at: temporaryURL)
                }
            }
            
            let content = try String(contentsOf: temporaryURL)
            let metadata = try UserScriptMetadataDecoder().decode(PluginMetadata.self, from: content)
            
            self.pluginInformation = .init(
                metadata: metadata,
                provider: .temporaryFile(url: temporaryURL),
                filename: filename
            )
        } catch let error as LocalizedError {
            alert?(.localized(error: error))
        } catch {
            alert?(.generic(error: error))
        }
    }
}

fileprivate struct CodeSection: View {
    @Binding private var pluginInformation: ExternalPluginInformation?
    
    @FocusState private var isCodeEditorFocused: Bool
    
    @State private var code = ""
    @State private var filename = ""
    
    init(_ pluginInformation: Binding<ExternalPluginInformation?>) {
        self._pluginInformation = pluginInformation
    }
    
    var body: some View {
        Section {
            TextEditor(text: $code)
                .monospaced()
                .focused($isCodeEditorFocused)
#if os(macOS)
                // .lineLimit(_:reservesSpace:) does not work at all
                // On iOS, the height of row will increase beyond the frame height
                // This bug exists on visionOS but will not occurs if paste without editing
                // If the bug is fixed or there are other workarounds, remove these.
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
        .onChange(of: filename) {
            if pluginInformation?.filename != filename {
                pluginInformation?.filename = filename
            }
        }
    }
    
    private func updateInformation() {
        guard let metadata = try? UserScriptMetadataDecoder().decode(PluginMetadata.self, from: code) else {
            pluginInformation = nil
            return
        }
        var filename = self.filename
        if filename.isEmpty {
            filename = metadata.name.components(separatedBy: "/\\:?%*|\"<>").joined()
        }
        pluginInformation = .init(
            metadata: metadata,
            provider: .code(code: code),
            filename: filename
        )
        if self.filename != filename {
            self.filename = filename
        }
    }
}
