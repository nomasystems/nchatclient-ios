// Copyright © 2020 Nomasystems S.L. All rights reserved.

import Foundation
import os

public func XMPPLog(_ category: String, _ message: String) {
    let log = OSLog(subsystem: "com.nomasystems.nmaxmpp", category: category)
    let type: OSLogType = category == "ERROR" ? .error : .debug
    os_log("%@", log: log, type: type, message)
}
