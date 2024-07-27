//
//  UserDefaults+Bookmark.swift
//  IntelStack
//
//  Created by Lucka on 2023-09-20.
//

import Foundation

extension UserDefaults {
    func bookmark(forKey defaultName: String) -> URL? {
        let securityScopedBookmark: Data?
#if os(macOS)
        let isAppExtension = Bundle.main.isAppExtension
        if isAppExtension {
            securityScopedBookmark = syncBookmark(forKey: defaultName)
        } else {
            securityScopedBookmark = data(forKey: defaultName)
        }
#else
        securityScopedBookmark = data(forKey: defaultName)
#endif
        guard let securityScopedBookmark else { return nil }
        
        var bookmarkDataIsStale = false
        let url = try? URL(
            resolvingSecurityScopedBookmarkData: securityScopedBookmark,
            bookmarkDataIsStale: &bookmarkDataIsStale
        )
        if bookmarkDataIsStale, let url, url.startAccessingSecurityScopedResource() {
#if os(macOS)
            if isAppExtension {
                // Update the "extension-al" security-scoped bookmark only
                if let updatedBookmark = try? url.bookmarkData(options: .withSecurityScope) {
                    set(updatedBookmark, forKey: Self.extensionDataKey(forKey: defaultName))
                }
            } else {
                setBookmark(url, forKey: defaultName)
            }
#else
            setBookmark(url, forKey: defaultName)
#endif
            url.stopAccessingSecurityScopedResource()
        }
        
        return url
    }
    
    func setBookmark(_ url: URL?, forKey defaultName: String) {
#if os(macOS)
        let appSyncKey = Self.appSyncKey(forKey: defaultName)
#endif
        guard let url else {
            let value: Data? = nil
            set(value, forKey: defaultName)
#if os(macOS)
            set(value, forKey: appSyncKey)
#endif
            return
        }
#if os(macOS)
        guard
            let bookmark = try? url.bookmarkData(options: .withSecurityScope),
            let implicitySecurityScopeBookmark = try? url.bookmarkData()
        else {
            return
        }
        set(implicitySecurityScopeBookmark, forKey: appSyncKey)
#else
        guard let bookmark = try? url.bookmarkData() else { return }
#endif
        set(bookmark, forKey: defaultName)
        return
    }
}

#if os(macOS)
fileprivate extension UserDefaults {
    // A solution from quoid/userscripts/xcode/Shared/Preferences.swift
    // On macOS, a security-scoped bookmark (created with .withSecurityScope option) is only resolvable in the bundle
    // in which it was created, but not in other bundles. A non-security-scoped (or called implicity security scope)
    // bookmark is resolvable in other bundles UNTIL reboot.
    // So we sync the URL from app to extension(s) by:
    // 1. In the App, when storing the bookmark, we also set a "global" non-security-scoped bookmark
    // 2. In every extension, we hold an "extension-al" non-security-scoped bookmark and an "extension-al" security-
    //    scoped bookmark
    // 3. In extension, when we need the URL, we get both the non-security-scoped bookmarks first
    //    3.1. If they are equal, the URL is not changed, we use the "extension-al" security-scoped bookmark directly
    //    3.2. If not, the URL was changed, we resolve the "global" one and update the "extension-al" security-scoped bookmark
    static let implicitySecurityScopeBookmarkKeySuffix = "ImplicitySecurityScope"
    static let bundleIdentifier = Bundle.main.bundleIdentifier!
    
    // Generate key for "global" non-security-scoped bookmark
    static func appSyncKey(forKey defaultName: String) -> String {
        "\(defaultName).\(Self.implicitySecurityScopeBookmarkKeySuffix)"
    }
    
    // Generate key for "extension-al" security-scoped bookmark
    static func extensionDataKey(forKey defaultName: String) -> String {
        "\(defaultName).\(Self.bundleIdentifier)"
    }
    
    // Generate key for "extension-al" non-security-scoped bookmark
    static func extensionSyncKey(forKey defaultName: String) -> String {
        "\(defaultName).\(Self.bundleIdentifier).\(Self.implicitySecurityScopeBookmarkKeySuffix)"
    }
    
    func syncBookmark(forKey defaultName: String) -> Data? {
        let extensionDataKey = Self.extensionDataKey(forKey: defaultName)
        let extensionSyncKey = Self.extensionSyncKey(forKey: defaultName)
        guard
            let appSyncData = data(forKey: Self.appSyncKey(forKey: defaultName))
        else {
            let value: Data? = nil
            set(value, forKey: extensionSyncKey)
            set(value, forKey: extensionDataKey)
            return value
        }
        let extensionSyncData = data(forKey: extensionSyncKey)
        guard extensionSyncData != appSyncData else {
            // Already synced
            return data(forKey: extensionDataKey)
        }
        var bookmarkDataIsStale = false
        guard
            let url = try? URL(resolvingBookmarkData: appSyncData, bookmarkDataIsStale: &bookmarkDataIsStale),
            url.startAccessingSecurityScopedResource(),
            let syncedData = try? url.bookmarkData(options: .withSecurityScope)
        else {
            let value: Data? = nil
            set(value, forKey: extensionSyncKey)
            set(value, forKey: extensionDataKey)
            return nil
        }
        url.stopAccessingSecurityScopedResource()
        set(appSyncData, forKey: extensionSyncKey)
        set(syncedData, forKey: extensionDataKey)
        return syncedData
    }
}
#endif
