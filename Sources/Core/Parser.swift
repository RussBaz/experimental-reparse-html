import Foundation
import ReparseRuntime

public final class Parser {
    let ast = ASTStorage()
    var closeDepth: [Int: Int] = [:]
    var ignoringUntilDepth: Int?
    var nestedEvalMode = false

    func parseNode(_ content: AST.Content, at depth: Int, leaving: Bool) {
        if let ignoring = ignoringUntilDepth, ignoring <= depth {
            ignoringUntilDepth = nil
        }

        guard ignoringUntilDepth == nil else { return }

        guard !nestedEvalMode else {
            append(eval: content)
            return
        }

        switch content {
        case let .tag(value):
            append(tag: value, at: depth)
        case let .text(value):
            append(text: value)
        case let .data(value):
            append(text: value)
        case .newLine:
            append(text: "\n")
        }

        if leaving {
            closeInnerASTs(for: depth)
        }
    }

    static func parse(html root: SimpleHtmlParser) -> ASTStorage? {
        let parser = Parser()
        var previousDepth = 0

        var previousNode: AST.Content?
        var secondPreviousNode: AST.Content?

        for node in root.nodes {
            let leaving = node.depth < previousDepth
            let content = node.content
            if content.isEmpty, case let .tag(value) = previousNode, let secondPreviousNode, secondPreviousNode.isEmpty {
                if content.text() == secondPreviousNode.text(), value.isControl {
                    ()
                } else {
                    parser.parseNode(node.content, at: node.depth, leaving: leaving)
                }
            } else {
                parser.parseNode(node.content, at: node.depth, leaving: leaving)
            }

            previousDepth = node.depth
            secondPreviousNode = previousNode
            previousNode = content
        }

        let result = parser.ast
        result.closeBranch()

        return result
    }

    static func parse(html text: String) -> ASTStorage? {
        let parser = SimpleHtmlParser(input: text)
        parser.parse()

        return parse(html: parser)
    }
}

extension Parser {
    struct ControlAttrs {
        let ifLine: String?
        let ifElseLine: String?
        let elseLine: Bool
        let tagLine: String?
        let forLine: String?
        let addToSlotLine: String?
        let replaceSlotLine: String?

        static func new(from e: AST.TagType) -> ControlAttrs? {
            var ifLine: String?
            var ifElseLine: String?
            var elseLine = false
            var tagLine: String?
            var forLine: String?
            var addToSlotLine: String?
            var replaceSlotLine: String?

            let name: String
            let attributes: SwiftAttributeStorage

            switch e {
            case let .openingTag(n, a):
                name = n
                attributes = a
            case let .voidTag(n, a):
                name = n
                attributes = a
            case let .closingTag(n):
                name = n
                attributes = SwiftAttributeStorage()
            }

            guard name != "r-set", name != "r-unset", name != "r-require", name != "r-extend" else { return nil }

            if let v = attributes.remove("r-if") {
                ifLine = v.text
            }

            if let v = attributes.remove("r-else-if") {
                ifElseLine = v.text
            }

            if let _ = attributes.remove("r-else") {
                elseLine = true
            }

            if let v = attributes.remove("r-tag") {
                tagLine = v.text
            }

            if let v = attributes.remove("r-for-every") {
                forLine = v.text
            }

            if let v = attributes.remove("r-add-to-slot") {
                addToSlotLine = v.text
            }

            if let v = attributes.remove("r-replace-slot") {
                replaceSlotLine = v.text
            }

            guard ifLine != nil || ifElseLine != nil || !elseLine || tagLine != nil || forLine != nil || addToSlotLine != nil || replaceSlotLine != nil else { return nil }

            return .init(ifLine: ifLine, ifElseLine: ifElseLine, elseLine: elseLine, tagLine: tagLine, forLine: forLine, addToSlotLine: addToSlotLine, replaceSlotLine: replaceSlotLine)
        }
    }
}

