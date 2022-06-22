// Copyright © 2022 Nomasystems S.L. All rights reserved.

import Foundation

class ReadFile {
    enum FileError: Error {
        case fileNotFound
    }

    static func data(fileName: String, ext: String = "xml") throws -> Data {
        guard let path = Bundle(for: ReadFile.self).path(forResource: fileName, ofType: ext) else {
            return try no_resource_workaround(filename: fileName)
        }

        return try Data(contentsOf: URL(fileURLWithPath: path))
    }
}

private extension ReadFile {
    static func no_resource_workaround(filename: String) throws -> Data {
        var content = ""
        switch filename {
        case "Mechanisms":
            content = """
                <body xmlns='http://jabber.org/protocol/httpbind'
                      authid='272C25CD'
                      xmlns:xmpp='urn:xmpp:xbosh'
                      xmlns:stream='http://etherx.jabber.org/streams'
                      xmpp:version='1.0'
                      sid='e54bc0277a2f0f29b99c2ea4de28def1f65c8a68'
                      wait='20'
                      requests='2'
                      inactivity='30'
                      maxpause='120'
                      polling='20'
                      ver='1.6'
                      from='chat-core.com'
                      secure='true'>
                    <stream:features xmlns:stream='http://etherx.jabber.org/streams'>
                        <mechanisms xmlns='urn:ietf:params:xml:ns:xmpp-sasl'>
                            <mechanism>PLAIN</mechanism>
                        </mechanisms>
                    </stream:features>
                </body>
                """
        case "PresenceAndHistory":
            content = """
                <body xmlns='http://jabber.org/protocol/httpbind'>
                    <presence from='100001648467788039353@chat-core.com/100056000000001'
                        to='100056000000001@chat-core.com/ios'>
                            <x xmlns='http://jabber.org/protocol/muc#user'>
                                <item affiliation='member'/>
                                <status code='110'/>
                            </x>
                    </presence>
                    <iq from='100056000000001@chat-core.com/ios'
                        to='100056000000001@chat-core.com/ios'
                        id='room-messages-history'
                        type='result'>
                        <query xmlns='http://jabber.org/protocol/messages'>
                            <item>
                                <from>0@chat-core.com</from>
                                <body>El cliente ha abandonado la conversación.</body>
                                <metadata></metadata>
                                <attachment></attachment>
                                <attention>false</attention>
                                <isRead>true</isRead>
                                <time>2022-03-28T11:43:19.166Z</time>
                            </item>
                        </query>
                    </iq>
                </body>
            """
        default:
            throw FileError.fileNotFound
        }

        return content.data(using: .utf8)!
    }
}
