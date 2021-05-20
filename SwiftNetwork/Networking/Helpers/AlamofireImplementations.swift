//
//  AlamofireImplementations.swift
//  SwiftNetwork
//
//  Created by iosgnanavel on 05/20/2021.
//  Copyright (c) 2021 iosgnanavel. All rights reserved.
//

import Foundation
import Alamofire

class AlamofireRequestBuilderFactory: RequestBuilderFactory {
    func getNonDecodableBuilder<T>() -> RequestBuilder<T>.Type {
        return AlamofireRequestBuilder<T>.self
    }

    func getBuilder<T:Decodable>() -> RequestBuilder<T>.Type {
        return AlamofireDecodableRequestBuilder<T>.self
    }
}

// Store manager to retain its reference
private var managerStore: [String: Alamofire.Session] = [:]

// Sync queue to manage safe access to the store manager
private let syncQueue = DispatchQueue(label: "thread-safe-sync-queue", attributes: .concurrent)

open class AlamofireRequestBuilder<T>: RequestBuilder<T> {
    required public init(method: String, URLString: String, parameters: [String : Any]?, isBody: Bool, headers: [String : String] = [:]) {
        super.init(method: method, URLString: URLString, parameters: parameters, isBody: isBody, headers: headers)
    }

    /**
     May be overridden by a subclass if you want to control the session
     configuration.
     */
    open func createSessionManager() -> Alamofire.Session {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = buildHeaders().dictionary
        return Alamofire.Session(configuration: configuration)
    }

    /**
     May be overridden by a subclass if you want to control the Content-Type
     that is given to an uploaded form part.

     Return nil to use the default behavior (inferring the Content-Type from
     the file extension).  Return the desired Content-Type otherwise.
     */
    open func contentTypeForFormPart(fileURL: URL) -> String? {
        return nil
    }

    /**
     May be overridden by a subclass if you want to control the request
     configuration (e.g. to override the cache policy).
     */
    open func makeRequest(manager: Session, method: HTTPMethod, encoding: ParameterEncoding, headers: [String: String]) -> DataRequest {
        return manager.request(URLString, method: method, parameters: parameters, encoding: encoding, headers: HTTPHeaders(headers))
    }

    override open func execute(_ completion: @escaping (_ response: Response<T>?, _ error: Error?) -> Void) {
        let managerId: String = UUID().uuidString
        // Create a new manager for each request to customize its request header
        let manager = createSessionManager()
        syncQueue.async(flags: .barrier) {
            managerStore[managerId] = manager
        }

        let encoding: ParameterEncoding = isBody ? JSONDataEncoding() : URLEncoding()

        let xMethod = Alamofire.HTTPMethod(rawValue: method)
        let fileKeys = parameters == nil ? [] : parameters!.filter { $1 is URL || $1 is Data}
            .map { $0.0 }

        if fileKeys.count > 0 {
            let request = manager.upload(multipartFormData: { mpForm in
                for (mapFormkey, mapFormValue) in self.parameters! {
                    switch mapFormValue {
                    case let fileData as Data:
                        mpForm.append(fileData, withName: mapFormkey, fileName: "\(mapFormkey)1.jpg", mimeType: "image/jpg")
                    case let fileURL as URL:
                        if let mimeType = self.contentTypeForFormPart(fileURL: fileURL) {
                            mpForm.append(fileURL, withName: mapFormkey, fileName: fileURL.lastPathComponent, mimeType: mimeType)
                        } else {
                            mpForm.append(fileURL, withName: mapFormkey)
                        }
                    case let string as String:
                        mpForm.append(string.data(using: String.Encoding.utf8)!, withName: mapFormkey)
                    case let number as NSNumber:
                        mpForm.append(number.stringValue.data(using: String.Encoding.utf8)!, withName: mapFormkey)
                    default:
                        fatalError("Unprocessable value \(mapFormValue) with key \(mapFormkey)")
                    }
                }
            }, to: URLString, method: xMethod, headers: nil)

            request.uploadProgress { progress in
                if let onProgressReady = self.onProgressReady {
                    onProgressReady(progress)
                }
            }
            processRequest(request: request, managerId, completion)
        } else {
            let request = makeRequest(manager: manager, method: xMethod, encoding: encoding, headers: headers)
            if let onProgressReady = self.onProgressReady {
                onProgressReady(request.downloadProgress)
            }
            processRequest(request: request, managerId, completion)
        }

    }

