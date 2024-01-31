//
//  CapsuleModifier.swift
//  Intel Stack
//
//  Created by Lucka on 2024-01-28.
//

import SwiftUI

extension View {
    func capsule(_ color: Color) -> some View {
        modifier(CapsuleModifier(color: color))
    }
}

fileprivate struct CapsuleModifier: ViewModifier {
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.gradient, in: Capsule(style: .continuous))
    }
}
