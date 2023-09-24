//
//  UserDefaults+Bookmark.swift
//  IntelStack
//
//  Created by Lucka on 2023-09-20.
//

import Foundation

extension UserDefaults {
    func bookmark(forKey defaultName: String) -> URL? {
        guard let bookmarkData = data(forKey: defaultName) else {
            return nil
        }
        var bookmarkDataIsStale = false
        #if os(macOS)
        guard
            let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                bookmarkDataIsStale: &bookmarkDataIsStale
            )
        else {
            return nil
        }
        #else
        guard
            let url = try? URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &bookmarkDataIsStale)
        else {
            return nil
        }
        #endif
        if bookmarkDataIsStale {
            setBookmark(url, forKey: defaultName)
        }
        return url
    }
    
    func setBookmark(_ url: URL?, forKey defaultName: String) {
        guard let url else {
            let value: Data? = nil
            set(value, forKey: defaultName)
            return
        }
        #if os(macOS)
        guard let bookmark = try? url.bookmarkData(options: .withSecurityScope) else { return }
        #else
        guard let bookmark = try? url.bookmarkData() else { return }
        #endif
        set(bookmark, forKey: defaultName)
        return
    }
}
