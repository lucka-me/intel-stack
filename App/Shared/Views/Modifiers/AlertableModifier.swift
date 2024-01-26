//
//  AlertableModifier.swift
//  Intel Stack
//
//  Created by Lucka on 2024-01-26.
//

import SwiftUI

enum AlertableError: Error, LocalizedError {
    case localized(error: LocalizedError)
    case generic(error: Error)
    
    var errorDescription: String? {
        switch self {
        case .localized(let error):
            return error.errorDescription ?? error.localizedDescription
        case .generic(let error):
            return error.localizedDescription
        }
    }
        
    var failureReason: String? {
        switch self {
        case .localized(let error):
            return error.failureReason ?? error.localizedDescription
        case .generic(let error):
            return error.localizedDescription
        }
    }
}

typealias AlertAction = (AlertableError) -> Void

extension EnvironmentValues {
    var alert: AlertAction? {
        get { self[AlertEnvironmentKey.self] }
        set { self[AlertEnvironmentKey.self] = newValue }
    }
}

extension View {
    func alertable() -> some View {
        modifier(AlertableModifier())
    }
}

fileprivate struct AlertableModifier: ViewModifier {
    @State private var currentError: AlertableError? = nil
    @State private var isAlertPresented = false
    
    func body(content: Content) -> some View {
        content
            .environment(\.alert, makeAlert(_:))
            .alert(isPresented: $isAlertPresented, error: currentError) { _ in } message: { error in
                if let reason = error.failureReason {
                    Text(reason)
                }
            }
    }
    
    private func makeAlert(_ error: AlertableError) {
        currentError = error
        isAlertPresented = true
    }
}

fileprivate struct AlertEnvironmentKey: EnvironmentKey {
    static let defaultValue: AlertAction? = nil
}
