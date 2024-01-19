//
//  SafariWebExtensionHandler+Persistence.swift
//  Web Extension
//
//  Created by Lucka on 2023-09-21.
//

import Foundation
import SwiftData
#if os(iOS)
import UIKit
#endif

extension SafariWebExtensionHandler {
    func getInjectionData() -> [ String : Any ] {
        guard UserDefaults.shared.scriptsEnabled else { return [ : ] }
        
        let fileManager = FileManager.default
        guard
            fileManager.fileExists(at: FileConstants.mainScriptURL),
            let mainScriptContent = try? String(contentsOf: FileConstants.mainScriptURL),
            let mainScriptMetadata = try? UserScriptMetadataDecoder()
                .decode(MainScriptMetadata.self, from: mainScriptContent)
        else {
            return [ : ]
        }

        let context = ModelContext(.default)
        var descriptor = FetchDescriptor(predicate: #Predicate<Plugin> { $0.enabled })
        descriptor.propertiesToFetch = [ \.name, \.scriptDescription, \.filename, \.isInternal, \.version ]
        guard let plugins = try? context.fetch(descriptor) else { return [ : ] }
        
        var scripts = [ CodeWrapper.wrap(code: mainScriptContent, metadata: mainScriptMetadata) ]
        
        let externalURL: URL?
        let isAccessingSecurityScopedResource: Bool
        if plugins.contains(where: { !$0.isInternal }) {
            externalURL = UserDefaults.shared.externalScriptsBookmarkURL
            isAccessingSecurityScopedResource = externalURL?.startAccessingSecurityScopedResource() ?? false
        } else {
            externalURL = nil
            isAccessingSecurityScopedResource = false
        }
        defer {
            if let externalURL, isAccessingSecurityScopedResource {
                externalURL.stopAccessingSecurityScopedResource()
            }
        }
        
        for plugin in plugins {
            var fileURL: URL
            if plugin.isInternal {
                fileURL = FileConstants.internalPluginsDirectoryURL
            } else if let externalURL {
                fileURL = externalURL
            } else {
                continue
            }
            fileURL.append(path: plugin.filename)
            fileURL.appendPathExtension(FileConstants.userScriptExtension)
            guard fileManager.fileExists(at: fileURL) else { continue }
            do {
                let content = try String(contentsOf: fileURL)
                scripts.append(CodeWrapper.wrap(code: content, plugin: plugin))
            } catch {
                print(error)
            }
        }
        
        var response: [ String : Any ] = [ : ]
#if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            response["device"] = "iPad"
        }
#elseif os(visionOS)
        response["device"] = "vision"
#endif
        response["scripts"] = scripts
        
        return response
    }
}

extension SafariWebExtensionHandler {
    func getPopupContentData() -> [ String : Any ] {
        let context = ModelContext(.default)
        
        var response: [ String : Any ] = [
            "scriptsEnabled" : UserDefaults.shared.scriptsEnabled
        ]
        
        let _ = try? ScriptManager.sync(with: context)
        
        var descriptor = FetchDescriptor<Plugin>(sortBy: [ .init(\.name, order: .forward) ])
        descriptor.propertiesToFetch = [ \.uuid, \.name, \.categoryValue, \.enabled ]
        guard let plugins = try? context.fetch(descriptor) else { return [ : ] }
        let categoriedPlugins: [ String : [ Plugin ] ] = plugins.reduce(into: [ : ]) { result, item in
            var value = result[item.categoryValue] ?? [ ]
            value.append(item)
            result[item.categoryValue] = value
        }
        
        response["categories"] =  Plugin.Category.allCases.map { category in
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
        
        #if os(macOS)
        response["platform"] = "macOS"
        #endif
        
        return response
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
        let context = ModelContext(.default)
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
