//
//  ScriptManager.swift
//  App
//
//  Created by Lucka on 2023-09-17.
//

import Foundation
import Observation
import SwiftData

@Observable
class ScriptManager {
    static let shared = ScriptManager()
    
    let downloadProgress = Progress()
    
    var mainScriptVersion: String? = nil
    var status = Status.idle
    
    private init() { }
}

extension ScriptManager {
    enum Status: Equatable {
        case downloading
        case idle
    }
}
