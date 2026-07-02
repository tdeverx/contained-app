import Foundation

/// Lossless JSON tree used by backup files and schema transforms. Objects keep their decoded member
/// order so unknown keys can survive downgrade -> upgrade round trips.
enum JSONValue: Codable, Equatable, Sendable {
    struct Member: Codable, Equatable, Sendable {
        var key: String
        var value: JSONValue
    }

    case object([Member])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        if var array = try? decoder.unkeyedContainer() {
            var values: [JSONValue] = []
            while !array.isAtEnd {
                values.append(try array.decode(JSONValue.self))
            }
            self = .array(values)
            return
        }

        if let object = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            let members = try object.allKeys.map { key in
                Member(key: key.stringValue, value: try object.decode(JSONValue.self, forKey: key))
            }
            self = .object(members)
            return
        }

        let single = try decoder.singleValueContainer()
        if single.decodeNil() {
            self = .null
        } else if let value = try? single.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? single.decode(Double.self) {
            self = .number(value)
        } else {
            self = .string(try single.decode(String.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .object(let members):
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            for member in members {
                try container.encode(member.value, forKey: DynamicCodingKey(member.key))
            }
        case .array(let values):
            var container = encoder.unkeyedContainer()
            for value in values { try container.encode(value) }
        case .string(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .number(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .bool(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
}

struct DynamicCodingKey: CodingKey, Hashable {
    var stringValue: String
    var intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(stringValue: String) { self.init(stringValue) }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

extension JSONValue {
    var objectMembers: [Member] {
        guard case .object(let members) = self else { return [] }
        return members
    }

    subscript(key: String) -> JSONValue? {
        guard case .object(let members) = self else { return nil }
        return members.first { $0.key == key }?.value
    }

}
