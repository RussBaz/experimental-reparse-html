class ASTStorage {
    var values: [AST] = []

    func getCurrentBranch() -> ASTStorage? {
        if values.isEmpty {
            self
        } else if let last = values.last {
            switch last {
            case .constant:
                self
            case let .slotDeclaration(_, defaults):
                defaults.getCurrentBranch() ?? self
            case let .slotCommand(_, contents):
                contents.getCurrentBranch() ?? self
            case let .include(_, contents):
                contents.getCurrentBranch() ?? self
            case let .conditional(_, _, _, contents):
                contents.getCurrentBranch() ?? self
            case let .loop(_, _, contents):
                contents.getCurrentBranch() ?? self
            case .modifiers:
                self
            case .eval:
                self
            case .value:
                self
            case .assignment:
                self
            case .index:
                self
            case .item:
                self
            case .endOfBranch:
                nil
            }
        } else {
            // Can never be reached
            nil
        }
    }

    func appendToLastConstant(content value: String) {
        if let last = values.popLast() {
            if case var .constant(contents) = last {
                contents.append(value)
                values.append(.constant(contents: contents))
            } else {
                values.append(last)
                values.append(.constant(contents: [value]))
            }
        } else {
            values.append(.constant(contents: [value]))
        }
    }

    func closeBranch() {
        values.append(.endOfBranch)
    }
}
