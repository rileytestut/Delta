///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
///

import Foundation
import Alamofire

open class DropboxTransportClient {
    public let manager: SessionManager
    public let backgroundManager: SessionManager
    public let longpollManager: SessionManager
    open var accessToken: String
    open var selectUser: String?
    open var pathRoot: Common.PathRoot?
    var baseHosts: [String: String]
    var userAgent: String

    public convenience init(accessToken: String, selectUser: String? = nil, pathRoot: Common.PathRoot? = nil) {
        self.init(accessToken: accessToken, baseHosts: nil, userAgent: nil, selectUser: selectUser, pathRoot: pathRoot)
    }

    public init(accessToken: String, baseHosts: [String: String]?, userAgent: String?, selectUser: String?, sessionDelegate: SessionDelegate? = nil, backgroundSessionDelegate: SessionDelegate? = nil, longpollSessionDelegate: SessionDelegate? = nil, serverTrustPolicyManager: ServerTrustPolicyManager? = nil, sharedContainerIdentifier: String? = nil, pathRoot: Common.PathRoot? = nil) {
        let config = URLSessionConfiguration.default
        let delegate = sessionDelegate ?? SessionDelegate()
        let serverTrustPolicyManager = serverTrustPolicyManager ?? nil

        let manager = SessionManager(configuration: config, delegate: delegate, serverTrustPolicyManager: serverTrustPolicyManager)
        manager.startRequestsImmediately = false

        let backgroundManager = { () -> SessionManager in
            let backgroundConfig = URLSessionConfiguration.background(withIdentifier: "com.dropbox.SwiftyDropbox." + UUID().uuidString)
            if let sharedContainerIdentifier = sharedContainerIdentifier{
                backgroundConfig.sharedContainerIdentifier = sharedContainerIdentifier
            }
            if let backgroundSessionDelegate = backgroundSessionDelegate {
                return SessionManager(configuration: backgroundConfig, delegate: backgroundSessionDelegate, serverTrustPolicyManager: serverTrustPolicyManager)
            }
            return SessionManager(configuration: backgroundConfig, serverTrustPolicyManager: serverTrustPolicyManager)
        }()
        backgroundManager.startRequestsImmediately = false

        let longpollConfig = URLSessionConfiguration.default
        longpollConfig.timeoutIntervalForRequest = 480.0

        let longpollSessionDelegate = longpollSessionDelegate ?? SessionDelegate()

        let longpollManager = SessionManager(configuration: longpollConfig, delegate: longpollSessionDelegate, serverTrustPolicyManager: serverTrustPolicyManager)

        let defaultBaseHosts = [
            "api": "https://api.dropbox.com/2",
            "content": "https://api-content.dropbox.com/2",
            "notify": "https://notify.dropboxapi.com/2",
            ]

        let defaultUserAgent = "OfficialDropboxSwiftSDKv2/\(Constants.versionSDK)"

        self.manager = manager
        self.backgroundManager = backgroundManager
        self.longpollManager = longpollManager
        self.accessToken = accessToken
        self.selectUser = selectUser
        self.pathRoot = pathRoot;
        self.baseHosts = baseHosts ?? defaultBaseHosts
        if let userAgent = userAgent {
            let customUserAgent = "\(userAgent)/\(defaultUserAgent)"
            self.userAgent = customUserAgent
        } else {
            self.userAgent = defaultUserAgent
        }
    }

