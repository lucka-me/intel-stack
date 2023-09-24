//
//  SafariWebExtensionHandler+Persistence.swift
//  Web Extension
//
//  Created by Lucka on 2023-09-21.
//

import Foundation
import SwiftData

extension SafariWebExtensionHandler {
    func getCodeForInjecting() -> [ String ] {
        guard UserDefaults.shared.scriptsEnabled else { return [ ] }
        
        var scripts: [ String ] = [ ]
        
        let fileManager = FileManager.default
        if fileManager.fileExists(at: FileConstants.mainScriptURL),
           let content = try? String(contentsOf: FileConstants.mainScriptURL) {
            scripts.append(content)
        }
        
        let container = ModelContainer.default
        let context = ModelContext(container)
        var descriptor = FetchDescriptor(predicate: #Predicate<Plugin> { $0.enabled && $0.isInternal })
        descriptor.propertiesToFetch = [ \.filename ]
        guard let plugins = try? context.fetch(descriptor) else { return scripts }
        
        let pluginScripts: [ String ] = plugins.compactMap { plugin in
            let fileURL = FileConstants.internalPluginsDirectoryURL
                .appending(path: plugin.filename)
                .appendingPathExtension(FileConstants.userScriptExtension)
            guard fileManager.fileExists(at: fileURL) else { return nil }
            return try? .init(contentsOf: fileURL)
        }
        scripts.append(contentsOf: pluginScripts)
        
        return scripts
    }
}

extension SafariWebExtensionHandler {
    func getPopupContentData() -> [ String : Any ] {
        let container = ModelContainer.default
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Plugin>(sortBy: [ .init(\.name, order: .forward) ])
        descriptor.propertiesToFetch = [ \.uuid, \.name, \.categoryValue, \.enabled ]
        guard let plugins = try? context.fetch(descriptor) else { return [ : ] }
        let categoriedPlugins: [ String : [ Plugin ] ] = plugins.reduce(into: [ : ]) { result, item in
            var value = result[item.categoryValue] ?? [ ]
            value.append(item)
            result[item.categoryValue] = value
        }
        
        let categories = Plugin.Category.allCases.map { category in
            [
                "name" : category.rawValue,
                "plugins": categoriedPlugins[category.rawValue]?.map { item in
                    [
                        "uuid": item.uuid.uuidString,
                        "name": item.displayName,
                        "enabled": item.enabled
                    ]
                } ?? [ ]
            ]
        }
        
        return [ "categories": categories ]
    }
}

extension SafariWebExtensionHandler {
    func setPluginEnabled(with arguments: [ String : Any ]) -> [ String : Any ] {
        guard
            let uuidString = arguments["uuid"] as? String,
            let uuid = UUID(uuidString: uuidString),
            let enable = arguments["enable"] as? Bool
        else {
            return [ : ]
        }
        let container = ModelContainer.default
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Plugin>(predicate: #Predicate { $0.uuid == uuid })
        descriptor.fetchLimit = 1
        descriptor.propertiesToFetch = [ \.enabled ]
        guard
            let plugins = try? context.fetch(descriptor),
            let plugin = plugins.first
        else {
            return [ : ]
        }
        plugin.enabled = enable
        try? context.save()
        
        return [ "succeed" : true ]
    }
}
