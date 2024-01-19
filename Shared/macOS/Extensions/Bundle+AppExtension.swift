//
//  Bundle+AppExtension.swift
//  Intel Stack
//
//  Created by Lucka on 2024-01-19.
//

import Foundation

extension Bundle {
    // Maybe a bad idea
    var isAppExtension: Bool {
        bundlePath.hasSuffix(".appex")
    }
}
