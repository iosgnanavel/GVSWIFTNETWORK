//
//  UserAPI.swift
//  SwiftNetwork
//
//  Created by iosgnanavel on 05/20/2021.
//  Copyright (c) 2021 iosgnanavel. All rights reserved.
//

import Foundation
import Alamofire
import CoreLocation


open class UserAPI {
    /**
     Logs user into the system
     - GET /user/login
     - parameter username: (String) The user name for login
     - parameter password: (String) The password for login in clear text
     - parameter deviceID: (String) The device ID for identify the user device

     - returns: response<UserLoginResponse>
     */
    open class func loginUser(username: String, password: String, deviceID: String, completion: @escaping ((_ data: UserLoginResponse?,_ error: Error?) -> Void)) {
        loginUserWithRequestBuilder(username: username, password: password, deviceID: deviceID).execute { (response, error) -> Void in
            completion(response?.body, error)
        }
    }
    
    private class func loginUserWithRequestBuilder(username: String, password: String, deviceID: String) -> RequestBuilder<UserLoginResponse> {
        let path = "/user/login"
        let URLString = SwiftNetworkClientAPI.basePath + path
        let parameters: [String: Any]? = nil
        var url = URLComponents(string: URLString)
        url?.queryItems = APIHelper.mapValuesToQueryItems([
            "email": username,
            "password": password,
            "deviceID": deviceID
        ])
        let requestBuilder: RequestBuilder<UserLoginResponse>.Type = SwiftNetworkClientAPI.requestBuilderFactory.getBuilder()
        return requestBuilder.init(method: "POST", URLString: (url?.string ?? URLString), parameters: parameters, isBody: false)
    }
}
