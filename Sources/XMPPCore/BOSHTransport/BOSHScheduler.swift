// Copyright © 2020 Nomasystems S.L. All rights reserved.

import Foundation

class BOSHScheduler {
    private let queue = DispatchQueue.global(qos: DispatchQoS.QoSClass.userInteractive)

    // Invariants: fifo, sorted by rid
    private var canceled = [BOSHRequest]()
    private var ready    = [BOSHRequest]()
    private var running  = [BOSHRequest]()
    private var completionHandler: (() -> Void)?

    var pipes = 1
    var maxTimeout = TimeInterval(10)

    func shouldPoll(_ wait: TimeInterval) -> Bool {
        return (ready.isEmpty && running.isEmpty) || (running.count < pipes && !running.isEmpty && running.first!.rage() > wait)
    }

    func add(_ request: BOSHRequest) {
        queue.sync {
            self.ready.append(request)
            self.ready.sort(by: { $0.rid < $1.rid })
        }
    }

    func clear() {
        queue.sync {
            let tmp = self.running
            self.ready = []
            self.running = []

            self.canceled.append(contentsOf: tmp)
            tmp.forEach {
                $0.cancel()
            }
        }
    }

    func complete(completion: @escaping () -> Void) {
        completionHandler = completion
        run()
    }

    // This function should be call semifrequently to reduce latency
    func run() {
        queue.sync {
            if !self.canceled.isEmpty {
                self.canceled = self.canceled.filter { (r: BOSHRequest) in
                    return r.state == .running
                }
            }

            let failed = self.running.filter { (r: BOSHRequest) in
                return r.state == .failed
            }

            self.running = self.running.filter { r in
                return r.state == .running
            }

            if !failed.isEmpty {
                self.ready.append(contentsOf: failed)
                self.ready.sort(by: { $0.rid < $1.rid })
            }

            while self.running.count < self.pipes {
                if let r = self.ready.first {
                    if r.state == .cancelled {
                        self.ready.removeFirst()
                    } else if r.state == .suspended {
                        self.running.append(self.ready.removeFirst())
                        r.send()
                    } else if r.state == .failed && r.retries < r.maxRetries && isTimedout(r) {
                        self.running.append(self.ready.removeFirst())
                        r.resend()
                    } else {
                        break
                    }
                } else {
                    break
                }
            }

            if completionHandler != nil, canceled.isEmpty, ready.isEmpty, running.isEmpty {
                DispatchQueue.main.async {
                    self.completionHandler?()
                    self.completionHandler = nil
                }
            }
        }
    }

    func isTimedout(_ r: BOSHRequest) -> Bool {
        return r.rage() > min(TimeInterval(pow(Double(r.retries), 3.0)), maxTimeout)
    }
}
