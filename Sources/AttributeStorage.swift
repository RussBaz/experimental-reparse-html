import SwiftSoup

final class AttributeStorage {
    enum AttributeValue {
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
}

extension AttributeStorage: CustomStringConvertible {
    var description: String {
        "[\(attributes.map { "\($0)" }.joined(separator: ", "))]"
    }
}
