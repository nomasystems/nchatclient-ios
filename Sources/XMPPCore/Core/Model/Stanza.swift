// Copyright © 2022 Nomasystems S.L. All rights reserved.

public protocol XMPPStanza: Equatable {
    var id: String { get }
    var from: XMPPJid? { get }
    var to: XMPPJid? { get }
    var data: [XMLParserEl] { get }
}

extension XMPPStanza {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.from == rhs.from &&
        lhs.to == rhs.to &&
        lhs.id == rhs.id
    }
}
