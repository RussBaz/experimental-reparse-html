import Foundation
import SwiftSoup

class NewParser: NodeVisitor {
    let ast = ASTStorage()

    func head(_ node: Node, _: Int) throws {
        if let node = node as? TextNode {
            openTag(node)
        } else if let node = node as? Element {
            openTag(node)
        } else {
            print("Error - unreachable node reached on tag entry")
        }
    }

    func tail(_ node: Node, _: Int) throws {
        if let node = node as? TextNode {
            closeTag(node)
        } else if let node = node as? Element {
            closeTag(node)
        } else {
            print("Error - unreachable node reached on tag exit")
        }
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
}
