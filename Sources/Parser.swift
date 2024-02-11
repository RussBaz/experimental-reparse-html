import Foundation
import SwiftSoup

final class NewParser: NodeVisitor {
    let ast = ASTStorage()
    var closeDepth: [Int: Int] = [:]
    var ignoringUntilDepth: Int?

    func head(_ node: Node, _ depth: Int) throws {
        guard ignoringUntilDepth == nil else { return }

        if let node = node as? TextNode {
            openTag(node)
        } else if let node = node as? Element {
            if let controlAttrs = ControlAttrs.new(from: node) {
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

            switch node.tagName() {
            case "r-include":
                openIncludeTag(node)
            case "r-set":
                openSetTag(node, depth: depth)
            case "r-unset":
                openUnsetTag(node, depth: depth)
            case "r-var":
                openVarTag(node, depth: depth)
            case "r-value":
                openValueTag(node, depth: depth)
            case "r-eval":
                openEvalTag(node, depth: depth)
            case "r-slot":
                openSlotTag(node)
            case "r-block":
                openBlockTag(node)
            case "r-index":
                openIndexTag(node, depth: depth)
            case "r-item":
                openItemTag(node, depth: depth)
            default:
                openTag(node)
            }
        } else if let node = node as? DataNode {
            openTag(node)
        } else {
            print("Error - unreachable node reached on tag entry: \(node)")
        }
    }

    func tail(_ node: Node, _ depth: Int) throws {
        guard ignoringUntilDepth == nil else {
            if ignoringUntilDepth! <= depth {
                ignoringUntilDepth = nil
            }
            return
        }

        if let node = node as? TextNode {
            closeTag(node)
        } else if let node = node as? Element {
            closeTag(node)
        } else if let node = node as? DataNode {
            closeTag(node)
        } else {
            print("Error - unreachable node reached on tag exit: \(node)")
        }

        closeInnerASTs(for: depth)
    }

    static func parse(html root: Element) throws -> ASTStorage {
        let parser = NewParser()

        for node in root.getChildNodes() {
            try node.traverse(parser)
        }

        return parser.ast
    }

    static func parse(html text: String) throws -> ASTStorage? {
        let doc = try SwiftSoup.parseBodyFragment(text)
        guard let body = doc.body() else { return nil }

        return try parse(html: body)
    }
}

extension NewParser {
    struct ControlAttrs {
        let ifLine: String?
        let ifElseLine: String?
        let elseLine: Bool
        let tagLine: String?
        let forLine: String?
        let addToSlotLine: String?
        let replaceSlotLine: String?

        static func new(from e: Element) -> ControlAttrs? {
            var ifLine: String?
            var ifElseLine: String?
            var elseLine = false
            var tagLine: String?
            var forLine: String?
            var addToSlotLine: String?
            var replaceSlotLine: String?

            let tagName = e.tagName()

            guard tagName != "r-set", tagName != "r-unset" else { return nil }

            if e.hasAttr("r-if"), let v = try? e.attr("r-if"), let _ = try? e.removeAttr("r-if") {
                ifLine = v
            }

            if e.hasAttr("r-else-if"), let v = try? e.attr("r-else-if"), let _ = try? e.removeAttr("r-else-if") {
                ifElseLine = v
            }

            if e.hasAttr("r-else"), let _ = try? e.removeAttr("r-else") {
                elseLine = true
            }

            if e.hasAttr("r-tag"), let v = try? e.attr("r-tag"), let _ = try? e.removeAttr("r-tag") {
                tagLine = v
            }

            if e.hasAttr("r-for-every"), let v = try? e.attr("r-for-every"), let _ = try? e.removeAttr("r-for-every") {
                forLine = v
            }

            if e.hasAttr("r-add-to-slot"), let v = try? e.attr("r-add-to-slot"), let _ = try? e.removeAttr("r-add-to-slot") {
                addToSlotLine = v
            }

            if e.hasAttr("r-replace-slot"), let v = try? e.attr("r-replace-slot"), let _ = try? e.removeAttr("r-replace-slot") {
                replaceSlotLine = v
            }

            guard ifLine != nil || ifElseLine != nil || !elseLine || tagLine != nil || forLine != nil || addToSlotLine != nil || replaceSlotLine != nil else { return nil }

            return .init(ifLine: ifLine, ifElseLine: ifElseLine, elseLine: elseLine, tagLine: tagLine, forLine: forLine, addToSlotLine: addToSlotLine, replaceSlotLine: replaceSlotLine)
        }
    }
}

extension NewParser {
    func openTag(_ text: TextNode) {
        guard let branch = ast.getCurrentBranch() else { return }
        branch.appendToLastConstant(content: .text(value: text.text()))
    }

