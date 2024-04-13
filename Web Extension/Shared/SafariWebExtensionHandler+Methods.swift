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
        let mainScriptURL = fileManager.mainScriptURL
        
        guard fileManager.fileExists(at: mainScriptURL) else {
            return [
                "error": String(localized: "SafariWebExtensionHandler.Error.MainScriptNotExists")
            ]
        }
        
        let mainScriptContent: String
        let mainScriptMetadata: MainScriptMetadata
        do {
            mainScriptContent = try String(contentsOf: mainScriptURL)
            mainScriptMetadata = try UserScriptMetadataDecoder()
                .decode(MainScriptMetadata.self, from: mainScriptContent)
        } catch let error as LocalizedError {
            return [ "error": error.errorDescription ?? error.localizedDescription ]
        } catch {
            return [ "error": error.localizedDescription ]
        }

        let context = ModelContext(.default)
        var descriptor = FetchDescriptor(predicate: #Predicate<Plugin> { $0.enabled })
        descriptor.propertiesToFetch = [ \.name, \.scriptDescription, \.filename, \.isInternal, \.version ]
        let plugins: [ Plugin ]
        do {
            plugins = try context.fetch(descriptor)
        } catch let error as LocalizedError {
            return [ "error": error.errorDescription ?? error.localizedDescription ]
        } catch {
            return [ "error": error.localizedDescription ]
        }
        
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
        
        var warnings: [ String ] = [ ]
        for plugin in plugins {
            var fileURL: URL
            if plugin.isInternal {
                fileURL = fileManager.internalPluginsDirectoryURL
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
            } catch let error as LocalizedError {
                let description = error.errorDescription ?? error.localizedDescription
                warnings.append(
                    .init(localized: "SafariWebExtensionHandler.Error.UnableToLoadPlugin \(plugin.name) \(description)")
                )
            } catch {
                warnings.append(
                    .init(localized: "SafariWebExtensionHandler.Error.UnableToLoadPlugin \(plugin.name) \(error.localizedDescription)")
                )
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
        if !warnings.isEmpty {
            response["warnings"] = warnings
        }
        
        return response
    }
}

extension SafariWebExtensionHandler {
    func getPopupContentData() -> [ String : Any ] {
        let context = ModelContext(.default)
        
        var response: [ String : Any ] = [ : ]
        
#if os(macOS)
        response["platform"] = "macOS"
#endif
        
        do {
            try ScriptManager.sync(with: context)
        } catch let error as LocalizedError {
            response["error"] = error.errorDescription ?? error.localizedDescription
            return response
        } catch {
            response["error"] = error.localizedDescription
            return response
        }
        
        var descriptor = FetchDescriptor<Plugin>(sortBy: [ .init(\.name, order: .forward) ])
        descriptor.propertiesToFetch = [ \.uuid, \.name, \.categoryValue, \.enabled ]
        
        let plugins: [ Plugin ]
        do {
            plugins = try context.fetch(descriptor)
        } catch let error as LocalizedError {
            response["error"] = error.errorDescription ?? error.localizedDescription
            return response
        } catch {
            response["error"] = error.localizedDescription
            return response
        }
        
        guard !plugins.isEmpty else {
            response["error"] = String(localized: "SafariWebExtensionHandler.NoPlugin")
            return response
        }
        
        let categoriedPlugins: [ String : [ Plugin ] ] = plugins.reduce(into: [ : ]) { result, item in
            var value = result[item.categoryValue] ?? [ ]
            value.append(item)
            result[item.categoryValue] = value
        }
        
        response["categories"] = categoriedPlugins.sorted { $0.key < $1.key }.map { category in
            [
                "name": category.key,
                "plugins": category.value.map { item in
                    [
                        "uuid": item.uuid.uuidString,
                        "name": item.displayName,
                        "enabled": item.enabled
                    ]
                }
            ]
        }
        
        response["scriptsEnabled"] = UserDefaults.shared.scriptsEnabled
        
        return response
    }
}

extension SafariWebExtensionHandler {
    func setPluginEnabled(with arguments: [ String : Any ]) -> [ String : Any ] {
        guard
            let uuidString = arguments["uuid"] as? String,
            let uuid = UUID(uuidString: uuidString)
        else {
            return [
                "error" : String(localized: "SafariWebExtensionHandler.Error.RequestContentMissing \("arguments.uuid")")
            ]
        }
        guard let enable = arguments["enable"] as? Bool else {
            return [
                "error" : String(localized: "SafariWebExtensionHandler.Error.RequestContentMissing \("arguments.enable")")
            ]
        }
        let context = ModelContext(.default)
        var descriptor = FetchDescriptor<Plugin>(predicate: #Predicate { $0.uuid == uuid })
        descriptor.fetchLimit = 1
        descriptor.propertiesToFetch = [ \.enabled ]
        
        do {
            let plugins = try context.fetch(descriptor)
            
            guard let plugin = plugins.first else {
                return [
                    "error" : String(localized: "SafariWebExtensionHandler.Error.PluginNotFound")
                ]
            }
            
            plugin.enabled = enable
            
            try context.save()
        } catch let error as LocalizedError {
            return [ "error" : error.errorDescription ?? error.localizedDescription ]
        } catch {
            return [ "error" : error.localizedDescription ]
        }
        
        return [ "succeed" : true ]
    }
}
