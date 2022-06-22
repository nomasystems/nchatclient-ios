// Copyright © 2020 Nomasystems S.L. All rights reserved.

import Foundation

class BOSHSessionConnection: BOSHConnection {
    private var session: URLSession

    private var config: URLSessionConfiguration

    var url: URL?
    private var userAgent = "XMPPCore BOSH 1.0"
    private var contentType = "text/xml; charset=utf-8"

    init() {
        self.session = URLSession.shared
        self.config = URLSessionConfiguration.default
    }

    func setConfiguration(_ connections: Int, requestTimeout: TimeInterval, wait: TimeInterval) {
        config = URLSessionConfiguration.default
        config.httpShouldUsePipelining = false
        config.httpMaximumConnectionsPerHost = connections
        config.timeoutIntervalForResource = wait
        config.timeoutIntervalForRequest = requestTimeout

        session.invalidateAndCancel()
        session = URLSession(configuration: config)
    }

    func shutdown() {
        session.invalidateAndCancel()
    }

    func reset() {
        shutdown()
        self.session = URLSession.shared
        self.config = URLSessionConfiguration.default
    }

    func createTask(_ data: Data, completionHandler: @escaping BOSHTaskCompletionHandler) -> BOSHTask {
        guard let url = url else {
            preconditionFailure("Url must be set")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpShouldHandleCookies = false
        req.httpShouldUsePipelining = false
        req.httpBody = data
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")

        #if XMPP_CONNECTION_DEBUG
        XMPPLog("SEND", "\(String(data: data, encoding: String.Encoding.utf8)!)")
        #endif

        let task = session.dataTask(with: req, completionHandler: {data, response, error in
            if error != nil {
                if let nserror = error as NSError? {
                    if nserror.code == -999 {
                        XMPPLog("ERROR", "CANCELLED")
                        completionHandler(.cancelled)
                    } else {
                        XMPPLog("ERROR", "\(nserror.localizedDescription)")
                        completionHandler(.error(error: nserror))
                    }
                } else {
                    XMPPLog("ERROR", "\(error!.localizedDescription)")
                    completionHandler(.error(error: NSError(domain: "XMPP", code: 0)))
                }
            } else {
                let httpResponse = response as! HTTPURLResponse
                if data != nil {
                    #if XMPP_CONNECTION_DEBUG
                    XMPPLog("RECV", "(\(httpResponse.statusCode)) \(String(data: data!, encoding: String.Encoding.utf8)!)")
                    #endif
                    completionHandler(.response(data: data))
                } else {
                    #if XMPP_CONNECTION_DEBUG
                    XMPPLog("RECV", "(\(httpResponse.statusCode))")
                    #endif
                    completionHandler(.response(data: nil))
                }
            }
        })

        return BOSHSessionTask(task: task)
    }

}

class BOSHSessionTask: BOSHTask {
    private let task: URLSessionTask

    init(task: URLSessionTask) {
        self.task = task
    }

    func resume() {
        task.resume()
    }

    func suspend() {
        task.suspend()
    }

    func cancel() {
        task.cancel()
    }

}
