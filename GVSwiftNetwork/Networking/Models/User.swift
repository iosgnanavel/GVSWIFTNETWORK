//
//  User.swift
//  SwiftNetwork
//
//  Created by iosgnanavel on 05/20/2021.
//  Copyright (c) 2021 iosgnanavel. All rights reserved.
//

import Foundation

// MARK: - UserLoginResponseData
public struct UserLoginResponse: Codable {
    public var status: Bool?
    public var message: String?
    public var statusCode: Int?
    public var data: UserLoginResponseData?

    enum CodingKeys: String, CodingKey {
        case status, message
        case statusCode = "status_code"
        case data
    }

    public init(status: Bool?, message: String?, statusCode: Int?, data: UserLoginResponseData?) {
        self.status = status
        self.message = message
        self.statusCode = statusCode
        self.data = data
    }
}

// MARK: - UserLoginResponseData
public struct UserLoginResponseData: Codable {
    public var apiToken: String?
    public var userID: Int?

    enum CodingKeys: String, CodingKey {
        case apiToken = "token"
        case userID = "user_id"
    }

    public init(apiToken: String?, userID: Int?) {
        self.apiToken = apiToken
        self.userID = userID
    }
}
