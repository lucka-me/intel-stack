//
//  AppIcon.swift
//  Intel Stack
//
//  Created by Lucka on 2023-10-11.
//

import Foundation
#if os(iOS)
import UIKit
#endif

enum AppIcon: String, CaseIterable, Identifiable {
    case primary = "AppIcon"
    
    static var current: AppIcon {
#if os(iOS)
        guard
            let iconName = UIApplication.shared.alternateIconName,
            let icon = AppIcon(rawValue: iconName)
        else {
            return .primary
        }
        return icon
#else
        return .primary
#endif
    }
    
    var id: String { self.rawValue }
    var previewName: String { self.rawValue + "-Preview" }
}
