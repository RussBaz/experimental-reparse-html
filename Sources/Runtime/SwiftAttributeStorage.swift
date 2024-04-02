public final class SwiftAttributeStorage {
    public enum AttributeValue {
        case flag
        case string(String, wrapper: AttributeValueWrapper)
    }

    public enum AttributeValueWrapper {
        case single, double, none
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

    public func append(key: String, value: String, wrapper: AttributeValueWrapper) {
        if wrapper != .none {
            attributes[key] = .string(value, wrapper: wrapper)
        } else {
            if value.isEmpty {
                attributes[key] = .flag
            } else {
                attributes[key] = .string(value, wrapper: wrapper)
            }
        }
    }

    public func append(to key: String, value: AttributeValue) {
        if let oldValue = attributes[key] {
            switch (oldValue, value) {
            case (.flag, .flag):
                attributes[key] = .flag
            case let (.flag, .string(v2, wrapper: wrapper2)):
                attributes[key] = .string(v2, wrapper: wrapper2)
            case let (.string(v1, wrapper: wrapper1), .flag):
                attributes[key] = .string(v1, wrapper: wrapper1)
            case let (.string(v1, wrapper1), .string(v2, _)):
                attributes[key] = .string(v1 + wrapper1.escapeQuotations(in: v2), wrapper: wrapper1)
            }
        } else {
            attributes[key] = value
        }
    }

    public func replace(key: String, with value: AttributeValue) {
        attributes[key] = value
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
        for (key, value) in attributes.sortedAttributes() {
            switch value {
            case .flag:
                lines.append("\"\(key)\": .flag")
            case let .string(v, wrapper):
                switch wrapper {
                case .single:
                    lines.append("\"\(key)\": .string(\"\"\"\n\(v)\n\"\"\", wrapper: .single)")
                case .double:
                    lines.append("\"\(key)\": .string(\"\(v)\", wrapper: .double)")
                case .none:
                    lines.append("\"\(key)\": .string(\"\(v)\", wrapper: .none)")
                }
            }
        }

        if lines.isEmpty {
            return ":"
        } else {
            return lines.joined(separator: ", ")
        }
    }
}

extension SwiftAttributeStorage: CustomStringConvertible {
    public var description: String {
        var result = ""
        for (key, attribute) in attributes.sortedAttributes() {
            switch attribute {
            case .flag:
                result += " \(key)"
            case let .string(value, wrapper):
                if wrapper == .single {
                    result += " \(key)='\(value)'"
                } else {
                    result += " \(key)=\"\(value)\""
                }
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
        case let .string(string, _):
            string
        }
    }

    var codeString: String {
        switch self {
        case .flag:
            ".flag"
        case let .string(string, wrapper):
            switch wrapper {
            case .single:
                ".string(\"\"\"\n\(string)\n\"\"\", wrapper: .single)"
            case .double:
                ".string(\"\(string)\", wrapper: .double)"
            case .none:
                ".string(\"\(string)\", wrapper: .none)"
            }
        }
    }
}

extension SwiftAttributeStorage.AttributeValue: Equatable {}
extension SwiftAttributeStorage: Equatable {
    public static func == (lhs: SwiftAttributeStorage, rhs: SwiftAttributeStorage) -> Bool {
        lhs.attributes == rhs.attributes
    }
}

extension SwiftAttributeStorage.AttributeValueWrapper {
    func isWrapped() -> Bool {
        if case .none = self {
            false
        } else {
            true
        }
    }

    func escapeQuotations(in value: String) -> String {
        switch self {
        case .single:
            value.replacing("'", with: "&#39")
        case .double:
            value.replacing("\"", with: "&quot")
        case .none:
            value
        }
    }
}

extension SwiftAttributeStorage {
    static func from(attributes: [String: (String, AttributeValueWrapper)]) -> SwiftAttributeStorage {
        let storage = SwiftAttributeStorage()
        for (key, (value, wrapper)) in attributes {
            if value.isEmpty {
                if wrapper.isWrapped() {
                    storage[key] = .string("", wrapper: wrapper)
                } else {
                    storage[key] = .flag
                }

            } else {
                storage[key] = .string(value, wrapper: wrapper)
            }
        }

        return storage
    }
}

public extension [String: SwiftAttributeStorage.AttributeValue] {
    func sortedAttributes() -> [(key: String, value: SwiftAttributeStorage.AttributeValue)] {
        var withValues: [(key: String, value: SwiftAttributeStorage.AttributeValue)] = []
        var withFlags: [(key: String, value: SwiftAttributeStorage.AttributeValue)] = []

        for (key, value) in self {
            switch value {
            case .flag:
                withFlags.append((key: key, value: value))
            case let .string(v, _):
                if v.isEmpty {
                    withFlags.append((key: key, value: .flag))
                } else {
                    withValues.append((key: key, value: value))
                }
            }
        }

        return withValues.sorted(by: { $0.key < $1.key }) + withFlags.sorted(by: { $0.key < $1.key })
    }
}