    open func request<ASerial, RSerial, ESerial>(_ route: Route<ASerial, RSerial, ESerial>,
                        serverArgs: ASerial.ValueType? = nil) -> RpcRequest<RSerial, ESerial> {
        let host = route.attrs["host"]! ?? "api"
        var routeName = route.name
        if route.version > 1 {
            routeName = String(format: "%@_v%d", route.name, route.version)
        }
        let url = "\(self.baseHosts[host]!)/\(route.namespace)/\(routeName)"
        
        let routeStyle: RouteStyle = RouteStyle(rawValue: route.attrs["style"]!!)!

        var rawJsonRequest: Data?
        rawJsonRequest = nil

        if let serverArgs = serverArgs {
            let jsonRequestObj = route.argSerializer.serialize(serverArgs)
            rawJsonRequest = SerializeUtil.dumpJSON(jsonRequestObj)
        } else {
            let voidSerializer = route.argSerializer as! VoidSerializer
            let jsonRequestObj = voidSerializer.serialize(())
            rawJsonRequest = SerializeUtil.dumpJSON(jsonRequestObj)
        }

        let headers = getHeaders(routeStyle, jsonRequest: rawJsonRequest, host: host)

        let customEncoding = SwiftyArgEncoding(rawJsonRequest: rawJsonRequest!)

        let managerToUse = { () -> SessionManager in
            // longpoll requests have a much longer timeout period than other requests
            if type(of: route) ==  type(of: Files.listFolderLongpoll) {
				return self.longpollManager
            }
			return self.manager
        }()

        let request = managerToUse.request(url, method: .post, parameters: ["jsonRequest": rawJsonRequest!], encoding: customEncoding, headers: headers)
        request.task?.priority = URLSessionTask.highPriority
        let rpcRequestObj = RpcRequest(request: request, responseSerializer: route.responseSerializer, errorSerializer: route.errorSerializer)

        request.resume()

        return rpcRequestObj
    }

    struct SwiftyArgEncoding: ParameterEncoding {
        fileprivate let rawJsonRequest: Data

        init(rawJsonRequest: Data) {
            self.rawJsonRequest = rawJsonRequest
        }

