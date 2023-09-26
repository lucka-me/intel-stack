//
//  URL.swift
//  IntelStack
//
//  Created by Lucka on 2023-09-25.
//

import Foundation

extension URL {
    init(resolvingSecurityScopedBookmarkData data: Data, bookmarkDataIsStale: inout Bool) throws {
        #if os(macOS)
        try self.init(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            bookmarkDataIsStale: &bookmarkDataIsStale
        )
        #else
        try self.init(resolvingBookmarkData: data, bookmarkDataIsStale: &bookmarkDataIsStale)
        #endif
    }
    
    init(resolvingSecurityScopedBookmarkData data: Data) throws {
        var bookmarkDataIsStale = false
        try self.init(resolvingSecurityScopedBookmarkData: data, bookmarkDataIsStale: &bookmarkDataIsStale)
    }
}
