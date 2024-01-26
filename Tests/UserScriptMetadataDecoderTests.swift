//
//  UserScriptMetadataDecoderTests.swift
//  Tests
//
//  Created by Lucka on 2024-01-18.
//

import XCTest

@testable
import Intel_Stack

final class UserScriptMetadataDecoderTests: XCTestCase {
    func testDecodeMainScriptMetadata() throws {
        let name = "IITC"
        let description = "Some descriptions"
        let version = "1.0.3"
        let content = """
            // ==UserScript==
            // @name        \(name)
            // @description \(description)
            // @version     \(version)
            // ==/UserScript==
            """
        let decoder = UserScriptMetadataDecoder()
        
        let metadata = try decoder.decode(MainScriptMetadata.self, from: content)

        XCTAssertEqual(metadata.name, name)
        XCTAssertEqual(metadata.description, description)
        XCTAssertEqual(metadata.version, version)
    }
    
    func testDecodePluginMetadata() throws {
        let id = "test-plugin"
        let name = "Test Plugin"
        let category = Plugin.Category.default(value: .highlighter)
        let author = "lucka-me"
        let description = "A testing plugin"
        let updateURL = "https://example.com/plugin.user.js"
        let version = "0.0.1"
        let content = """
            // ==UserScript==
            // @id          \(id)
            // @name        \(name)
            // @category    \(category.rawValue)
            // @author      \(author)
            // @description \(description)
            // @updateURL   \(updateURL)
            // @version     \(version)
            // ==/UserScript==
            """
        let decoder = UserScriptMetadataDecoder()
        
        let metadata = try decoder.decode(PluginMetadata.self, from: content)

        XCTAssertEqual(metadata.id, id)
        XCTAssertEqual(metadata.name, name)
        XCTAssertEqual(metadata.category, category)
        XCTAssertEqual(metadata.author, author)
        XCTAssertEqual(metadata.description, description)
        XCTAssertNil(metadata.downloadURL)
        XCTAssertEqual(metadata.updateURL, updateURL)
        XCTAssertEqual(metadata.version, version)
    }
    
    func testDecodeNoOpening() throws {
        let content = """
            // @name        IITC
            // @version     1.0.3
            // ==/UserScript==
            """
        
        let decoder = UserScriptMetadataDecoder()
        
        XCTAssertThrowsError(
            try decoder.decode(MainScriptMetadata.self, from: content)
        ) { error in
            XCTAssertTrue(error is UserScriptMetadataDecoder.SyntaxError)
            let aError = error as! UserScriptMetadataDecoder.SyntaxError
            XCTAssertEqual(aError.part, .opening)
        }
    }
    
    func testDecodeNoClosing() throws {
        let content = """
            // ==UserScript==
            // @name        IITC
            // @version     1.0.3
            """
        
        let decoder = UserScriptMetadataDecoder()
        
        XCTAssertThrowsError(
            try decoder.decode(MainScriptMetadata.self, from: content)
        ) { error in
            XCTAssertTrue(error is UserScriptMetadataDecoder.SyntaxError)
            let aError = error as! UserScriptMetadataDecoder.SyntaxError
            XCTAssertEqual(aError.part, .closing)
        }
    }
    
    func testDecodeWrongConfigurationFormate() throws {
        let content = """
            // ==UserScript==
            // @name        IITC
            // @version
            // ==/UserScript==
            """
        
        let decoder = UserScriptMetadataDecoder()
        
        XCTAssertThrowsError(
            try decoder.decode(MainScriptMetadata.self, from: content)
        ) { error in
            XCTAssertTrue(error is UserScriptMetadataDecoder.SyntaxError)
            let aError = error as! UserScriptMetadataDecoder.SyntaxError
            XCTAssertEqual(aError.part, .configuration(line: "// @version"))
        }
    }
    
    func testDecodeMissingKey() throws {
        let content = """
            // ==UserScript==
            // @name        IITC
            // @description Some descriptions
            // ==/UserScript==
            """
        
        let decoder = UserScriptMetadataDecoder()
        
        XCTAssertThrowsError(
            try decoder.decode(MainScriptMetadata.self, from: content)
        ) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
}
