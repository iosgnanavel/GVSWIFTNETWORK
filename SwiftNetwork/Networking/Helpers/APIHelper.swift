//
//  APIHelper.swift
//  SwiftNetwork
//
//  Created by iosgnanavel on 05/20/2021.
//  Copyright (c) 2021 iosgnanavel. All rights reserved.
//

import Foundation

public struct APIHelper {
    public static func rejectNil(_ source: [String: Any?]) -> [String:Any]? {
        let destination = source.reduce(into: [String: Any]()) { (result, item) in
            if let value = item.value {
                result[item.key] = value
            }
        }

        if destination.isEmpty {
            return nil
        }
        return destination
    }

    public static func rejectNilHeaders(_ source: [String: Any?]) -> [String: String] {
        return source.reduce(into: [String: String]()) { (result, item) in
            if let collection = item.value as? Array<Any?> {
                result[item.key] = collection.filter({ $0 != nil }).map{ "\($0!)" }.joined(separator: ",")
            } else if let value: Any = item.value {
                result[item.key] = "\(value)"
            }
        }
    }

    public static func convertBoolToString(_ source: [String: Any]?) -> [String:Any]? {
        guard let source = source else {
            return nil
        }

        return source.reduce(into: [String: Any](), { (result, item) in
            switch item.value {
            case let xValue as Bool:
                result[item.key] = xValue.description
            default:
                result[item.key] = item.value
            }
        })
    }


    public static func mapValuesToQueryItems(_ source: [String: Any?]) -> [URLQueryItem]? {
        let destination = source.filter({ $0.value != nil}).reduce(into: [URLQueryItem]()) { (result, item) in
            var queryItem: URLQueryItem?
            if let collection = item.value as? Array<Any?> {
                let value = collection.filter({ $0 != nil }).map({"\($0!)"}).joined(separator: ",")
                queryItem = URLQueryItem(name: item.key, value: value)
            } else if let value = item.value {
                queryItem = URLQueryItem(name: item.key, value: "\(value)")
            }
            // Assign User Token for all APIs
            if let queryItemTemp = queryItem {
                /*if item.key == "api_token" {
                    queryItemTemp.value = UserDefaults.standard.string(forKey: "USERTOKEN")
                } else if item.key == "driver_id" {
                    queryItemTemp.value = UserDefaults.standard.string(forKey: "USERID")
                }*/
                result.append(queryItemTemp)
            }
        }

        if destination.isEmpty {
            return nil
        }
        return destination
    }
}

