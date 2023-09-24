//
//  ModelContainer+Init.swift
//  IntelStack
//
//  Created by Lucka on 2023-09-22.
//

import Foundation
import SwiftData

extension ModelContainer {
    static var `default`: ModelContainer {
        let container: ModelContainer
        do {
            container = try .init(
                for: Plugin.self,
                configurations: .init(groupContainer: .identifier(FileManager.applicationGroupIdentifier))
            )
        } catch {
            fatalError("Unable to create ModelContainer: \(error)")
        }
        return container
    }
}
