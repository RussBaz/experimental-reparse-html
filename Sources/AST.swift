import SwiftSoup

public indirect enum AST {
    case constant(contents: Contents)
    case slotDeclaration(name: String, defaults: ASTStorage)
    case slotCommand(type: SlotCommandType, contents: ASTStorage)
    case include(name: String, contents: ASTStorage)
    case conditional(name: String?, check: String, type: ConditionType, contents: ASTStorage)
    case loop(forEvery: String, name: String?, contents: ASTStorage)
    case modifiers(applying: [AttributeModifier], tag: TagType)
    case eval(line: String)
    case value(of: String)
    case assignment(name: String, line: String)
    case index
    case item
    case endOfBranch

    public enum TagType {
        case openingTag(name: String, attributes: AttributeStorage)
        case voidTag(name: String, attributes: AttributeStorage)
        case closingTag(name: String)
    }

    public enum Content {
        case tag(value: TagType)
        case text(value: String)
        case data(value: String)
        case newLine
    }

    public enum ConditionType {
        case ifType
        case elseIfType
        case elseType
    }

    public enum SlotCommandType {
        case add(name: String)
        case replace(name: String)
    }

    public enum AttributeModifier {
        case append(name: String, value: AttributeStorage.AttributeValue, condition: AttributeCondition?)
        case replace(name: String, value: AttributeStorage.AttributeValue, condition: AttributeCondition?)
        case remove(name: String, condition: AttributeCondition?)
    }

    public struct AttributeCondition {
        let type: ConditionType
        let check: String
        let name: String?
    }

    public class Contents {
        var values: [Content] = []

        init(_ values: [Content] = []) {
            self.values = values
        }

        var isEmpty: Bool {
            values.isEmpty || values.allSatisfy(\.isEmpty)
        }
    }
}

extension AST.TagType {
    static func from(element: Element, closing: Bool = false) -> Self {
        let tag = element.tag()
        let name = tag.getName()

        return if closing {
            .closingTag(name: name)
        } else {
            if tag.isSelfClosing() {
                .voidTag(name: name, attributes: AttributeStorage.from(element: element))
            } else {
                .openingTag(name: name, attributes: AttributeStorage.from(element: element))
            }
        }
    }

    var name: String {
        switch self {
        case let .openingTag(name, _):
            name
        case let .voidTag(name, _):
            name
        case let .closingTag(name):
            name
        }
    }

    var attributes: AttributeStorage? {
        switch self {
        case let .openingTag(_, attributes):
            attributes
        case let .voidTag(_, attributes):
            attributes
        case .closingTag:
            nil
        }
    }

    var isOpening: Bool {
        if case .openingTag = self {
            true
        } else {
            false
        }
    }

    var isClosing: Bool {
        if case .closingTag = self {
            true
        } else {
            false
        }
    }

    var isVoid: Bool {
        if case .voidTag = self {
            true
        } else {
            false
        }
    }
}

public extension AST.Content {
    var isEmpty: Bool {
        switch self {
        case .tag:
            false
        case let .text(value):
            value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case let .data(value):
            value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .newLine:
            true
        }
    }

    func text() -> String {
        switch self {
        case let .tag(value: value):
            value.text()
        case let .text(value: value):
            value
        case let .data(value: value):
            value
        case .newLine:
            "\n"
        }
    }
}

public extension AST {
    var isEmptyConstant: Bool {
        if case let .constant(contents) = self {
            contents.isEmpty
        } else {
            false
        }
    }
}

public extension AST.TagType {
    func text() -> String {
        switch self {
        case let .openingTag(name, attributes):
            "<\(name)\(attributes)>"
        case let .voidTag(name, attributes):
            "<\(name)\(attributes)/>"
        case let .closingTag(name):
            "</\(name)>"
        }
    }

    var isControl: Bool {
        ["r-include", "r-set", "r-unset", "r-var", "r-value", "r-eval", "r-slot", "r-block", "r-index", "r-item"].contains(name)
    }
}

extension AST.Contents {
    struct ContentsStringIterator: Sequence, IteratorProtocol {
        var current = 0
        let data: AST.Contents

        mutating func next() -> String? {
            guard !data.isEmpty else {
                return nil
            }
            guard current < data.values.count, current >= 0 else {
                return nil
            }

            let previousIndex: Int? = if current > 0 { current - 1 } else { nil }
            let nextIndex: Int? = if current < data.values.count - 1 { current + 1 } else { nil }

            let previousItem: AST.Content? = if let previousIndex { data.values[previousIndex] } else { nil }
            let currentItem = data.values[current]
            let nextItem: AST.Content? = if let nextIndex { data.values[nextIndex] } else { nil }

            current += 1

            guard let previousItem, let nextItem else {
                if currentItem.isEmpty {
                    return "\n"
                } else {
                    let r = currentItem.text()
                    return r
                }
            }

            if case .tag(.openingTag) = previousItem, case .tag(.closingTag) = nextItem {
                let r = currentItem.text()
                return r
            }

            if currentItem.isEmpty {
                return "\n"
            } else {
                let r = currentItem.text()
                return r
            }
        }
    }

    var lines: ContentsStringIterator {
        ContentsStringIterator(data: self)
    }
}

extension AST.Contents: CustomStringConvertible {
    public var description: String {
        var buffer: [String] = []
        for item in lines {
            if item == "\n" {
                buffer.append("")
            } else {
                buffer.append(">> \(item)")
            }
        }

        return "[\n\(buffer.joined(separator: "\n"))\n]"
    }
}