        func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
            var urlRequest = urlRequest.urlRequest
            urlRequest!.httpBody = rawJsonRequest
            return urlRequest!
        }
    }

    open func request<ASerial, RSerial, ESerial>(_ route: Route<ASerial, RSerial, ESerial>,
                        serverArgs: ASerial.ValueType, input: UploadBody) -> UploadRequest<RSerial, ESerial> {
        let host = route.attrs["host"]! ?? "api"
        var routeName = route.name
        if route.version > 1 {
            routeName = String(format: "%@_v%d", route.name, route.version)
        }
        let url = "\(self.baseHosts[host]!)/\(route.namespace)/\(routeName)"
        let routeStyle: RouteStyle = RouteStyle(rawValue: route.attrs["style"]!!)!

        let jsonRequestObj = route.argSerializer.serialize(serverArgs)
        let rawJsonRequest = SerializeUtil.dumpJSON(jsonRequestObj)

        let headers = getHeaders(routeStyle, jsonRequest: rawJsonRequest, host: host)

        let request: Alamofire.UploadRequest

        switch input {
        case let .data(data):
            request = self.manager.upload(data, to: url, method: .post, headers: headers)
        case let .file(file):
            request = self.backgroundManager.upload(file, to: url, method: .post, headers: headers)
        case let .stream(stream):
            request = self.manager.upload(stream, to: url, method: .post, headers: headers)
        }
        let uploadRequestObj = UploadRequest(request: request, responseSerializer: route.responseSerializer, errorSerializer: route.errorSerializer)
        request.resume()

        return uploadRequestObj
    }

    open func request<ASerial, RSerial, ESerial>(_ route: Route<ASerial, RSerial, ESerial>,
                        serverArgs: ASerial.ValueType, overwrite: Bool, destination: @escaping (URL, HTTPURLResponse) -> URL) -> DownloadRequestFile<RSerial, ESerial> {
        let host = route.attrs["host"]! ?? "api"
        var routeName = route.name
        if route.version > 1 {
            routeName = String(format: "%@_v%d", route.name, route.version)
        }
        let url = "\(self.baseHosts[host]!)/\(route.namespace)/\(routeName)"
        let routeStyle: RouteStyle = RouteStyle(rawValue: route.attrs["style"]!!)!

        let jsonRequestObj = route.argSerializer.serialize(serverArgs)
        let rawJsonRequest = SerializeUtil.dumpJSON(jsonRequestObj)

        let headers = getHeaders(routeStyle, jsonRequest: rawJsonRequest, host: host)

        weak var _self: DownloadRequestFile<RSerial, ESerial>!

        let destinationWrapper: DownloadRequest.DownloadFileDestination = { url, resp in
            var finalUrl = destination(url, resp)

            if 200 ... 299 ~= resp.statusCode {
                if FileManager.default.fileExists(atPath: finalUrl.path) {
                    if overwrite {
                        do {
                            try FileManager.default.removeItem(at: finalUrl)
                        } catch let error as NSError {
                            print("Error: \(error)")
                        }
                    } else {
                        print("Error: File already exists at \(finalUrl.path)")
                    }
                }
            } else {
                _self.errorMessage = try! Data(contentsOf: url)
                // Alamofire will "move" the file to the temporary location where it already resides,
                // and where it will soon be automatically deleted
                finalUrl = url
            }

            _self.urlPath = finalUrl

            return (finalUrl, [])
        }

        let request = self.backgroundManager.download(url, method: .post, headers: headers, to: destinationWrapper)

        let downloadRequestObj = DownloadRequestFile(request: request, responseSerializer: route.responseSerializer, errorSerializer: route.errorSerializer)
        _self = downloadRequestObj

        request.resume()

        return downloadRequestObj
    }

    public func request<ASerial, RSerial, ESerial>(_ route: Route<ASerial, RSerial, ESerial>,
                        serverArgs: ASerial.ValueType) -> DownloadRequestMemory<RSerial, ESerial> {
        let host = route.attrs["host"]! ?? "api"
        let url = "\(self.baseHosts[host]!)/\(route.namespace)/\(route.name)"
        let routeStyle: RouteStyle = RouteStyle(rawValue: route.attrs["style"]!!)!

        let jsonRequestObj = route.argSerializer.serialize(serverArgs)
        let rawJsonRequest = SerializeUtil.dumpJSON(jsonRequestObj)

        let headers = getHeaders(routeStyle, jsonRequest: rawJsonRequest, host: host)

        let request = self.backgroundManager.request(url, method: .post, headers: headers)

        let downloadRequestObj = DownloadRequestMemory(request: request, responseSerializer: route.responseSerializer, errorSerializer: route.errorSerializer)

        request.resume()

        return downloadRequestObj
    }

    fileprivate func getHeaders(_ routeStyle: RouteStyle, jsonRequest: Data?, host: String) -> HTTPHeaders {
        var headers = ["User-Agent": self.userAgent]
        let noauth = (host == "notify")

        if (!noauth) {
            headers["Authorization"] = "Bearer \(self.accessToken)"
            if let selectUser = self.selectUser {
                headers["Dropbox-Api-Select-User"] = selectUser
            }

            if let pathRoot = self.pathRoot {
                let obj = Common.PathRootSerializer().serialize(pathRoot)
                headers["Dropbox-Api-Path-Root"] = utf8Decode(SerializeUtil.dumpJSON(obj)!)
            }
        }

        if (routeStyle == RouteStyle.Rpc) {
            headers["Content-Type"] = "application/json"
        } else if (routeStyle == RouteStyle.Upload) {
            headers["Content-Type"] = "application/octet-stream"
            if let jsonRequest = jsonRequest {
                let value = asciiEscape(utf8Decode(jsonRequest))
                headers["Dropbox-Api-Arg"] = value
            }
        } else if (routeStyle == RouteStyle.Download) {
            if let jsonRequest = jsonRequest {
                let value = asciiEscape(utf8Decode(jsonRequest))
                headers["Dropbox-Api-Arg"] = value
            }
        }
        return headers
    }
}