    func openTag(_ element: Element) {
        guard let branch = ast.getCurrentBranch() else { return }
        let tag = AST.TagType.from(element: element)

        branch.appendToLastConstant(content: .tag(value: tag))
    }

    func openTag(_ element: DataNode) {
        guard let branch = ast.getCurrentBranch() else { return }

        let tag = element.nodeName()

        if tag == "#data" {
            branch.appendToLastConstant(content: .text(value: element.getWholeData()))
        } else {
            branch.appendToLastConstant(content: .tag(value: .openingTag(name: tag, attributes: AttributeStorage.from(element: element))))
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

    func closeTag(_: TextNode) {
        // Do nothing on text
    }

    func closeTag(_ element: Element) {
        guard let branch = ast.getCurrentBranch() else { return }

        let tag = element.tag()

        guard !tag.isSelfClosing() else { return }

        let tagName = tag.getNameNormal()

        switch tagName {
        case "r-include":
            branch.closeBranch()
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
            branch.appendToLastConstant(content: .tag(value: .closingTag(name: tagName)))
        }
    }

    func closeTag(_ element: DataNode) {
        guard let branch = ast.getCurrentBranch() else { return }

        let tag = element.nodeName()

        guard tag != "#data" else { return }

        branch.appendToLastConstant(content: .tag(value: .closingTag(name: tag)))
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

    func openIncludeTag(_ element: Element) {
        guard let branch = ast.getCurrentBranch() else { return }

        if element.hasAttr("name"), let name = try? element.attr("name") {
            let storage = ASTStorage()
            if element.tag().isSelfClosing() {
                storage.append(node: .endOfBranch)
            }
            branch.append(node: .include(name: name, contents: storage))
        } else {
            try? element.remove()
        }
    }

    func openSetTag(_ element: Element, depth: Int) {
        guard let branch = ast.getCurrentBranch() else { return }

        guard element.hasAttr("name"), let name = try? element.attr("name") else {
            if element.tag().isSelfClosing() {
                try? element.remove()
            } else {
                ignoringUntilDepth = depth
            }
            return
        }

        let attributeValue: AttributeStorage.AttributeValue = if element.hasAttr("value") {
            if let value = try? element.attr("value") {
                if name.starts(with: "data-"), name.count > 5 {
                    .data(value)
                } else {
                    .string(value)
                }
            } else {
                .flag
            }
        } else {
            .flag
        }

        let appending = if element.hasAttr("append") { true } else { false }

        let conditionName: String? = if element.hasAttr("r-tag") {
            try? element.attr("r-tag")
        } else {
            nil
        }

        let condition: AST.AttributeCondition? = if element.hasAttr("r-if") {
            if let check = try? element.attr("r-if") {
                .init(type: .ifType, check: check, name: conditionName)
            } else {
                nil
            }
        } else if element.hasAttr("r-else-if") {
            if let check = try? element.attr("r-else-if") {
                .init(type: .ifType, check: check, name: conditionName)
            } else {
                nil
            }
        } else if element.hasAttr("r-else") {
            .init(type: .ifType, check: "", name: conditionName)
        } else {
            nil
        }

        let modifier: AST.AttributeModifier = if appending {
            .append(name: name, value: attributeValue, condition: condition)
        } else {
            .replace(name: name, value: attributeValue, condition: condition)
        }

        ignoringUntilDepth = depth

        if let last = branch.popLast() {
            switch last {
            case .modifiers(applying: var modifiers, tag: let tag):
                modifiers.append(modifier)
                branch.append(node: .modifiers(applying: modifiers, tag: tag))
            case var .constant(contents: contents):
                if let index = contents.lastIndex(where: { !$0.isEmpty }) {
                    let item = contents[index]

                    guard case let .tag(value: tag) = item, !tag.isClosing else {
                        branch.append(node: last)
                        return
                    }

                    if contents.endIndex - 1 == index {
                        contents.removeLast()
                    } else {
                        contents.removeSubrange(index ..< index + 2)
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

    func openUnsetTag(_ element: Element, depth: Int) {
        guard let branch = ast.getCurrentBranch() else { return }

        guard element.hasAttr("name"), let name = try? element.attr("name") else {
            if element.tag().isSelfClosing() {
                try? element.remove()
            } else {
                ignoringUntilDepth = depth
            }
            return
        }

        let conditionName: String? = if element.hasAttr("r-tag") {
            try? element.attr("r-tag")
        } else {
            nil
        }

        let condition: AST.AttributeCondition? = if element.hasAttr("r-if") {
            if let check = try? element.attr("r-if") {
                .init(type: .ifType, check: check, name: conditionName)
            } else {
                nil
            }
        } else if element.hasAttr("r-else-if") {
            if let check = try? element.attr("r-else-if") {
                .init(type: .ifType, check: check, name: conditionName)
            } else {
                nil
            }
        } else if element.hasAttr("r-else") {
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
            case var .constant(contents: contents):
                if let index = contents.lastIndex(where: { !$0.isEmpty }) {
                    let item = contents[index]

                    guard case let .tag(value: tag) = item, !tag.isClosing else {
                        branch.append(node: last)
                        return
                    }

                    if contents.endIndex - 1 == index {
                        contents.removeLast()
                    } else {
                        contents.removeSubrange(index ..< index + 2)
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

    func openVarTag(_ element: Element, depth: Int) {
        guard let branch = ast.getCurrentBranch() else { return }

        guard element.hasAttr("name"), let name = try? element.attr("name") else {
            if element.tag().isSelfClosing() {
                try? element.remove()
            } else {
                ignoringUntilDepth = depth
            }
            return
        }

        guard element.hasAttr("line"), let line = try? element.attr("line") else {
            if element.tag().isSelfClosing() {
                try? element.remove()
            } else {
                ignoringUntilDepth = depth
            }
            return
        }

        branch.append(node: .assignment(name: name, line: line))
    }

    func openValueTag(_ element: Element, depth: Int) {
        guard let branch = ast.getCurrentBranch() else { return }

        guard element.hasAttr("of"), let name = try? element.attr("of") else {
            if element.tag().isSelfClosing() {
                try? element.remove()
            } else {
                ignoringUntilDepth = depth
            }
            return
        }

        branch.append(node: .value(of: name))
    }

    func openEvalTag(_ element: Element, depth _: Int) {
        guard let branch = ast.getCurrentBranch() else { return }

        if element.hasAttr("line"), let line = try? element.attr("line") {
            branch.append(node: .eval(line: line))
        } else {
            let textNodes = element.textNodes()

            if let line = textNodes.first, textNodes.count == 1 {
                branch.append(node: .eval(line: line.text()))
            }
        }
    }

    func openSlotTag(_ element: Element) {
        guard let branch = ast.getCurrentBranch() else { return }

        if element.hasAttr("name"), let name = try? element.attr("name") {
            let storage = ASTStorage()
            if element.tag().isSelfClosing() {
                storage.append(node: .endOfBranch)
            }
            branch.append(node: .slotDeclaration(name: name, defaults: storage))
        } else {
            try? element.remove()
        }
    }

    func openBlockTag(_ element: Element) {
        guard let _ = ast.getCurrentBranch() else { return }

        if element.tag().isSelfClosing() {
            try? element.remove()
        }
    }

    func openIndexTag(_ element: Element, depth: Int) {
        guard let branch = ast.getCurrentBranch() else { return }

        branch.append(node: .index)

        guard element.tag().isSelfClosing() else {
            ignoringUntilDepth = depth
            return
        }
    }

    func openItemTag(_ element: Element, depth: Int) {
        guard let branch = ast.getCurrentBranch() else { return }

        branch.append(node: .item)

        guard element.tag().isSelfClosing() else {
            ignoringUntilDepth = depth
            return
        }
    }
}
