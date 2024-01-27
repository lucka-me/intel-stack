//
//  URLSession+HTTP.swift
//  Intel Stack
//
//  Created by Lucka on 2024-01-26.
//

import Combine
import Foundation

enum HTTPResponseError : LocalizedError {
    case invalidResponseType
    case invalidHTTPResponse(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponseType:
            return .init(localized: "HTTPResponseError.InvalidResponseType")
        case .invalidHTTPResponse(let statusCode):
            return .init(localized: "HTTPResponseError.InvalidHTTPResponse \(statusCode)")
        }
    }
    
    var failureReason: String? {
        switch self {
        case .invalidResponseType:
            return .init(localized: "HTTPResponseError.InvalidResponseType.Reason")
        case .invalidHTTPResponse(let statusCode):
            return HTTPURLResponse.localizedString(forStatusCode: statusCode)
        }
    }
}

extension URLSession {
    func data(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.checkHTTP(response: response)
        return data
    }
    
    func decoded<D: TopLevelDecoder, T: Decodable>(
        _ type: T.Type, from url: URL, by decoder: D
    ) async throws -> T where D.Input == Data {
        try decoder.decode(type, from: try await data(from: url))
    }
}

extension URLSession {
    func download(from url: URL) async throws -> URL {
        let (temporaryURL, response) = try await download(from: url)
        let fileManager = FileManager.default
        var succeed = false
        defer {
            if !succeed {
                try? fileManager.removeItem(at: temporaryURL)
            }
        }
        try Self.checkHTTP(response: response)
        succeed = true
        return temporaryURL
    }
}

fileprivate extension URLSession {
    static func checkHTTP(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPResponseError.invalidResponseType
        }
        guard httpResponse.statusCode == 200 else {
            throw HTTPResponseError.invalidHTTPResponse(statusCode: httpResponse.statusCode)
        }
    }
}
