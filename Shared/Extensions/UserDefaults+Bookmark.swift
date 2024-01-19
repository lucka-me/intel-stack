//
//  UserDefaults+Bookmark.swift
//  IntelStack
//
//  Created by Lucka on 2023-09-20.
//

import Foundation

extension UserDefaults {
    // A solution from quoid/userscripts/xcode/Shared/Preferences.swift
    // For macOS, the security-scoped bookmark (created with .withSecurityScope option) is resolvable only in the main
    // app, but not in the app extension, but a non-security-scoped bookmark (or called implicity security scope) is
    // resolvable and accessable in the app extension (really weird).
#if os(macOS)
    fileprivate static let implicitySecurityScopeBookmarkKeySuffix = ".ImplicitySecurityScope"
#endif

    func bookmark(forKey defaultName: String) -> URL? {
        let bookmarkData: Data?
#if os(macOS)
        if Bundle.main.isAppExtension {
            bookmarkData = data(forKey: defaultName + Self.implicitySecurityScopeBookmarkKeySuffix)
        } else {
            bookmarkData = data(forKey: defaultName)
        }
#else
        bookmarkData = data(forKey: defaultName)
#endif
        guard let bookmarkData else { return nil }
        
        var bookmarkDataIsStale = false
        let url: URL?
#if os(macOS)
        if Bundle.main.isAppExtension {
            url = try? .init(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &bookmarkDataIsStale)
            // Prevent updating bookmark in app extension
            bookmarkDataIsStale = false
        } else {
            url = try? .init(
                resolvingSecurityScopedBookmarkData: bookmarkData, bookmarkDataIsStale: &bookmarkDataIsStale
            )
        }
#else
        url = try? .init(
            resolvingSecurityScopedBookmarkData: bookmarkData, bookmarkDataIsStale: &bookmarkDataIsStale
        )
#endif
        if bookmarkDataIsStale, let url, url.startAccessingSecurityScopedResource() {
            setBookmark(url, forKey: defaultName)
            url.stopAccessingSecurityScopedResource()
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
        guard
            let bookmark = try? url.bookmarkData(options: .withSecurityScope),
            let implicitySecurityScopeBookmark = try? url.bookmarkData()
        else {
            return
        }
        set(implicitySecurityScopeBookmark, forKey: defaultName + Self.implicitySecurityScopeBookmarkKeySuffix)
#else
        guard let bookmark = try? url.bookmarkData() else { return }
#endif
        set(bookmark, forKey: defaultName)
        return
    }
}