extension Parser {
    func openTag(_ tag: AST.TagType, at depth: Int) {
        guard let _ = ast.getCurrentBranch() else { return }

        if let controlAttrs = ControlAttrs.new(from: tag) {
            if let conditional = isConditional(controlAttrs), let branch = ast.getCurrentBranch() {
                closeDepth[depth] = (closeDepth[depth] ?? 0) + 1
                branch.append(node: conditional)
            }

            if let loop = isLoop(controlAttrs), let branch = ast.getCurrentBranch() {
                closeDepth[depth] = (closeDepth[depth] ?? 0) + 1
                branch.append(node: loop)
            }

            if let slotControl = isSlotCommand(controlAttrs), let branch = ast.getCurrentBranch() {
                closeDepth[depth] = (closeDepth[depth] ?? 0) + 1
                branch.append(node: slotControl)
            }
        }

        switch tag.name {
        case "r-include":
            openIncludeTag(tag, at: depth)
        case "r-extend":
            openExtendTag(tag, at: depth)
        case "r-require":
            openRequireTag(tag, at: depth)
        case "r-set":
            openSetTag(tag, at: depth)
        case "r-unset":
            openUnsetTag(tag, at: depth)
        case "r-var":
            openVarTag(tag, at: depth)
        case "r-value":
            openValueTag(tag, at: depth)
        case "r-eval":
            openEvalTag(tag, at: depth)
        case "r-slot":
            openSlotTag(tag, at: depth)
        case "r-block":
            openBlockTag(tag, at: depth)
        case "r-index":
            openIndexTag(tag, at: depth)
        case "r-item":
            openItemTag(tag, at: depth)
        default:
            openConstantTag(tag, at: depth)
        }
    }

    func append(eval content: AST.Content) {
        guard let branch = ast.getCurrentBranch() else { return }
        guard let last = branch.popLast() else { return }
        guard case let .eval(line) = last else {
            branch.append(node: last)
            return
        }

        switch content {
        case let .tag(value):
            if value.isClosing, value.name == "r-eval" {
                branch.append(node: .eval(line: line))
                nestedEvalMode = false
            } else {
                branch.append(node: .eval(line: line + value.text()))
            }
        case let .text(value):
            branch.append(node: .eval(line: line + value))
        case let .data(value):
            branch.append(node: .eval(line: line + value))
        case .newLine:
            branch.append(node: .eval(line: line + "\n"))
        }
    }

    func append(text: String) {
        guard let branch = ast.getCurrentBranch() else { return }

        branch.append(constant: .text(value: text))
    }

    func append(tag: AST.TagType, at depth: Int) {
        switch tag {
        case .openingTag, .voidTag:
            openTag(tag, at: depth)
        case .closingTag:
            closeTag(tag, at: depth)
        }
    }

    func closeInnerASTs(for depth: Int) {
        let times = closeDepth.removeValue(forKey: depth) ?? 0

        guard times > 0 else { return }

        for _ in 0 ..< times {
            if let branch = ast.getCurrentBranch() {
                branch.append(node: .endOfBranch)
            }
        }
    }

    func closeTag(_ tag: AST.TagType, at _: Int) {
        guard let branch = ast.getCurrentBranch() else { return }
        guard tag.isClosing else { return }

        switch tag.name {
        case "r-include":
            branch.closeBranch()
        case "r-extend":
            ()
        case "r-require":
            ()
        case "r-set":
            ()
        case "r-unset":
            ()
        case "r-var":
            ()
        case "r-value":
            ()
        case "r-eval":
            ()
        case "r-slot":
            branch.closeBranch()
        case "r-block":
            ()
        case "r-index":
            ()
        case "r-item":
            ()
        default:
            branch.append(constant: .tag(value: .closingTag(name: tag.name)))
        }
    }

    func isConditional(_ attrs: ControlAttrs) -> AST? {
        switch (attrs.ifLine, attrs.ifElseLine, attrs.elseLine, attrs.tagLine) {
        case let (.some(line), _, _, tag):
            .conditional(name: tag, check: line, type: .ifType, contents: ASTStorage())
        case let (.none, .some(line), _, tag):
            .conditional(name: tag, check: line, type: .elseIfType, contents: ASTStorage())
        case let (.none, .none, true, tag):
            .conditional(name: tag, check: "", type: .elseType, contents: ASTStorage())
        case (.none, .none, false, _):
            nil
        }
    }

    func isLoop(_ attrs: ControlAttrs) -> AST? {
        switch (attrs.forLine, attrs.tagLine) {
        case let (.some(line), tag):
            .loop(forEvery: line, name: tag, contents: ASTStorage())
        case (.none, _):
            nil
        }
    }

    func isSlotCommand(_ attrs: ControlAttrs) -> AST? {
        if let name = attrs.addToSlotLine {
            return .slotCommand(type: .add(name: name), contents: ASTStorage())
        }

        if let name = attrs.replaceSlotLine {
            return .slotCommand(type: .replace(name: name), contents: ASTStorage())
        }

        return nil
    }

