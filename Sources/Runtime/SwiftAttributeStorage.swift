public final class SwiftAttributeStorage {
    public enum AttributeValue {
        case flag
        case string(String)
    }

    var attributes: [String: AttributeValue] = [:]

    public init() {}

    public func copy() -> SwiftAttributeStorage {
        let storage = SwiftAttributeStorage()
        for (key, value) in attributes {
            storage.attributes[key] = value
        }
        return storage
    }

    public func append(key: String, value: String, wrapped: Bool) {
        if wrapped {
            attributes[key] = .string(value)
        } else {
            if value.isEmpty {
                attributes[key] = .flag
            } else {
                attributes[key] = .string(value)
            }
        }
    }

    public func update(key: String, with value: AttributeValue, replacing: Bool) {
        if replacing {
            attributes[key] = value
        } else {
            if let oldValue = attributes[key] {
                switch (oldValue, value) {
                case (.flag, .flag):
                    attributes[key] = .flag
                case let (.flag, .string(v2)):
                    attributes[key] = .string(v2)
                case let (.string(v1), .flag):
                    attributes[key] = .string(v1)
                case let (.string(v1), .string(v2)):
                    attributes[key] = .string(v1 + v2)
                }
            } else {
                attributes[key] = value
            }
        }
    }

    public func has(_ name: String) -> Bool {
        attributes[name] != nil
    }

    public func find(_ name: String) -> String? {
        attributes[name]?.text
    }

    public subscript(name: String) -> AttributeValue? {
        get {
            attributes[name]
        }
        set {
            if let newValue {
                attributes[name] = newValue
            } else {
                attributes.removeValue(forKey: name)
            }
        }
    }

    @discardableResult
    public func remove(_ name: String) -> AttributeValue? {
        attributes.removeValue(forKey: name)
    }

    public static func from(attributes: [String: AttributeValue]) -> SwiftAttributeStorage {
        let storage = SwiftAttributeStorage()
        storage.attributes = attributes

        return storage
    }

    public var codeString: String {
        var lines: [String] = []
        for (key, value) in attributes {
            switch value {
            case .flag:
                lines.append("\"\(key)\": .flag")
            case let .string(v):
                lines.append("\"\(key)\": .string(\"\(v)\")")
            }
        }
        return lines.joined(separator: ", ")
    }
}

extension SwiftAttributeStorage: CustomStringConvertible {
    public var description: String {
        var result = ""
        for (key, attribute) in attributes {
            switch attribute {
            case .flag:
                result += " \(key)"
            case let .string(value):
                result += " \(key)=\"\(value)\""
            }
        }
        return result
    }
}

public extension SwiftAttributeStorage.AttributeValue {
    var text: String {
        switch self {
        case .flag:
            // Not a standard interpretation of an empty string
            "true"
        case let .string(string):
            string
        }
    }

    var codeString: String {
        switch self {
        case .flag:
            ".flag"
        case let .string(string):
            ".string(\"\(string)\")"
        }
    }
}

extension SwiftAttributeStorage.AttributeValue: Equatable {}
extension SwiftAttributeStorage: Equatable {
    public static func == (lhs: SwiftAttributeStorage, rhs: SwiftAttributeStorage) -> Bool {
        lhs.attributes == rhs.attributes
    }
}