open class Box<T> {
    public let unboxed: T
    init (_ v: T) { self.unboxed = v }
}

public enum CallError<EType>: CustomStringConvertible {
    case internalServerError(Int, String?, String?)
    case badInputError(String?, String?)
    case rateLimitError(Auth.RateLimitError, String?, String?, String?)
    case httpError(Int?, String?, String?)
    case authError(Auth.AuthError, String?, String?, String?)
    case accessError(Auth.AccessError, String?, String?, String?)
    case routeError(Box<EType>, String?, String?, String?)
    case clientError(Error?)

    public var description: String {
        switch self {
        case let .internalServerError(code, message, requestId):
            var ret = ""
            if let r = requestId {
                ret += "[request-id \(r)] "
            }
            ret += "Internal Server Error \(code)"
            if let m = message {
                ret += ": \(m)"
            }
            return ret
        case let .badInputError(message, requestId):
            var ret = ""
            if let r = requestId {
                ret += "[request-id \(r)] "
            }
            ret += "Bad Input"
            if let m = message {
                ret += ": \(m)"
            }
            return ret
        case let .authError(error, _, _, requestId):
            var ret = ""
            if let r = requestId {
                ret += "[request-id \(r)] "
            }
            ret += "API auth error - \(error)"
            return ret
        case let .accessError(error, _, _, requestId):
            var ret = ""
            if let r = requestId {
                ret += "[request-id \(r)] "
            }
            ret += "API access error - \(error)"
            return ret
        case let .httpError(code, message, requestId):
            var ret = ""
            if let r = requestId {
                ret += "[request-id \(r)] "
            }
            ret += "HTTP Error"
            if let c = code {
                ret += "\(c)"
            }
            if let m = message {
                ret += ": \(m)"
            }
            return ret
        case let .routeError(box, _, _, requestId):
            var ret = ""
            if let r = requestId {
                ret += "[request-id \(r)] "
            }
            ret += "API route error - \(box.unboxed)"
            return ret
        case let .rateLimitError(error, _, _, requestId):
            var ret = ""
            if let r = requestId {
                ret += "[request-id \(r)] "
            }
            ret += "API rate limit error - \(error)"
            return ret
        case let .clientError(err):
            if let e = err {
                return "\(e)"
            }
            return "An unknown system error"
        }
    }
}

func utf8Decode(_ data: Data) -> String {
    return NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
}

func asciiEscape(_ s: String) -> String {
    var out: String = ""

    for char in s.unicodeScalars {
        var esc = "\(char)"
        if !char.isASCII {
            esc = NSString(format:"\\u%04x", char.value) as String
        } else {
            esc = "\(char)"
        }
        out += esc

    }
    return out
}

public enum RouteStyle: String {
    case Rpc = "rpc"
    case Upload = "upload"
    case Download = "download"
    case Other
}

public enum UploadBody {
    case data(Data)
    case file(URL)
    case stream(InputStream)
}

/// These objects are constructed by the SDK; users of the SDK do not need to create them manually.
///
/// Pass in a closure to the `response` method to handle a response or error.
open class Request<RSerial: JSONSerializer, ESerial: JSONSerializer> {
    let responseSerializer: RSerial
    let errorSerializer: ESerial

    init(responseSerializer: RSerial, errorSerializer: ESerial) {
        self.errorSerializer = errorSerializer
        self.responseSerializer = responseSerializer
    }

