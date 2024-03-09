public final class PageProperties {
    enum LineType {
        case text(String)
        case deferred(() -> [String])
    }

    public enum ProtocolCompliance {
        case simple(name: String)
        case generic(name: String, associatedTypes: [(name: String, type: String)])
    }

    struct LineDef {
        let indentation: Int
        let line: LineType
    }

    let name: String
    let rootPath: String
    let fileExtension: String
    let enumName: String
    var lines: [LineDef] = []
    var conditionTags: [(name: String, read: Bool)] = []
    var defaultValues: [String: String] = [:]
    var mutableParameters: [String] = []
    var modifiersPresent = false
    var protocols: [ProtocolCompliance] = []

    init(name: String, rootPath: String, fileExtension: String, enumName: String, protocols: [ProtocolCompliance]) {
        self.name = name
        self.fileExtension = fileExtension
        self.enumName = enumName
        self.protocols = protocols
        self.rootPath = rootPath
    }

    func clear() {
        lines = []
        conditionTags = []
        defaultValues = [:]
    }

    func append(at indentation: Int) {
        lines.append(.init(indentation: indentation, line: .text("")))
    }

    func prepend(at indentation: Int) {
        lines.insert(.init(indentation: indentation, line: .text("")), at: 0)
    }

    func append(_ text: String, at indentation: Int) {
        lines.append(.init(indentation: indentation, line: .text(text)))
    }

    /// Use this function when the conditions are not yet known and knowing them will require a global resolution first
    func append(at indentation: Int, deferred: @escaping () -> [String]) {
        lines.append(.init(indentation: indentation, line: .deferred(deferred)))
    }

    func prepend(_ text: String, at indentation: Int) {
        lines.insert(.init(indentation: indentation, line: .text(text)), at: 0)
    }

    /// Use this function when the conditions are not yet known and knowing them will require a global resolution first
    func prepend(at indentation: Int, deferred: @escaping () -> [String]) {
        lines.insert(.init(indentation: indentation, line: .deferred(deferred)), at: 0)
    }

    func append(contentsOf data: [LineDef]) {
        lines.append(contentsOf: data)
    }

    func prepend(contentsOf data: [LineDef]) {
        lines.insert(contentsOf: data, at: 0)
    }

    func append(condition tag: String) {
        if !conditionTags.contains(where: { $0.name == tag }) {
            conditionTags.append((name: tag, read: false))
        }
    }

    func appendDefault(name: String, value: String) {
        defaultValues[name] = value
    }

    func appendMutable(name: String) {
        guard !mutableParameters.contains(name) else { return }

        mutableParameters.append(name)
    }

    @discardableResult
    func markAsRead(condition name: String) -> Bool {
        for (i, c) in conditionTags.enumerated() {
            guard c.name == name else { continue }
            conditionTags[i] = (name: name, read: true)
            return true
        }

        return false
    }

    func isRead(condition name: String) -> Bool {
        guard let item = conditionTags.first(where: { $0.name == name }) else { return false }

        return item.read
    }

    func asText(at indenation: Int = 0) -> String {
        asLines(at: indenation).joined(separator: "\n")
    }

    func asLines(at indentation: Int = 0) -> [String] {
        var result = [String]()

        for l in lines {
            switch l.line {
            case let .text(string):
                result.append("\(String(repeating: "    ", count: indentation + l.indentation))\(string)")
            case let .deferred(f):
                for i in f() {
                    result.append("\(String(repeating: "    ", count: indentation + l.indentation))\(i)")
                }
            }
        }

        return result
    }
}

extension PageProperties.ProtocolCompliance {
    var asDeclaration: String {
        switch self {
        case let .simple(name):
            name
        case let .generic(name, _):
            name
        }
    }

    var asAssociatedType: [String] {
        switch self {
        case .simple:
            return []
        case let .generic(_, associatedTypes):
            var result: [String] = []
            for (name, type) in associatedTypes {
                result.append("typealias \(name) = \(type)")
            }

            return result
        }
    }
}

extension PageProperties.ProtocolCompliance: LosslessStringConvertible {
    private enum ParseState {
        case parsingProtocolName
        case parsingAssociatedName
        case parsingAssociatedType
    }

    public init?(_ description: String) {
        guard !description.isEmpty else { return nil }

        var protocolName = ""
        var associatedTypes: [(name: String, type: String)] = []

        var currentAssosiatedName = ""
        var currentAssociatedType = ""

        var state: ParseState = .parsingProtocolName

        for c in description {
            switch state {
            case .parsingProtocolName:
                if c == ":" {
                    guard !protocolName.isEmpty else { return nil }
                    state = .parsingAssociatedName
                } else if c.isLetter {
                    protocolName.append(c)
                } else if c.isNumber, !protocolName.isEmpty {
                    protocolName.append(c)
                } else {
                    return nil
                }
            case .parsingAssociatedName:
                if c == ":" {
                    guard !currentAssosiatedName.isEmpty else { return nil }
                    state = .parsingAssociatedType
                } else if c.isLetter {
                    currentAssosiatedName.append(c)
                } else if c.isNumber, !currentAssosiatedName.isEmpty {
                    currentAssosiatedName.append(c)
                } else {
                    return nil
                }
            case .parsingAssociatedType:
                if c == ":" {
                    guard !currentAssociatedType.isEmpty else { return nil }
                    associatedTypes.append((name: currentAssosiatedName, type: currentAssosiatedName))
                    currentAssosiatedName = ""
                    currentAssociatedType = ""
                    state = .parsingAssociatedName
                } else if c.isLetter {
                    currentAssociatedType.append(c)
                } else if c.isNumber, !currentAssociatedType.isEmpty {
                    currentAssociatedType.append(c)
                } else {
                    return nil
                }
            }
        }

        guard !protocolName.isEmpty else { return nil }

        guard state != .parsingAssociatedName else { return nil }

        if case .parsingAssociatedType = state {
            guard !currentAssociatedType.isEmpty else { return nil }
            associatedTypes.append((name: currentAssosiatedName, type: currentAssociatedType))
        }

        if associatedTypes.isEmpty {
            self = .simple(name: protocolName)
        } else {
            self = .generic(name: protocolName, associatedTypes: associatedTypes)
        }
    }

    public var description: String {
        var result: String

        switch self {
        case let .simple(name):
            result = name
        case let .generic(name, associatedTypes):
            result = name
            for (name, type) in associatedTypes {
                result.append(":\(name):\(type)")
            }
        }

        return result
    }
}
