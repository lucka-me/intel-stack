//
//  ExternalFileMonitor.swift
//  Intel Stack
//
//  Created by Lucka on 2023-10-04.
//

import Foundation

class ExternalFileMonitor {
    let url: URL
    
    private let accessingSecurityScopedResource: Bool
    private let dispatchSourceObject: DispatchSourceFileSystemObject
    
    init(url: URL, action: @escaping (URL) -> Void) {
        self.url = url
        self.accessingSecurityScopedResource = self.url.startAccessingSecurityScopedResource()
        
        let descriptor = open(self.url.path(percentEncoded: false), O_EVTONLY)
        self.dispatchSourceObject = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: .write, queue: .global(qos: .background)
        )
        self.dispatchSourceObject.setEventHandler {
            action(self.url)
        }
        self.dispatchSourceObject.resume()
    }
    
    deinit {
        self.dispatchSourceObject.cancel()
        close(dispatchSourceObject.handle)
        if accessingSecurityScopedResource {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
