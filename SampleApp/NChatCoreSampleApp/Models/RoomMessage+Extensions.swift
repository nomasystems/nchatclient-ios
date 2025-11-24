import Foundation
import NChatCore

extension Room.Message {
    func same(as message: Room.Message) -> Bool {
        let marginOfSeconds = 3

        return sameContent(as: message) &&
        from == message.from &&
        timestamp < message.timestamp.adding(seconds: marginOfSeconds) &&
        timestamp > message.timestamp.adding(seconds: -marginOfSeconds)
    }

    func sameContent(as message: Room.Message) -> Bool {
        switch (containsAttachment, message.containsAttachment) {
        case (true, true):
            // When comparing two messages with attachments, text is not reliable since raw attachment data
            // coming from history retrieval in injected into the message text with attachment data.
            // In such a case, we extract url data from both messages and compare them.
            let attachment1: ChatAttachment? = {
                attachment ??
                ChatAttachmentsManager.shared.getAttachment(rawAttachment, body: text)?.attachment
            }()
            let attachment2: ChatAttachment? = {
                message.attachment ??
                ChatAttachmentsManager.shared.getAttachment(message.rawAttachment, body: message.text)?.attachment
            }()
            return attachment1?.url == attachment2?.url
        case (true, false),
             (false, true),
             (false, false):
            return message.text == text
        }
    }

    var buttons: [Button] {
        guard let text = metadata,
              let jsonData = text.data(using: .utf8),
              let formBody: Rbody = try? JSONDecoder().decode(Rbody.self, from: jsonData),
              let buttons = formBody.fields.first?.options
        else { return [] }
        return buttons
    }

    var buttonText: String? {
        guard let text = metadata,
              let jsonData = text.data(using: .utf8),
              let formBody: Rbody = try? JSONDecoder().decode(Rbody.self, from: jsonData),
              let label = formBody.fields.first?.label
        else { return nil }
        return label
    }

    var isDelivered: Bool {
        [.delivered, .sent].contains(state) || from != .user
    }

    var containsAttachment: Bool {
        attachment != nil || rawAttachment != nil
    }
}
