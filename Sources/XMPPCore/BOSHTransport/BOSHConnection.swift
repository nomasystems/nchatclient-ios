// Copyright © 2020 Nomasystems S.L. All rights reserved.

import Foundation

enum BOSHTaskResult {
    case error(error: NSError)
    case response(data: Data?)
    case cancelled
}

typealias BOSHTaskCompletionHandler = (_ result: BOSHTaskResult) -> Void

protocol BOSHTask {
    func resume()
    func suspend()
    func cancel()
}

protocol BOSHConnection: AnyObject {
    var url: URL? { get set }
    func reset()
    func shutdown()
    func setConfiguration(_ connections: Int, requestTimeout: TimeInterval, wait: TimeInterval)
    func createTask(_ data: Data, completionHandler: @escaping BOSHTaskCompletionHandler) -> BOSHTask
}
