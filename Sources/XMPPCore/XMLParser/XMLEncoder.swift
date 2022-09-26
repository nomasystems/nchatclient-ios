// Copyright © 2022 Nomasystems S.L. All rights reserved.

import Foundation

class XMLEncoder {
    private var nsStack = [XMPPNamespace]()

    func encode(_ body: XMPPBody) -> Data? {
        nsStack = [XMPPNamespace.BOSH]
        var str = "<body xmlns='\(XMPPNamespace.BOSH.rawValue)'"
        for (key, value) in body.properties {
            str += " \(sanitize(key))='\(sanitize(value))'"
        }

        str += ">"
        for e in body.elements {
            str += loop(element: e)
        }
        str += "</body>"

        //XMPPLog("Verbose XMPP", "Encode \n \(str)")

        return str.data(using: String.Encoding.utf8)
    }

    private func loop(element: XMLParserEl) -> String {
        switch element {
        case .text(let text):
            return sanitize(text)
        case .node(let name, let namespace, let attributes, let children):
            var attrs = attributes
            if let namespace = namespace {
                if namespace != nsStack.last {
                    attrs["xmlns"] = namespace.rawValue
                }
                nsStack.append(namespace)
            }

            var attrstr = ""
            for (key, value) in attrs {
                attrstr += " \(sanitize(key))='\(sanitize(value))'"
            }

            var buffer = ""
            if children.isEmpty {
                buffer = "<\(sanitize(name))\(attrstr)/>"
            } else {
                buffer = "<\(sanitize(name))\(attrstr)>"
                for c in children {
                    buffer += loop(element: c)
                }
                buffer += "</\(sanitize(name))>"
            }

            if namespace != nil {
                nsStack.removeLast()
            }
            return buffer
        }
    }

    private func sanitize(_ str: String) -> String {
        return str.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
