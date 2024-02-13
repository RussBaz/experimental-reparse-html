import SwiftSoup

public final class AttributeStorage {
    public enum AttributeValue {
        case flag
        case string(String)
        case data(String)
    }

    var attributes: [String: AttributeValue] = [:]

    static func from(element: Node) -> AttributeStorage {
        let storage = AttributeStorage()
        guard let attributes = element.getAttributes() else { return storage }

        for a in attributes {
            if a.isBooleanAttribute() {
                storage.attributes[a.getKey()] = .flag
            } else if a.isDataAttribute() {
                storage.attributes[a.getKey()] = .data(a.getValue())
            } else {
                storage.attributes[a.getKey()] = .string(a.getValue())
            }
        }

        return storage
    }
    
    static func from(attributes: [String: String]) -> AttributeStorage {
        let storage = AttributeStorage()
        for (key, value) in attributes {
            if value.isEmpty {
                storage.attributes[key] = .flag
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
            case .string(let value):
                result += " \(key)=\"\(value)\""
            case .data(let value):
                result += " \(key)=\"\(value)\""
            }
        }
        return result
    }
}
