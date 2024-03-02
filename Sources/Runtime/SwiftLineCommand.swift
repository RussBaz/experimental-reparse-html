public enum SwiftLineCommand {
    case text(value: String)
    case declare(name: String)
    case startDeclareWithDefaults(name: String)
    case endDeclareWithDefaults
    case include(storage: SwiftLineStorage)
    case startIncludeWithDefaults(storage: SwiftLineStorage)
    case endIncludeWithDefaults
    case select(slot: String?)
    case clear
    case noop
}

extension SwiftLineCommand {
    var asString: String? {
        if case let .text(value) = self {
            value
        } else {
            nil
        }
    }
}
