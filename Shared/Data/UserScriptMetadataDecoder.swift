//
//  UserScriptMetadataDecoder.swift
//  IntelStack
//
//  Created by Lucka on 2024-01-17.
//

import Foundation

class UserScriptMetadataDecoder {
    func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        return try type.init(from: Implementation(from: string))
    }
}

extension UserScriptMetadataDecoder {
    struct SyntaxError : LocalizedError {
        enum Part : Equatable {
            case opening
            case configuration(line: String)
            case closing
        }
        
        let part: Part
        
        var errorDescription: String? {
            .init(localized: "UserScriptMetadataDecoder.SyntaxError")
        }
        
        var failureReason: String? {
            switch part {
            case .opening:
                return .init(localized: "UserScriptMetadataDecoder.SyntaxError.Opening.Reason")
            case .configuration(let line):
                return .init(localized: "UserScriptMetadataDecoder.SyntaxError.Configuration.Reason \(line)")
            case .closing:
                return .init(localized: "UserScriptMetadataDecoder.SyntaxError.Closing.Reason")
            }
        }
    }
}

fileprivate struct Implementation {
    typealias Items = [ String : String ]

    private static let blockPrefix = "// ==UserScript=="
    private static let blockSuffix = "// ==/UserScript=="
    
    let codingPath: [ CodingKey ] = [ ]
    let userInfo: [ CodingUserInfoKey : Any ] = [ : ]
    
    let items: Items
    
    init(from string: String) throws {
        guard
            let startIndex = string.firstRange(of: Self.blockPrefix)?.upperBound
        else {
            throw UserScriptMetadataDecoder.SyntaxError(part: .opening)
        }
        guard
            let endIndex = string[startIndex ..< string.endIndex].firstRange(of: Self.blockSuffix)?.lowerBound
        else {
            throw UserScriptMetadataDecoder.SyntaxError(part: .closing)
        }
        self.items = try string[startIndex ..< endIndex].components(separatedBy: .newlines)
            .reduce(into: [ : ]) { result, line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                let pattern = /\/\/ *@(.+?) +(.+?) */
                guard let (_, key, value) = try? pattern.wholeMatch(in: trimmed)?.output else {
                    throw UserScriptMetadataDecoder.SyntaxError(part: .configuration(line: line))
                }
                result[.init(key)] = .init(value)
            }
    }
}

extension Implementation : Decoder {
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        .init(KeyedContainer(decoder: self))
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(
            [ Any ].self,
            .init(codingPath: [ ], debugDescription: "Only Key-Value pair is supported")
        )
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        throw DecodingError.typeMismatch(
            Any.self,
            .init(codingPath: [ ], debugDescription: "Only Key-Value pair is supported")
        )
    }
}

fileprivate struct KeyedContainer<Key: CodingKey> : KeyedDecodingContainerProtocol {
    let decoder: Implementation
    
    let codingPath: [ CodingKey ] = [ ]
    
    var allKeys: [ Key ] {
        decoder.items.keys.compactMap { .init(stringValue: $0) }
    }
    
    func contains(_ key: Key) -> Bool {
        decoder.items[key.stringValue] != nil
    }
    
    func decodeNil(forKey key: Key) throws -> Bool {
        let raw = try rawValue(of: key)
        return raw.isEmpty // Impossible
    }
    
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        try value(of: key)
    }
    
    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        try rawValue(of: key)
    }
    
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        try value(of: key)
    }
    
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        try value(of: key)
    }
    
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        try value(of: key)
    }
    
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        try value(of: key)
    }
    
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        try value(of: key)
    }
    
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        try value(of: key)
    }
    
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        try value(of: key)
    }
    
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        try value(of: key)
    }
    
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        try value(of: key)
    }
    
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        try value(of: key)
    }
    
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        try value(of: key)
    }
    
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        try value(of: key)
    }
    
    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
        let rawValue = try rawValue(of: key)
        switch type {
        case let aType as LosslessStringConvertible.Type:
            return aType.init(rawValue) as! T
        case let aType as any RawRepresentable<String>.Type:
            guard let value = aType.init(rawValue: rawValue) else {
                throw DecodingError.typeMismatch(
                    type,
                    .init(
                        codingPath: [ key ],
                        debugDescription: "The raw value \(rawValue) can not be converted into \(type)"
                    )
                )
            }
            return value as! T
        // TODO: Add more cases if needed
        default:
            throw DecodingError.typeMismatch(
                type,
                .init(
                    codingPath: [ key ],
                    debugDescription: "Unable to convert \(rawValue) into \(type)"
                )
            )
        }
    }
    
    func nestedContainer<NestedKey>(
        keyedBy type: NestedKey.Type, forKey key: Key
    ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        throw DecodingError.typeMismatch(
            type,
            .init(codingPath: [ ], debugDescription: "Nested item is not supported")
        )
    }
    
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(
            [ Any ].self,
            .init(codingPath: [ ], debugDescription: "Nested item is not supported")
        )
    }
    
    func superDecoder() throws -> Decoder {
        decoder
    }
    
    func superDecoder(forKey key: Key) throws -> Decoder {
        throw DecodingError.typeMismatch(
            Implementation.Items.self,
            .init(codingPath: [ ], debugDescription: "Nested item is not supported")
        )
    }
    
    private func rawValue(of key: Key) throws -> String {
        guard let value = decoder.items[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                .init(codingPath: [ key ], debugDescription: "The key \(key) does not exists")
            )
        }
        return value
    }
    
    private func value<Value: LosslessStringConvertible>(of key: Key) throws -> Value {
        let text = try rawValue(of: key)
        guard let result = Value(text) else {
            throw DecodingError.typeMismatch(
                Value.self,
                .init(
                    codingPath: [ key ],
                    debugDescription: "The value \(text) is not a \(Value.self)"
                )
            )
        }
        return result
    }
}
