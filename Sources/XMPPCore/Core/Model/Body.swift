// Copyright © 2022 Nomasystems S.L. All rights reserved.

import Foundation

struct XMPPBody {
    let elements: [XMLParserEl]
    let lang = "en"
    let properties: [String: String]

    init(properties: [String: String], elements: [XMLParserEl] = []) {
        self.properties = properties
        self.elements = elements
    }
}
