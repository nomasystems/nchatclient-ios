// Copyright © 2022 Nomasystems S.L. All rights reserved.

import Foundation

public enum XMLParserEl {
    case node(name: String, namespace: XMPPNamespace? = nil,
              attributes: [String: String] = [:], children: [XMLParserEl] = [])
    case text(String)
}

public extension XMLParserEl {
    func forEachElement(completion: (XMLParserEl) throws -> Void) rethrows {
        guard case let .node(_, _, _, children) = self else { return }
        try children.forEach { try completion($0) }
    }

    func getText() -> String {
        let text: String
        switch self {
        case .text(let baseText):
            text = baseText
        case .node(_, _, _, let children):
            text = children.map { $0.getText() }.joined()
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
