import SwiftSoup

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

    func has(_ name: String) -> Bool {
        attributes[name] != nil
    }

    func find(_ name: String) -> String? {
        attributes[name]?.text
    }

    func value(of name: String) -> AttributeValue? {
        attributes[name]
    }

    func remove(_ name: String) -> AttributeValue? {
        attributes.removeValue(forKey: name)
    }

    static func from(element: Node) -> AttributeStorage {
        let storage = AttributeStorage()
        guard let attributes = element.getAttributes() else { return storage }

        for a in attributes {
            if a.isBooleanAttribute() {
                storage.attributes[a.getKey()] = .flag
            } else {
                storage.attributes[a.getKey()] = .string(a.getValue())
            }
        }

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
}
