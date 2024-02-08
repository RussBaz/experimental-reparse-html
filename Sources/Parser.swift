import Foundation
import SwiftSoup

class NewParser: NodeVisitor {
    let ast = ASTStorage()
    var closeDepth: [Int: Int] = [:]

    func head(_ node: Node, _ depth: Int) throws {
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

                openTag(node)
            } else {
                switch node.tagName() {
                case "r-include":
                    openIncludeTag(node)
                case "r-set":
                    openSetTag(node)
                case "r-unset":
                    openUnsetTag(node)
                case "r-var":
                    openVarTag(node)
                case "r-value":
                    openValueTag(node)
                case "r-eval":
                    openEvalTag(node)
                case "r-slot":
                    openSetTag(node)
                case "r-block":
                    openBlockTag(node)
                case "r-index":
                    openIndexTag(node)
                case "r-item":
                    openItemTag(node)
                default:
                    openTag(node)
                }
            }
        } else {
            print("Error - unreachable node reached on tag entry")
        }
    }

    func tail(_ node: Node, _ depth: Int) throws {
        if let node = node as? TextNode {
            closeTag(node)
        } else if let node = node as? Element {
            closeTag(node)
        } else {
            print("Error - unreachable node reached on tag exit")
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
        let elseLine: String?
        let tagLine: String?
        let forLine: String?
        let addToSlotLine: String?
        let replaceSlotLine: String?

        static func new(from e: Element) -> ControlAttrs? {
            var ifLine: String?
            var ifElseLine: String?
            var elseLine: String?
            var tagLine: String?
            var forLine: String?
            var addToSlotLine: String?
            var replaceSlotLine: String?

            if e.hasAttr("r-if"), let v = try? e.attr("r-if"), let _ = try? e.removeAttr("r-if") {
                ifLine = v
            }

            if e.hasAttr("r-else-if"), let v = try? e.attr("r-else-if"), let _ = try? e.removeAttr("r-else-if") {
                ifElseLine = v
            }

            if e.hasAttr("r-else"), let v = try? e.attr("r-else"), let _ = try? e.removeAttr("r-else") {
                elseLine = v
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

            guard ifLine != nil || ifElseLine != nil || elseLine != nil || tagLine != nil || forLine != nil || addToSlotLine != nil || replaceSlotLine != nil else { return nil }

            return .init(ifLine: ifLine, ifElseLine: ifElseLine, elseLine: elseLine, tagLine: tagLine, forLine: forLine, addToSlotLine: addToSlotLine, replaceSlotLine: replaceSlotLine)
        }
    }
}

extension NewParser {
    func openTag(_ text: TextNode) {
        guard let branch = ast.getCurrentBranch() else { return }
        branch.appendToLastConstant(content: text.text())
    }

    func openTag(_ element: Element) {
        guard let branch = ast.getCurrentBranch() else { return }
        let tag = element.tag()
        let tagName = tag.getNameNormal()
        let attrs = try? element.getAttributes()?.html()

        let value = if tag.isSelfClosing() {
            "<\(tagName)\(attrs ?? "")/>"
        } else {
            "<\(tagName)\(attrs ?? "")>"
        }

        branch.appendToLastConstant(content: value)
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
        branch.appendToLastConstant(content: "</\(tagName)>")
    }

    func isConditional(_ attrs: ControlAttrs) -> AST? {
        switch (attrs.ifLine, attrs.ifElseLine, attrs.elseLine, attrs.tagLine) {
        case let (.some(line), _, _, tag):
            .conditional(name: tag, check: line, type: .ifType, contents: ASTStorage())
        case let (.none, .some(line), _, tag):
            .conditional(name: tag, check: line, type: .elseIfType, contents: ASTStorage())
        case let (.none, .none, .some(line), tag):
            .conditional(name: tag, check: line, type: .elseType, contents: ASTStorage())
        case (.none, .none, .none, _):
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
        openTag(element)
    }

    func openSetTag(_ element: Element) {
        openTag(element)
    }

    func openUnsetTag(_ element: Element) {
        openTag(element)
    }

    func openVarTag(_ element: Element) {
        openTag(element)
    }

    func openValueTag(_ element: Element) {
        openTag(element)
    }

    func openEvalTag(_ element: Element) {
        openTag(element)
    }

    func openSlotTag(_ element: Element) {
        openTag(element)
    }

    func openBlockTag(_ element: Element) {
        openTag(element)
    }

    func openIndexTag(_ element: Element) {
        openTag(element)
    }

    func openItemTag(_ element: Element) {
        openTag(element)
    }
}
