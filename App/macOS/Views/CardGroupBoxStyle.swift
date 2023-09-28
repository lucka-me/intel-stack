//
//  CardGroupBoxStyle.swift
//  Intel Stack
//
//  Created by Lucka on 2023-09-27.
//

import Foundation
import SwiftUI

struct CardGroupBoxStyle : GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            configuration.label
            configuration.content
        }
        .padding(12)
        .background(Material.bar, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension GroupBoxStyle where Self == CardGroupBoxStyle {
    static var card: CardGroupBoxStyle { .init() }
}