    func openIncludeTag(_ tag: AST.TagType, at _: Int) {
        guard let branch = ast.getCurrentBranch() else { return }
        guard !tag.isClosing else { return }
        guard let attributes = tag.attributes else { return }
        guard let name = attributes.find("name") else { return }

        let storage = ASTStorage()
        if tag.isVoid {
            storage.append(node: .endOfBranch)
        }

        branch.append(node: .include(name: name, contents: storage))
    }

    func openExtendTag(_ tag: AST.TagType, at depth: Int) {
        guard ast.values.allSatisfy({ v in
            if case .extend = v {
                return true
            }
            if case .requirement = v {
                return true
            }
            if v.isEmptyConstant {
                return true
            }
            return false
        }) else { return }
        guard !tag.isClosing else { return }
        guard let attributes = tag.attributes else { return }

        if !tag.isVoid { ignoringUntilDepth = depth }

        guard let name = attributes.find("name") else { return }

        let conditionName = attributes.find("r-tag")

        let condition: AST.EmbeddedCondition? = if let check = attributes.find("r-if") {
            .init(type: .ifType, check: check, name: conditionName)
        } else if let check = attributes.find("r-else-if") {
            .init(type: .ifType, check: check, name: conditionName)
        } else if attributes.has("r-else") {
            .init(type: .ifType, check: "", name: conditionName)
        } else {
            nil
        }

        ast.append(node: .extend(name: name, condition: condition))
    }

    func openRequireTag(_ tag: AST.TagType, at depth: Int) {
        guard ast.values.allSatisfy({ v in
            if case .requirement = v {
                return true
            }
            if v.isEmptyConstant {
                return true
            }

            return false
        }) else { return }
        guard !tag.isClosing else { return }
        guard let attributes = tag.attributes else { return }

        if !tag.isVoid { ignoringUntilDepth = depth }

        guard let name = attributes.find("name") else { return }
        guard let type = attributes.find("type") else { return }

        let label = attributes.find("label")
        let defaultValue = attributes.find("default")

        ast.append(node: .requirement(name: name, type: type, label: label, value: defaultValue))
    }

    func openSetTag(_ tag: AST.TagType, at depth: Int) {
        guard let branch = ast.getCurrentBranch() else { return }
        guard tag.isVoid else { ignoringUntilDepth = depth; return }
        guard let attributes = tag.attributes else { return }
        guard let name = attributes.find("name") else { return }
        guard let attributeValue = attributes["value"] else { return }

        let appending = if attributes.has("append") { true } else { false }

        let conditionName = attributes.find("r-tag")

        let condition: AST.EmbeddedCondition? = if let check = attributes.find("r-if") {
            .init(type: .ifType, check: check, name: conditionName)
        } else if let check = attributes.find("r-else-if") {
            .init(type: .ifType, check: check, name: conditionName)
        } else if attributes.has("r-else") {
            .init(type: .ifType, check: "", name: conditionName)
        } else {
            nil
        }

        let modifier: AST.AttributeModifier = if appending {
            .append(name: name, value: attributeValue, condition: condition)
        } else {
            .replace(name: name, value: attributeValue, condition: condition)
        }

        if let last = branch.popLast() {
            switch last {
            case .modifiers(applying: var modifiers, tag: let tag):
                modifiers.append(modifier)
                branch.append(node: .modifiers(applying: modifiers, tag: tag))
            case let .constant(contents: contents):
                if let index = contents.values.lastIndex(where: { !$0.isEmpty }) {
                    let item = contents.values[index]

                    guard case let .tag(value: tag) = item, !tag.isClosing else {
                        branch.append(node: last)
                        return
                    }

                    if contents.values.endIndex - 1 == index {
                        contents.values.removeLast()
                    } else {
                        contents.values.removeSubrange(index ..< index + 2)
                    }

                    branch.append(node: .constant(contents: contents))
                    branch.append(node: .modifiers(applying: [modifier], tag: tag))
                } else {
                    guard let secondLast = branch.popLast() else {
                        branch.append(node: last)
                        return
                    }

                    guard case .modifiers(var modifiers, let tag) = secondLast else {
                        branch.append(node: secondLast)
                        branch.append(node: last)
                        return
                    }

                    modifiers.append(modifier)
                    branch.append(node: .modifiers(applying: modifiers, tag: tag))
                    branch.append(node: last)
                }
            default:
                branch.append(node: last)
            }
        }
    }

