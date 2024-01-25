//
//  ReadViewHeightModifier.swift
//  Intel Stack
//
//  Created by Lucka on 2024-01-24.
//

import SwiftUI

extension View {
    func readSize(height: Binding<CGFloat>) -> some View {
        modifier(ReadViewHeightModifier(height: height))
    }
}

fileprivate struct ReadViewHeightModifier: ViewModifier {
    private struct ViewHeight: PreferenceKey {
        static var defaultValue: CGFloat = .zero
        
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }
    
    @Binding var height: CGFloat
    
    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: ViewHeight.self, value: proxy.size.height)
                }
            }
            .onPreferenceChange(ViewHeight.self) { newValue in
                height = newValue
            }
    }
}
