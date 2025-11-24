import Foundation

// MARK: Quick response buttons.

struct Button: Codable, Equatable {
    let type: String
    let text: String
    let value: String
    let timestamp = Date()

    private enum JsonKey: String, CodingKey {
        case type
        case label
        case value
    }

    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: JsonKey.self)
        type = try root.decode(String.self, forKey: .type)
        text = try root.decode(String.self, forKey: .label)
        value = try root.decode(String.self, forKey: .value)
    }
}

struct Rbody: Codable {
    let type: String
    let fields: [Field]
}

struct Field: Codable {
    let type: String
    let `var`: String
    let options: [Button]
    let label: String?
    let value: String?
}