    func openUnsetTag(_ tag: AST.TagType, at depth: Int) {
        guard let branch = ast.getCurrentBranch() else { return }
        guard tag.isVoid else { ignoringUntilDepth = depth; return }
        guard let attributes = tag.attributes else { return }
        guard let name = attributes.find("name") else { return }

        let conditionName = attributes.find("r-tag")

        let condition: AST.EmbeddedCondition? = if let check = attributes.find("r-if") {
            .init(type: .ifType, check: check, name: conditionName)
        } else if let check = attributes.find("r-else-if") {
            .init(type: .ifType, check: check, name: conditionName)
        } else if attributes.has("r-else") {
            .init(type: .ifType, check: "", name: conditionName)
        } else {
            nil
        }

        let modifier: AST.AttributeModifier = .remove(name: name, condition: condition)

        ignoringUntilDepth = depth

        if let last = branch.popLast() {
            switch last {
            case .modifiers(applying: var modifiers, tag: let tag):
                modifiers.append(modifier)
                branch.append(node: .modifiers(applying: modifiers, tag: tag))
            case let .constant(contents: contents):
                if let index = contents.values.lastIndex(where: { !$0.isEmpty }) {
                    let item = contents.values[index]

                    guard case let .tag(value: tag) = item, !tag.isClosing else {
                        branch.append(node: last)
                        return
                    }

                    if contents.values.endIndex - 1 == index {
                        contents.values.removeLast()
                    } else {
                        contents.values.removeSubrange(index ..< index + 2)
                    }

                    branch.append(node: .constant(contents: contents))
                    branch.append(node: .modifiers(applying: [modifier], tag: tag))
                } else {
                    guard let secondLast = branch.popLast() else {
                        branch.append(node: last)
                        return
                    }

                    guard case .modifiers(var modifiers, let tag) = secondLast else {
                        branch.append(node: secondLast)
                        branch.append(node: last)
                        return
                    }

                    modifiers.append(modifier)
                    branch.append(node: .modifiers(applying: modifiers, tag: tag))
                    branch.append(node: last)
                }
            default:
                branch.append(node: last)
            }
        }
    }

    func openVarTag(_ tag: AST.TagType, at depth: Int) {
        guard let branch = ast.getCurrentBranch() else { return }
        guard tag.isVoid else { ignoringUntilDepth = depth; return }
        guard let attributes = tag.attributes else { return }
        guard let name = attributes.find("name") else { return }
        guard let line = attributes.find("line") else { return }

        branch.append(node: .assignment(name: name, line: line))
    }

    func openValueTag(_ tag: AST.TagType, at depth: Int) {
        guard let branch = ast.getCurrentBranch() else { return }
        guard tag.isVoid else { ignoringUntilDepth = depth; return }
        guard let attributes = tag.attributes else { return }
        guard let name = attributes.find("of") else { return }

        let defaultValue = attributes.find("default")

        branch.append(node: .value(of: name, defaultValue: defaultValue))
    }

    func openEvalTag(_ tag: AST.TagType, at depth: Int) {
        guard let branch = ast.getCurrentBranch() else { return }
        guard !tag.isClosing else { return }
        guard let attributes = tag.attributes else { return }

        if let line = attributes.find("line") {
            branch.append(node: .eval(line: line))
            if tag.isOpening {
                ignoringUntilDepth = depth
            }
        } else if tag.isOpening {
            branch.append(node: .eval(line: ""))
            nestedEvalMode = true
        }
    }

    func openSlotTag(_ tag: AST.TagType, at _: Int) {
        guard let branch = ast.getCurrentBranch() else { return }
        guard !tag.isClosing else { return }
        guard let attributes = tag.attributes else { return }

        let name = attributes.find("name") ?? "default"

        let storage = ASTStorage()
        if tag.isVoid {
            storage.closeBranch()
        }
        branch.append(node: .slotDeclaration(name: name, defaults: storage))
    }

    func openBlockTag(_ tag: AST.TagType, at depth: Int) {
        guard let _ = ast.getCurrentBranch() else { return }
        guard tag.isOpening else { ignoringUntilDepth = depth; return }
    }

    func openIndexTag(_ tag: AST.TagType, at depth: Int) {
        guard let branch = ast.getCurrentBranch() else { return }
        guard tag.isVoid else { ignoringUntilDepth = depth; return }

        branch.append(node: .index)
    }

    func openItemTag(_ tag: AST.TagType, at depth: Int) {
        guard let branch = ast.getCurrentBranch() else { return }
        guard tag.isVoid else { ignoringUntilDepth = depth; return }

        branch.append(node: .item)
    }

    func openConstantTag(_ tag: AST.TagType, at _: Int) {
        guard let branch = ast.getCurrentBranch() else { return }
        branch.append(constant: .tag(value: tag))
    }
}
