//
//  UserDefaults.swift
//  IntelStack
//
//  Created by Lucka on 2023-09-18.
//

import Foundation

extension UserDefaults {
    static let shared = UserDefaults(suiteName: FileManager.applicationGroupIdentifier)!
}

extension UserDefaults {
    struct Key {        
        private init() { }
    }
}

extension UserDefaults.Key {
    static let scriptsEnabled = "Scripts.Enabled"
}

extension UserDefaults {
    var scriptsEnabled: Bool {
        set {
            self.set(newValue, forKey: Key.scriptsEnabled)
        }
        get {
            bool(forKey: Key.scriptsEnabled)
        }
    }
}

extension UserDefaults.Key {
    static let externalScriptsBookmark = "ExternalScripts.Bookmark"
}

extension UserDefaults {
    var externalScriptsBookmarkURL: URL? {
        set {
            setBookmark(newValue, forKey: Key.externalScriptsBookmark)
        }
        get {
            bookmark(forKey: Key.externalScriptsBookmark)
        }
    }
}
