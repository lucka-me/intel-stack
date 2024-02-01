//
//  PluginCardView.swift
//  Intel Stack
//
//  Created by Lucka on 2024-02-01.
//

import SwiftUI

struct PluginCardView<Header: View, Labels: View, Footer: View>: View {
    @ViewBuilder private let header: () -> Header
    @ViewBuilder private let labels: () -> Labels
    @ViewBuilder private let footer: () -> Footer
    
    private let description: String?
    
    init(
        description: String?,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder labels: @escaping () -> Labels,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.header = header
        self.labels = labels
        self.footer = footer
        self.description = description
    }
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading) {
                FlexHStack(alignment: .leading) {
                    labels()
                }
                .font(.caption)
                .lineLimit(1)
                
                Spacer()
                
                Text(description ?? .init(localized: "PluginCardView.NoDescriptions"))
                    .italic(description == nil)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3, reservesSpace: true)
                
                HStack {
                    Spacer()
                    footer()
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .italic()
                        .lineLimit(1, reservesSpace: true)
                }
            }
        } label: {
            header()
                .lineLimit(2)
        }
        .fixedSize(horizontal: false, vertical: false)
#if os(macOS)
        .groupBoxStyle(.card)
#endif
    }
}
