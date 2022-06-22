// Copyright © 2022 Nomasystems S.L. All rights reserved.

import Foundation

enum ParseResult {
    case body(XMPPBody)
    case error(Error)
}

enum XMLDecoderError: Error {
    case invalidTree(on: XMLParserEl)
    case invalidTagEnd(tagName: String)
}

class XMLDecoder: NSObject {
    private var completion: ((ParseResult) -> Void)?
    private var elements: [XMLParserEl] = []
    private var properties: [String: String] = [:]
    private var root = true
    private var stack: [XMLParserEl] = []

    required init(completion: ((ParseResult) -> Void)? = nil) {
        self.completion = completion

        super.init()
    }

    @discardableResult
    convenience init(data: Data, completion: ((ParseResult) -> Void)? = nil) {
        self.init(completion: completion)
        parse(data: data)
    }

    func parse(data: Data) {
        //XMPPLog("Verbose XMPP", "Decode \n \(String(data: data, encoding: .utf8) ?? "")")
        root = true
        let xmlParser = XMLParser(data: data)
        xmlParser.shouldProcessNamespaces = true
        xmlParser.delegate = self
        xmlParser.parse()
    }
}

extension XMLDecoder: XMLParserDelegate {
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        var xmlns = XMPPNamespace(rawValue: namespaceURI ?? "undefined")

        if root {
            guard elementName == "body" && xmlns == .BOSH else {
                parser.abortParsing()
                return
            }

            properties = attributeDict
            root = false
        } else {
            // See issue: 131
            if xmlns == .BOSH {
                xmlns = .CLIENT
            }

            stack.append(.node(name: elementName, namespace: xmlns, attributes: attributeDict))
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard !stack.isEmpty else { return }

        try? reduceIfNeeded(element: stack.removeLast(), to: elementName)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        stack.append(.text(string))
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        if let error = parser.parserError {
            completion?(.error(error))
        }

        completion?(.body(XMPPBody(properties: properties, elements: elements)))
    }
}

private extension XMLDecoder {
    func reduceIfNeeded(element: XMLParserEl, to name: String) throws {
        guard !stack.isEmpty else {
            elements.append(element)
            return
        }

        let previousElement = stack.removeLast()

        switch (element, previousElement) {
        case (let .text(value), let .text(previousValue)):
            try reduceIfNeeded(element: .text(previousValue + value), to: name)
        case (_, .node(name, _, _, _)):
            let newElement = try append(element: element, into: previousElement)
            try reduceIfNeeded(element: newElement, to: name)
        case (.node(name, _, _, _), .node(_, _, _, _)):
            let newElement = try append(element: element, into: previousElement)
            stack.append(newElement)
        case (_, _):
            throw XMLDecoderError.invalidTagEnd(tagName: name)
        }
    }

    func append(element: XMLParserEl, into previousElement: XMLParserEl) throws -> XMLParserEl {
        guard case let .node(name, namespace, attrs, children) = previousElement else {
            throw XMLDecoderError.invalidTree(on: previousElement)
        }

        var newChildren = children
        newChildren.append(element)
        return .node(name: name,
                     namespace: namespace,
                     attributes: attrs,
                     children: newChildren)
    }
}
