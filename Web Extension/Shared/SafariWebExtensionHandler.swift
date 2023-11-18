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
            let message = requestItem.userInfo?[SFExtensionMessageKey] as? [ String : Any ],
            let method = message["method"] as? String
        else {
            responseContent = [ "error" : "Unable to parse the request" ]
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
                responseContent = [ "error" : "[arguments] is missing" ]
                break
            }
            responseContent = setPluginEnabled(with: arguments)
        case "setScriptsEnabled":
            guard let enable = arguments?["enable"] as? Bool else {
                responseContent = [ "error" : "[arguments][enable] is missing" ]
                break
            }
            UserDefaults.shared.scriptsEnabled = enable
            responseContent = [ "succeed" : true ]
        default:
            responseContent = [ "error" : "Unknown method: \(method)" ]
        }
    }
}
