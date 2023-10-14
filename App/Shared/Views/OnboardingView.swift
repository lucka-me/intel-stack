//
//  OnboardingView.swift
//  App
//
//  Created by Lucka on 2023-09-17.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scriptManager) private var scriptManager
    
    @State private var isDownloading = false
    
    private var downloadProgress = Progress()
    
    var body: some View {
        VStack {
            Image(AppIcon.current.previewName)
                .resizable()
                .aspectRatio(contentMode: .fit)
#if os(iOS)
                .mask {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.secondary.opacity(0.5), lineWidth: 1)
                }
#endif
                .frame(width: 96, height: 96, alignment: .center)
                .padding(.top, 40)
            
            Text("OnboardingView.Title")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 40)
            
            ScrollView(.vertical) {
                Grid(alignment: .topLeading, horizontalSpacing: 20, verticalSpacing: 20) {
                    downloadRow
                    // TODO: Maybe more instructions
                }
                .frame(maxWidth: 400)
            }
#if os(macOS)
            .frame(maxWidth: 400, minHeight: 150)
#endif
            
#if os(iOS)
            Spacer()
            primaryActionButton
#endif
        }
#if os(macOS)
        .frame(minWidth: 320, maxWidth: 640, maxHeight: 640, alignment: .top)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                primaryActionButton
            }
        }
#endif
        .padding([ .horizontal, .bottom ])
    }
    
    @ViewBuilder
    private var downloadRow: some View {
        row("OnboardingView.Download") {
            if downloadProgress.isFinished {
                Text("OnboardingView.Download.Content.Done")
            } else {
                Text("OnboardingView.Download.Content")
                    .lineLimit(3, reservesSpace: true)
                    .opacity(isDownloading ? 0 : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay {
                        if isDownloading {
                            ProgressView(downloadProgress)
                        }
                    }
            }
            Spacer()
        } icon: {
            if isDownloading {
                Image(systemName: "arrow.down.circle.dotted")
                    .foregroundStyle(.blue.gradient)
                    .symbolRenderingMode(.multicolor)
                    .symbolEffect(.pulse, options: .repeating)
            } else if downloadProgress.isFinished {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green.gradient)
            } else {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.blue.gradient)
            }
        }
    }
   
    @ViewBuilder
    private var primaryActionButton: some View {
        Button {
            if downloadProgress.isFinished {
                dismiss()
            } else {
                Task { await tryDownload() }
            }
        } label: {
            Text(
                downloadProgress.isFinished
                ? "OnboardingView.Action.Continue"
                : "OnboardingView.Action.Download"
            )
#if os(iOS)
                .frame(maxWidth: 640)
#endif
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isDownloading)
    }
    
    @ViewBuilder
    private func row<Icon: View, Content: View>(
        _ titleKey: LocalizedStringKey,
        @ViewBuilder content: () -> Content,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        GridRow {
            icon()
                .font(.largeTitle)
                .symbolRenderingMode(.multicolor)
                .gridColumnAlignment(.center)
            VStack(alignment: .leading, spacing: 6) {
                Text(titleKey)
                    .foregroundStyle(.primary)
                    .font(.headline)
                    .fontWeight(.semibold)
                content()
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .gridColumnAlignment(.leading)
        }
    }
    
    private func tryDownload() async {
        do {
            let internalPluginNames = try ScriptManager.internalPluginNames
            
            await MainActor.run {
                downloadProgress.totalUnitCount = .init(internalPluginNames.count + 1)
                downloadProgress.completedUnitCount = 0
                isDownloading = true
            }
            
            try await ScriptManager.downloadMainScript(from: .release)
            await MainActor.run { downloadProgress.completedUnitCount += 1 }
            
            try await withThrowingTaskGroup(of: Void.self) { group in
                for name in internalPluginNames {
                    group.addTask {
                        try await ScriptManager.downloadInternalPlugin(name, from: .release)
                        await MainActor.run { downloadProgress.completedUnitCount += 1 }
                    }
                }
                
                try await group.waitForAll()
            }
        } catch {
            // TODO: Present the error
            print(error)
        }
        
        await MainActor.run {
            isDownloading = false
        }
    }
}

#Preview {
    OnboardingView()
}