    fileprivate func processRequest(request: DataRequest, _ managerId: String, _ completion: @escaping (_ response: Response<T>?, _ error: Error?) -> Void) {
        if let credential = self.credential {
            request.authenticate(with: credential)
        }

        let cleanupRequest = {
            syncQueue.async(flags: .barrier) {
                _ = managerStore.removeValue(forKey: managerId)
            }
        }

        let validatedRequest = request.validate()

        switch T.self {
        case is String.Type:
            validatedRequest.responseString(completionHandler: { (stringResponse) in
                cleanupRequest()
                switch stringResponse.result {
                case let .failure(error):
                    completion(
                        nil,
                        ErrorResponse.error(stringResponse.response?.statusCode ?? 500, stringResponse.data, error)
                    )
                    return
                case let .success(value):
                    completion(
                        Response(
                            response: stringResponse.response!,
                            body: (value as! T)
                        ),
                        nil
                    )
                }
            })
        case is URL.Type:
            validatedRequest.responseData(completionHandler: { (dataResponse) in
                cleanupRequest()
                do {
                    switch dataResponse.result {
                    case .failure(_):
                        throw DownloadException.responseFailed
                    case let .success(data):
                        guard !data.isEmpty else {
                            throw DownloadException.responseDataMissing
                        }

                        guard let request = request.request else {
                            throw DownloadException.requestMissing
                        }

                        let fileManager = FileManager.default
                        let urlRequest = try request.asURLRequest()
                        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let requestURL = try self.getURL(from: urlRequest)

                        var requestPath = try self.getPath(from: requestURL)

                        if let headerFileName = self.getFileName(fromContentDisposition: dataResponse.response?.allHeaderFields["Content-Disposition"] as? String) {
                            requestPath = requestPath.appending("/\(headerFileName)")
                        }

                        let filePath = documentsDirectory.appendingPathComponent(requestPath)
                        let directoryPath = filePath.deletingLastPathComponent().path

                        try fileManager.createDirectory(atPath: directoryPath, withIntermediateDirectories: true, attributes: nil)
                        try data.write(to: filePath, options: .atomic)

                        completion(
                            Response(
                                response: dataResponse.response!,
                                body: (filePath as! T)
                            ),
                            nil
                        )
                    }

                } catch let requestParserError as DownloadException {
                    completion(nil, ErrorResponse.error(400, dataResponse.data, requestParserError))
                } catch let error {
                    completion(nil, ErrorResponse.error(400, dataResponse.data, error))
                }
                return
            })
        case is Void.Type:
            validatedRequest.responseData(completionHandler: { (voidResponse) in
                cleanupRequest()
                switch voidResponse.result {
                case let .failure(error):
                    completion(
                        nil,
                        ErrorResponse.error(voidResponse.response?.statusCode ?? 500, voidResponse.data, error)
                    )
                    return
                case let .success(data):
                    completion(
                        Response(
                            response: voidResponse.response!,
                            body: nil),
                        nil
                    )
                }
            })
        default:
            validatedRequest.responseData(completionHandler: { (dataResponse) in
                cleanupRequest()
                switch dataResponse.result {
                case let .failure(error):
                    completion(
                        nil,
                        ErrorResponse.error(dataResponse.response?.statusCode ?? 500, dataResponse.data, error)
                    )
                    return
                case let .success(data):
                    completion(
                        Response(
                            response: dataResponse.response!,
                            body: (data as! T)
                        ),
                        nil
                    )
                }
            })
        }
    }

    open func buildHeaders() -> HTTPHeaders {
        var httpHeaders = HTTPHeaders.default
        for (key, value) in self.headers {
            httpHeaders[key] = value
        }
        return httpHeaders
    }

