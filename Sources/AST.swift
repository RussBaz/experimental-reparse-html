import SwiftSoup

indirect enum AST {
    case constant(contents: [String])
    case slotDeclaration(name: String, defaults: [AST])
    case slotCommand(type: SlotCommandType, contents: [AST])
    case include(name: String, contents: [AST])
    case conditional(name: String?, check: String, type: ConditionType, contents: [AST])
    case loop(forEvery: String, name: String?, contents: [AST])
    case modifiers(applying: [AttributeModifier], node: String)
    case eval(line: String)
    case value(of: String)
    case assignment(name: String, line: String)
    case index
    case item

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
        case set(name: String, value: String, condition: AttributeCondition?)
    }

    struct AttributeCondition {
        let type: ConditionType
        let check: String
        let name: String?
    }
}
