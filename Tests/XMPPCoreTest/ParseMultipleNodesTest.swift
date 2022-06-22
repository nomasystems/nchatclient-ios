// Copyright © 2022 Nomasystems S.L. All rights reserved.

import Foundation
import XCTest
@testable import XMPPCore

class ParseMultipleNodesTest: XCTestCase {
    func testDecode() throws {
        guard let mechanismData = try? ReadFile.data(fileName: "PresenceAndHistory") else {
            XCTFail("Invalid file")
            return
        }

        XCTAssertNotNil(mechanismData)
        XMLDecoder(data: mechanismData) { result in
            switch result {
            case .body(let xmppBody):
                XCTAssertEqual(xmppBody.elements.count, 2)
            case .error(_):
                XCTFail("Parse Error")
            }
        }
    }
}