    fileprivate func getFileName(fromContentDisposition contentDisposition : String?) -> String? {
        guard let contentDisposition = contentDisposition else {
            return nil
        }

        let items = contentDisposition.components(separatedBy: ";")

        var filename : String? = nil

        for contentItem in items {
            let filenameKey = "filename="
            guard let range = contentItem.range(of: filenameKey) else {
                break
            }

            filename = contentItem
            return filename?
                .replacingCharacters(in: range, with:"")
                .replacingOccurrences(of: "\"", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return filename

    }

    fileprivate func getPath(from url : URL) throws -> String {
        guard var path = URLComponents(url: url, resolvingAgainstBaseURL: true)?.path else {
            throw DownloadException.requestMissingPath
        }

        if path.hasPrefix("/") {
            path.remove(at: path.startIndex)
        }

        return path

    }

    fileprivate func getURL(from urlRequest : URLRequest) throws -> URL {
        guard let url = urlRequest.url else {
            throw DownloadException.requestMissingURL
        }

        return url
    }

}

fileprivate enum DownloadException : Error {
    case responseDataMissing
    case responseFailed
    case requestMissing
    case requestMissingPath
    case requestMissingURL
}

public enum AlamofireDecodableRequestBuilderError: Error {
    case emptyDataResponse
    case nilHTTPResponse
    case jsonDecoding(DecodingError)
    case generalError(Error)
}
open class AlamofireDecodableRequestBuilder<T: Decodable>: AlamofireRequestBuilder<T> {
    override fileprivate func processRequest(request: DataRequest, _ managerId: String, _ completion: @escaping (_ response: Response<T>?, _ error: Error?) -> Void) {
        if let credential = self.credential {
            request.authenticate(with: credential)
        }

        let cleanupRequest = {
            syncQueue.async(flags: .barrier) {
                _ = managerStore.removeValue(forKey: managerId)
            }
        }
        let validatedRequest = request.validate()

        switch T.self {
        case is String.Type:
            validatedRequest.responseString(completionHandler: { (stringResponse) in
                cleanupRequest()
                switch stringResponse.result {
                case let .failure(error):
                    completion(
                        nil,
                        ErrorResponse.error(stringResponse.response?.statusCode ?? 500, stringResponse.data, error)
                    )
                    return
                case let .success(value):
                    completion(
                        Response(
                            response: stringResponse.response!,
                            body: (value as! T)
                        ),
                        nil
                    )
                }
            })
        case is Void.Type:
            validatedRequest.responseData(completionHandler: { (voidResponse) in
                cleanupRequest()
                switch voidResponse.result {
                case let .failure(error):
                    completion(
                        nil,
                        ErrorResponse.error(voidResponse.response?.statusCode ?? 500, voidResponse.data, error)
                    )
                    return
                case .success(_):
                    completion(
                        Response(
                            response: voidResponse.response!,
                            body: nil),
                        nil
                    )
                }
            })
        case is Data.Type:
            validatedRequest.responseData(completionHandler: { (dataResponse) in
                cleanupRequest()
                switch dataResponse.result {
                case let .failure(error):
                    completion(
                        nil,
                        ErrorResponse.error(dataResponse.response?.statusCode ?? 500, dataResponse.data, error)
                    )
                    return
                case .success(_):
                    completion(
                        Response(
                            response: dataResponse.response!,
                            body: (dataResponse.data as! T)
                        ),
                        nil
                    )
                }
            })
        default:
            validatedRequest.responseData(completionHandler: { (dataResponse: AFDataResponse<Data>) in
                cleanupRequest()
                func callSuccessResponse(_ data: Data) {
                    guard !data.isEmpty else {
                        completion(nil, ErrorResponse.error(-1, nil, AlamofireDecodableRequestBuilderError.emptyDataResponse))
                        return
                    }

                    guard let httpResponse = dataResponse.response else {
                        completion(nil, ErrorResponse.error(-2, nil, AlamofireDecodableRequestBuilderError.nilHTTPResponse))
                        return
                    }

                    var responseObj: Response<T>? = nil

                    let decodeResult: (decodableObj: T?, error: Error?) = CodableHelper.decode(T.self, from: data)
                    if decodeResult.error == nil {
                        responseObj = Response(response: httpResponse, body: decodeResult.decodableObj)
                    }
                    // Debug Log
                    if isDebugAPI {
                        var responseMessage: Any?
                        var errorMessage: Any?
                        if decodeResult.error == nil {
                            do {
                                let json =  try JSONSerialization.jsonObject(with: data, options: .mutableContainers)
                                responseMessage = json
                            } catch let error {
                                errorMessage = error
                            }
                        } else {
                            errorMessage = String(describing: decodeResult.error)
                        }
                        self.printLogResponse(request: request, response: responseMessage, error: errorMessage)
                    }
                    completion(responseObj, decodeResult.error)
                }
                switch dataResponse.result {
                case let .failure(error):
                    if dataResponse.data == nil {
                        completion(nil, ErrorResponse.error(dataResponse.response?.statusCode ?? 500, dataResponse.data, error))
                    } else {
                        callSuccessResponse(dataResponse.data!)
                    }
                    
//                    guard dataResponse.result.isSuccess || dataResponse.data != nil else {
//                        completion(nil, ErrorResponse.error(dataResponse.response?.statusCode ?? 500, dataResponse.data, dataResponse.result.error!))
//                        //self.processRequestAPI(request: request, dataResponse: dataResponse, error: errorResponse, completion: completion)
//                        return
//                    }
                    return
                case let .success(data):
                    callSuccessResponse(data)
                }
            })
        }
    }
    func printLogResponse(request: DataRequest, response: Any?, error: Any?) {
        if isDebugAPI {
            apiPrint("API Date:\n\(Date())")
            apiPrint("--------------------API START--------------------")
            apiPrint("Request:-\n\(request.request?.debugDescription ?? "")")
            if let responseString = response {
                apiPrint("Response:\n\(responseString)")
            }
            if let errorString = error {
                apiPrint("Error:\n\(errorString)")
            }
            apiPrint("--------------------API END--------------------")
        }
    }
}
// MARK: - DEBUG
#if DEBUG
func apiPrint(_ object: String) {print("\(object)")}
let isDebugAPI = true
#else
func apiPrint(_ object: String) {}
let isDebugAPI = false
#endif

// MARK: - Connectivity
class Connectivity {
    class func isConnectedToInternet() ->Bool {
        return NetworkReachabilityManager()!.isReachable
    }
}
// MARK: - MyError
enum MyError: Error {
    case runtimeError(String)
}
