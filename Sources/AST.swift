import SwiftSoup

indirect enum AST {
    case constant(contents: [Content])
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

    enum TagType {
        case openingTag(name: String, attributes: AttributeStorage)
        case selfClosingTag(name: String, attributes: AttributeStorage)
        case closingTag(name: String)
    }

    enum Content {
        case tag(value: TagType)
        case text(value: String)
    }

    enum ConditionType {
        case ifType
        case elseIfType
        case elseType
    }

    enum SlotCommandType {
        case add(name: String)
        case replace(name: String)
    }

    enum AttributeModifier {
        case append(name: String, value: String, condition: AttributeCondition?)
        case replace(name: String, value: String, condition: AttributeCondition?)
        case remove(name: String, condition: AttributeCondition?)
    }

    struct AttributeCondition {
        let type: ConditionType
        let check: String
        let name: String?
    }
}

extension AST.TagType {
    static func from(element: Element, closing: Bool = false) -> Self {
        let tag = element.tag()

        return if closing {
            .closingTag(name: tag.getName())
        } else {
            if tag.isSelfClosing() {
                .selfClosingTag(name: tag.getName(), attributes: AttributeStorage.from(element: element))
            } else {
                .openingTag(name: tag.getName(), attributes: AttributeStorage.from(element: element))
            }
        }
    }

    var isClosing: Bool { if case .closingTag = self {
        true
    } else {
        false
    }}
}

extension AST.Content {
    var isEmpty: Bool {
        switch self {
        case .tag:
            false
        case let .text(value):
            value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