    func handleResponseError(_ response: HTTPURLResponse?, data: Data?, error: Error?) -> CallError<ESerial.ValueType> {
        let requestId = response?.allHeaderFields["X-Dropbox-Request-Id"] as? String
        if let code = response?.statusCode {
            switch code {
            case 500...599:
                var message = ""
                if let d = data {
                    message = utf8Decode(d)
                }
                return .internalServerError(code, message, requestId)
            case 400:
                var message = ""
                if let d = data {
                    message = utf8Decode(d)
                }
                return .badInputError(message, requestId)
            case 401:
                let json = SerializeUtil.parseJSON(data!)
                switch json {
                case .dictionary(let d):
                    return .authError(Auth.AuthErrorSerializer().deserialize(d["error"]!), getStringFromJson(json: d, key: "user_message"), getStringFromJson(json: d, key: "error_summary"), requestId)
                default:
                    fatalError("Failed to parse error type")
                }
            case 403:
                let json = SerializeUtil.parseJSON(data!)
                switch json {
                case .dictionary(let d):
                    return .accessError(Auth.AccessErrorSerializer().deserialize(d["error"]!), getStringFromJson(json: d, key: "user_message"), getStringFromJson(json: d, key: "error_summary"),requestId)
                default:
                    fatalError("Failed to parse error type")
                }
            case 409:
                let json = SerializeUtil.parseJSON(data!)
                switch json {
                case .dictionary(let d):
                    return .routeError(Box(self.errorSerializer.deserialize(d["error"]!)), getStringFromJson(json: d, key: "user_message"), getStringFromJson(json: d, key: "error_summary"), requestId)
                default:
                    fatalError("Failed to parse error type")
                }
            case 429:
                let json = SerializeUtil.parseJSON(data!)
                switch json {
                case .dictionary(let d):
                    return .rateLimitError(Auth.RateLimitErrorSerializer().deserialize(d["error"]!), getStringFromJson(json: d, key: "user_message"), getStringFromJson(json: d, key: "error_summary"), requestId)
                default:
                    fatalError("Failed to parse error type")
                }
            case 200:
                return .clientError(error)
            default:
                return .httpError(code, "An error occurred.", requestId)
            }
        } else if response == nil {
            return .clientError(error)
        } else {
            var message = ""
            if let d = data {
                message = utf8Decode(d)
            }
            return .httpError(nil, message, requestId)
        }
    }
    
    func getStringFromJson(json: [String : JSON], key: String) -> String {
        if let jsonStr = json[key] {
            switch jsonStr {
            case .str(let str):
                return str;
            default:
                break;
            }
        }

        return "";
    }
}

/// An "rpc-style" request
open class RpcRequest<RSerial: JSONSerializer, ESerial: JSONSerializer>: Request<RSerial, ESerial> {
    public let request: Alamofire.DataRequest

    public init(request: Alamofire.DataRequest, responseSerializer: RSerial, errorSerializer: ESerial) {
        self.request = request
        super.init(responseSerializer: responseSerializer, errorSerializer: errorSerializer)
    }

    open func cancel() {
        self.request.cancel()
    }

    @discardableResult open func response(queue: DispatchQueue? = nil, completionHandler: @escaping (RSerial.ValueType?, CallError<ESerial.ValueType>?) -> Void) -> Self {
        self.request.validate().response(queue: queue) { response in
            if let error = response.error {
                completionHandler(nil, self.handleResponseError(response.response, data: response.data!, error: error))
            } else {
                completionHandler(self.responseSerializer.deserialize(SerializeUtil.parseJSON(response.data!)), nil)
            }
        }
        return self
    }
}

/// An "upload-style" request
open class UploadRequest<RSerial: JSONSerializer, ESerial: JSONSerializer>: Request<RSerial, ESerial> {
    public let request: Alamofire.UploadRequest

    public init(request: Alamofire.UploadRequest, responseSerializer: RSerial, errorSerializer: ESerial) {
        self.request = request
        super.init(responseSerializer: responseSerializer, errorSerializer: errorSerializer)
    }

    @discardableResult open func progress(_ progressHandler: @escaping ((Progress) -> Void)) -> Self {
        self.request.uploadProgress { progressData in
            progressHandler(progressData)
        }
        return self
    }

    open func cancel() {
        self.request.cancel()
    }

