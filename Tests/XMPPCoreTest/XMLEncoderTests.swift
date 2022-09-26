// Copyright © 2022 Nomasystems S.L. All rights reserved.

import XCTest
@testable import XMPPCore

class XMLEncoderTests: XCTestCase {

    static let keyString = "key"
    let bodyFormat = "<body xmlns=\'http://jabber.org/protocol/httpbind\' \(keyString)=\'%@'></body>"

    func testSingleQuoteEncoding() throws {
        let encoder = XMLEncoder()
        let body = XMPPBody(properties: [Self.keyString : "Hello 'world'"])
        let data = encoder.encode(body)
        let result = String(decoding: data!, as: UTF8.self)
        let expectedResult = String(format: bodyFormat, "Hello &apos;world&apos;")
        XCTAssertEqual(result, expectedResult)
    }

    func testDoubleQuoteEncoding() throws {
        let encoder = XMLEncoder()
        let body = XMPPBody(properties: [Self.keyString: "Hello \"world\""])
        let data = encoder.encode(body)
        let result = String(decoding: data!, as: UTF8.self)
        let expectedResult = String(format: bodyFormat, "Hello &quot;world&quot;")
        XCTAssertEqual(result, expectedResult)
    }

}
