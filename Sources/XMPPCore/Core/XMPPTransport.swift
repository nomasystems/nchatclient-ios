// Copyright © 2020 Nomasystems S.L. All rights reserved.

import Foundation

protocol XMPPTransportDelegate: AnyObject {
    func on(transport: XMPPTransport, error: XMPPTransportError)
    func on(transport: XMPPTransport, failure: XMPPTransportError)
    func on(transport: XMPPTransport, element: XMLParserEl)
    func on(transport: XMPPTransport, state: XMPPTransportState)
}

// Transport API
protocol XMPPTransport {
    // Called when the transport has something useful to report
    var delegate: XMPPTransportDelegate? { get set }

    // Connect to the server
    func connect(jid: XMPPJid, url: URL)

    // Disconnect from the server
    func disconnect()

    // Restart the current stream
    func restart()

    // Add a element to the send queue
    func send(element: XMLParserEl)

    // Flush the send queue
    func flush()

    // Flush the send queue and wait for completion
    func complete(completion: @escaping () -> Void)

    // Called to process events (should be called regularly to reduce latency)
    func processEvents()
}