    @discardableResult open func response(queue: DispatchQueue? = nil, completionHandler: @escaping (RSerial.ValueType?, CallError<ESerial.ValueType>?) -> Void) -> Self {
        self.request.validate().response(queue: queue) { response in
            if let error = response.error {
                completionHandler(nil, self.handleResponseError(response.response, data: response.data!, error: error))
            } else {
                completionHandler(self.responseSerializer.deserialize(SerializeUtil.parseJSON(response.data!)), nil)
            }
        }
        return self
    }
}


/// A "download-style" request to a file
open class DownloadRequestFile<RSerial: JSONSerializer, ESerial: JSONSerializer>: Request<RSerial, ESerial> {
    public let request: Alamofire.DownloadRequest
    open var urlPath: URL?
    open var errorMessage: Data

    public init(request: Alamofire.DownloadRequest, responseSerializer: RSerial, errorSerializer: ESerial) {
        self.request = request
        urlPath = nil
        errorMessage = Data()
        super.init(responseSerializer: responseSerializer, errorSerializer: errorSerializer)
    }

    @discardableResult open func progress(_ progressHandler: @escaping ((Progress) -> Void)) -> Self {
        self.request.downloadProgress { progressData in
            progressHandler(progressData)
        }
        return self
    }

    open func cancel() {
        self.request.cancel()
    }

    @discardableResult open func response(queue: DispatchQueue? = nil, completionHandler: @escaping ((RSerial.ValueType, URL)?, CallError<ESerial.ValueType>?) -> Void) -> Self {
        self.request.validate().response(queue: queue) { response in
            if let error = response.error {
                completionHandler(nil, self.handleResponseError(response.response, data: self.errorMessage, error: error))
            } else {
                let headerFields: [AnyHashable : Any] = response.response!.allHeaderFields
                let result = caseInsensitiveLookup("Dropbox-Api-Result", dictionary: headerFields)!
                let resultData = result.data(using: .utf8, allowLossyConversion: false)
                let resultObject = self.responseSerializer.deserialize(SerializeUtil.parseJSON(resultData!))

                completionHandler((resultObject, self.urlPath!), nil)
            }
        }
        return self
    }
}

/// A "download-style" request to memory
open class DownloadRequestMemory<RSerial: JSONSerializer, ESerial: JSONSerializer>: Request<RSerial, ESerial> {
    public let request: Alamofire.DataRequest

    public init(request: Alamofire.DataRequest, responseSerializer: RSerial, errorSerializer: ESerial) {
        self.request = request
        super.init(responseSerializer: responseSerializer, errorSerializer: errorSerializer)
    }

    @discardableResult open func progress(_ progressHandler: @escaping ((Progress) -> Void)) -> Self {
        self.request.downloadProgress { progressData in
            progressHandler(progressData)
        }
        return self
    }

    open func cancel() {
        self.request.cancel()
    }

    @discardableResult open func response(queue: DispatchQueue? = nil, completionHandler: @escaping ((RSerial.ValueType, Data)?, CallError<ESerial.ValueType>?) -> Void) -> Self {
        self.request.validate().response(queue: queue) { response in
            if let error = response.error {
                completionHandler(nil, self.handleResponseError(response.response, data: response.data, error: error))
            } else {
                let headerFields: [AnyHashable : Any] = response.response!.allHeaderFields
                let result = caseInsensitiveLookup("Dropbox-Api-Result", dictionary: headerFields)!
                let resultData = result.data(using: .utf8, allowLossyConversion: false)
                let resultObject = self.responseSerializer.deserialize(SerializeUtil.parseJSON(resultData!))

                completionHandler((resultObject, response.data!), nil)
            }
        }
        return self
    }
}

func caseInsensitiveLookup(_ lookupKey: String, dictionary: [AnyHashable : Any]) -> String? {
    for key in dictionary.keys {
        let keyString = key as! String
        if (keyString.lowercased() == lookupKey.lowercased()) {
            return dictionary[key] as? String
        }
    }
    return nil
}
