//
//  SettingsView.swift
//  App
//
//  Created by Lucka on 2023-09-17.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            ExternalScriptsSection()
            BuildChannelSection()
            AboutSection()
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle("SettingsView.Title")
    }
}

#Preview {
    SettingsView()
}

fileprivate struct ExternalScriptsSection: View {
    @AppStorage(UserDefaults.Key.externalScriptsBookmark) private var bookmark: Data?
    
    #if !os(macOS)
    @Environment(\.openURL) private var openURL
    #endif
    
    @State private var url: URL? = nil
    @State private var isLocationImporterPresented = false
    
    var body: some View {
        Section {
            if let readableExternalScriptLocation {
                Button(readableExternalScriptLocation, systemImage: "folder", action: openLocation)
                    #if os(macOS)
                    .buttonStyle(.borderless)
                    #endif
                Button("SettingsView.ExternalScripts.ChangeLocation", systemImage: "folder.badge.gearshape", role: .destructive) {
                    isLocationImporterPresented = true
                }
            } else {
                Button("SettingsView.ExternalScripts.SelectLocation", systemImage: "folder.badge.plus") {
                    isLocationImporterPresented = true
                }
            }
        } header: {
            Text("SettingsView.ExternalScripts.Title")
        } footer: {
            Text("SettingsView.ExternalScripts.Footer")
        }
        .fileImporter(
            isPresented: $isLocationImporterPresented, allowedContentTypes: [ .folder ]
        ) { result in
            guard
                case .success(let url) = result,
                url.startAccessingSecurityScopedResource()
            else {
                return
            }
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            UserDefaults.shared.externalScriptsBookmarkURL = url
        }
        .task(id: bookmark) {
            // Just simply update the displaying url, other operations should be done in IntelStackApp
            let url: URL?
            if let bookmark {
                url = try? URL(resolvingSecurityScopedBookmarkData: bookmark)
            } else {
                url = nil
            }
            await MainActor.run {
                self.url = url
            }
        }
    }
    
    private var readableExternalScriptLocation: String? {
        guard let url else { return nil }
        return url
            .standardizedFileURL
            .path(percentEncoded: false)
    }
    
    private func openLocation() {
        guard let url else { return }
        #if os(macOS)
        let accessingSecurityScopedResource = url.startAccessingSecurityScopedResource()
        NSWorkspace.shared.open(url)
        if accessingSecurityScopedResource {
            url.stopAccessingSecurityScopedResource()
        }
        #else
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        components.scheme = "shareddocuments"
        guard let urlForFileApp = components.url else { return }
        openURL(urlForFileApp)
        #endif
    }
}

fileprivate struct BuildChannelSection: View {
    @AppStorage(UserDefaults.Key.buildChannel) private var channel: ScriptManager.BuildChannel = .release
    
    var body: some View {
        Section {
            Picker("SettingsView.BuildChannel.Channel", selection: $channel) {
                ForEach(ScriptManager.BuildChannel.allCases, id: \.rawValue) { item in
                    Text(item.rawValue)
                        .textCase(.uppercase)
                        .tag(item)
                }
            }
        } header: {
            Text("SettingsView.BuildChannel.Title")
        } footer: {
            Text("SettingsView.BuildChannel.Footer")
        }
    }
}

fileprivate struct AboutSection: View {
    var body: some View {
        Section {
            Link(destination: .init(string: "https://github.com/lucka-me/intel-stack")!) {
                Label("SettingsView.About.SourceCode", systemImage: "swift")
            }
            
            Link(destination: .init(string: "https://iitc.app")!) {
                Label("SettingsView.About.IITCWebsite", systemImage: "link")
            }
            
            if
                let shortVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                let versionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
                let version = Int(versionString) {
                Label(shortVersionString, systemImage: "app.badge.checkmark")
                    .badge(version)
            }
        } header: {
            Text("SettingsView.About.Title")
        } footer: {
            Text("SettingsView.About.Footer \(Image(systemName: "heart.fill"))")
        }
    }
}
