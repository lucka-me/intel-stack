//
//  OnboardingView.swift
//  App
//
//  Created by Lucka on 2023-09-17.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.alert) private var alert
    @Environment(\.dismiss) private var dismiss
    @Environment(\.updateProgress) private var updateProgress
    @Environment(\.updateScripts) private var updateScripts
    @Environment(\.updateStatus) private var updateStatus
    
    var body: some View {
        VStack {
            Image(AppIcon.current.previewName)
                .resizable()
                .aspectRatio(contentMode: .fit)
#if !os(macOS)
                .mask {
                    appIconShape
                }
                .overlay {
                    appIconShape
                        .stroke(.secondary.opacity(0.5), lineWidth: 1)
                }
#endif
#if os(visionOS)
                .shadow(radius: 5)
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
#if !os(iOS)
            .frame(maxWidth: 400, minHeight: 150)
#endif
            
#if !os(macOS)
            Spacer()
            primaryActionButton
#endif
        }
#if !os(iOS)
        .frame(minWidth: 320, maxWidth: 640, maxHeight: 640, alignment: .top)
#endif
#if os(macOS)
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
            if updateProgress.isFinished {
                Text("OnboardingView.Download.Content.Done")
            } else {
                Text("OnboardingView.Download.Content")
                    .lineLimit(3, reservesSpace: true)
                    .opacity(updateStatus == .updating ? 0 : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay {
                        if updateStatus == .updating {
                            ProgressView(updateProgress)
                        }
                    }
            }
            Spacer()
        } icon: {
            if updateStatus == .updating {
                Image(systemName: "arrow.down.circle.dotted")
                    .foregroundStyle(.blue.gradient)
                    .symbolRenderingMode(.multicolor)
                    .symbolEffect(.pulse, options: .repeating)
            } else if updateProgress.isFinished {
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
            if updateProgress.isFinished {
                dismiss()
            } else {
                Task { await tryDownload() }
            }
        } label: {
            Text(
                updateProgress.isFinished
                ? "OnboardingView.Action.Continue"
                : "OnboardingView.Action.Download"
            )
#if os(iOS)
                .frame(maxWidth: 640)
#endif
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(updateStatus == .updating)
    }
    
#if os(iOS)
    private var appIconShape: RoundedRectangle {
        .init(cornerRadius: 20, style: .continuous)
    }
#elseif os(visionOS)
    private var appIconShape: Circle {
        .init()
    }
#endif
    
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
            try await updateScripts?()
        } catch let error as LocalizedError {
            alert?(.localized(error: error))
        } catch {
            alert?(.generic(error: error))
        }
    }
}

#Preview {
    OnboardingView()
}
