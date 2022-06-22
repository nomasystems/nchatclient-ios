// Copyright © 2022 Nomasystems S.L. All rights reserved.

import Foundation
import XCTest
@testable import XMPPCore

class ParseStreamMechanismTest: XCTestCase {
    func testDecode() throws {
        guard let mechanismData = try? ReadFile.data(fileName: "Mechanisms") else {
            XCTFail("Invalid file")
            return
        }

        XCTAssertNotNil(mechanismData)
        XMLDecoder(data: mechanismData) { result in
            switch result {
            case .body(let xmppBody):
                XCTAssertNotNil(xmppBody)
            case .error(_):
                XCTFail("Parse Error")
            }
        }
    }
}
