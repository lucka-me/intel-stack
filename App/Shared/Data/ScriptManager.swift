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
    
    var mainScriptVersion: String? = nil
    
    private init() { }
}
