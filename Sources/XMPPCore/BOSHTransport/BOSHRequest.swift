// Copyright © 2020 Nomasystems S.L. All rights reserved.

import Foundation

class BOSHRequest {

    enum Result {
        case error(error: XMPPTransportError)
        case result(body: XMPPBody)
        case empty
    }

    typealias CompletionHandler = (_ result: Result, _ request: BOSHRequest) -> Void

    let completionHandler: CompletionHandler
    let body: XMPPBody
    let rid: String
    let stamp = Date()
    var rstamp: Date?
    var retries = 0
    var maxRetries: Int
    var state = BOSHRequestState.suspended

    private let encoder: XMLEncoder
    private var parser: XMLDecoder!
    private var task: BOSHTask?
    private weak var connection: BOSHConnection?

    var isRecoverable: Bool {
        return retries < maxRetries
    }

    init(body: XMPPBody, connection: BOSHConnection, maxRetries: Int = 3, withCompletionHandler: @escaping CompletionHandler) {
        self.encoder = XMLEncoder()
        self.body = body
        self.connection = connection
        self.completionHandler = withCompletionHandler
        self.rid = body.properties["rid"] ?? ""
        self.maxRetries = maxRetries

        parser = XMLDecoder(completion: { [weak self] result in
            guard let self = self else { return }
            self.task = nil
            switch result {
            case .error:
                self.maxRetries = 0
                self.complete(.error(error: XMPPTransportError.parse))
            case .body(let body):
                self.complete(.result(body: body))
            }
        })
    }

    func age() -> TimeInterval {
        return Date().timeIntervalSince(stamp)
    }

    func rage() -> TimeInterval {
        guard let rstamp = rstamp else {
            return age()
        }
        return Date().timeIntervalSince(rstamp)
    }

    func send() {
        guard let connection = connection,
            let encodedBody = encoder.encode(body) else { return }
        state = .running
        let t = connection.createTask(encodedBody, completionHandler: {result in
            self.rstamp = Date()

            switch result {
            case .cancelled:
                self.task = nil
                self.state = .cancelled
            case .error(let error):
                self.task = nil
                self.state = .failed
                self.complete(.error(error: .connection(error)))
            case .response(let data):
                self.state = .completed
                if let data = data {
                    self.parser.parse(data: data)
                } else {
                    self.complete(.empty)
                }
            }
        })

        self.task = t
        t.resume()
    }

    func resend() {
        retries += 1
        send()
    }

    func fail() {
        state = .failed
    }

    func cancel() {
        task?.cancel()
    }

    private func complete(_ result: Result) {
        DispatchQueue.main.async {
            self.completionHandler(result, self)
        }
    }
}
