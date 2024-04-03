public final class ASTStorage {
    var values: [AST] = []

    func getCurrentBranch() -> ASTStorage? {
        if values.isEmpty {
            self
        } else if let last = values.last {
            switch last {
            case .constant:
                self
            case .requirement:
                self
            case let .slotDeclaration(_, defaults):
                defaults.getCurrentBranch() ?? self
            case let .slotCommand(_, contents):
                contents.getCurrentBranch() ?? self
            case let .include(_, contents):
                contents.getCurrentBranch() ?? self
            case .extend:
                self
            case let .conditional(_, _, _, contents):
                contents.getCurrentBranch() ?? self
            case let .loop(_, _, _, _, contents):
                contents.getCurrentBranch() ?? self
            case .modifiers:
                self
            case .eval:
                self
            case .value:
                self
            case .assignment:
                self
            case .endOfBranch:
                nil
            case .noop:
                self
            }
        } else {
            // Can never be reached
            nil
        }
    }

    func append(constant value: AST.Content) {
        if let last = values.popLast() {
            if case let .constant(contents) = last {
                contents.values.append(value)
                values.append(.constant(contents: contents))
            } else {
                values.append(last)
                values.append(.constant(contents: AST.Contents([value])))
            }
        } else {
            values.append(.constant(contents: AST.Contents([value])))
        }
    }

    func append(node: AST) {
        values.append(node)
    }

    func closeBranch() {
        values.append(.endOfBranch)
    }

    func popLast() -> AST? {
        values.popLast()
    }

    var isEmpty: Bool {
        values.isEmpty || values.count == 1 && values[0] == .endOfBranch
    }
}

extension ASTStorage: CustomStringConvertible {
    public var description: String {
        "[\(values.map { "\($0)" }.joined(separator: "\n\n"))]"
    }
}

extension ASTStorage: Equatable {
    public static func == (lhs: ASTStorage, rhs: ASTStorage) -> Bool {
        lhs.values == rhs.values
    }
}
