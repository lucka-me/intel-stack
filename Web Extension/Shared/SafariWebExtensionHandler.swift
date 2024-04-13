//
//  SafariWebExtensionHandler.swift
//  Web Extension
//
//  Created by Lucka on 2023-09-17.
//

import SafariServices

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        var responseContent: [ String : Any ] = [ : ]
        defer {
            let response = NSExtensionItem()
            response.userInfo = [ SFExtensionMessageKey: responseContent ]
            context.completeRequest(returningItems: [ response ], completionHandler: nil)
        }
        
        guard
            let requestItem = context.inputItems.first as? NSExtensionItem,
            let message = requestItem.userInfo?[SFExtensionMessageKey] as? [ String : Any ]
        else {
            responseContent = [ "error" : String(localized: "SafariWebExtensionHandler.Error.NoMessage") ]
            return
        }
        
        guard let method = message["method"] as? String else {
            responseContent = [
                "error" : String(localized: "SafariWebExtensionHandler.Error.RequestContentMissing \("method")")
            ]
            return
        }
        let arguments = message["arguments"] as? [ String : Any ]
        
        switch method {
        case "getInjectionData":
            responseContent = getInjectionData()
        case "getPopupContentData":
            responseContent = getPopupContentData()
        case "setPluginEnabled":
            guard let arguments else {
                responseContent = [
                    "error" : String(localized: "SafariWebExtensionHandler.Error.RequestContentMissing \("arguments")")
                ]
                break
            }
            responseContent = setPluginEnabled(with: arguments)
        case "setScriptsEnabled":
            guard let enable = arguments?["enable"] as? Bool else {
                responseContent = [
                    "error" : String(localized: "SafariWebExtensionHandler.Error.RequestContentMissing \("arguments.enable")")
                ]
                break
            }
            UserDefaults.shared.scriptsEnabled = enable
            responseContent = [ "succeed" : true ]
        default:
            responseContent = [
                "error" : String(localized: "SafariWebExtensionHandler.Error.UnknownMethod \(method)")
            ]
        }
    }
}
