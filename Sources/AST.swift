import SwiftSoup

indirect enum AST {
    case constant(contents: [String])
    case slotDeclaration(name: String, defaults: ASTStorage)
    case slotCommand(type: SlotCommandType, contents: ASTStorage)
    case include(name: String, contents: ASTStorage)
    case conditional(name: String?, check: String, type: ConditionType, contents: ASTStorage)
    case loop(forEvery: String, name: String?, contents: ASTStorage)
    case modifiers(applying: [AttributeModifier], node: String)
    case eval(line: String)
    case value(of: String)
    case assignment(name: String, line: String)
    case index
    case item
    case endOfBranch

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
