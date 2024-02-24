public final class AttributeStorage {
    public enum AttributeValue {
        case flag
        case string(String)
    }

    var attributes: [String: AttributeValue] = [:]

    func copy() -> AttributeStorage {
        let storage = AttributeStorage()
        for (key, value) in attributes {
            storage.attributes[key] = value
        }
        return storage
    }

    func append(key: String, value: String, wrapped: Bool) {
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

    func update(key: String, with value: AttributeValue, replacing: Bool) {
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

    func has(_ name: String) -> Bool {
        attributes[name] != nil
    }

    func find(_ name: String) -> String? {
        attributes[name]?.text
    }

    func value(of name: String) -> AttributeValue? {
        attributes[name]
    }

    @discardableResult
    func remove(_ name: String) -> AttributeValue? {
        attributes.removeValue(forKey: name)
    }

    static func from(attributes: [String: AttributeValue]) -> AttributeStorage {
        let storage = AttributeStorage()
        storage.attributes = attributes

        return storage
    }

    static func from(attributes: [String: (String, SimpleHtmlParser.AttributeValueWrapper)]) -> AttributeStorage {
        let storage = AttributeStorage()
        for (key, (value, wrapper)) in attributes {
            if value.isEmpty {
                if wrapper.isWrapped() {
                    storage.attributes[key] = .string("")
                } else {
                    storage.attributes[key] = .flag
                }

            } else {
                storage.attributes[key] = .string(value)
            }
        }

        return storage
    }

    func codeString(at _: Int) -> String {
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

extension AttributeStorage: CustomStringConvertible {
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

extension AttributeStorage.AttributeValue {
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

extension AttributeStorage.AttributeValue: Equatable {}
extension AttributeStorage: Equatable {
    public static func == (lhs: AttributeStorage, rhs: AttributeStorage) -> Bool {
        lhs.attributes == rhs.attributes
    }
}
