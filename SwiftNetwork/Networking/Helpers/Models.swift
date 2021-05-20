//
//  Models.swift
//  SwiftNetwork
//
//  Created by iosgnanavel on 05/20/2021.
//  Copyright (c) 2021 iosgnanavel. All rights reserved.
//

import Foundation

protocol JSONEncodable {
    func encodeToJSON() -> Any
}

public enum ErrorResponse : Error {
    case error(Int, Data?, Error)
}

open class Response<T> {
    public let statusCode: Int
    public let header: [String: String]
    public let body: T?

    public init(statusCode: Int, header: [String: String], body: T?) {
        self.statusCode = statusCode
        self.header = header
        self.body = body
    }

    public convenience init(response: HTTPURLResponse, body: T?) {
        let rawHeader = response.allHeaderFields
        var header = [String:String]()
        for case let (key, value) as (String, String) in rawHeader {
            header[key] = value
        }
        self.init(statusCode: response.statusCode, header: header, body: body)
    }
}
