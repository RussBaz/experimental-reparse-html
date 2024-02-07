import Foundation
import SwiftSoup

enum Parser {}

extension Parser {
    enum NodeRef {
        case open(OpenTagRef)
        case selfclose(SelfCloseTagRef)
        case close(CloseTagRef)
        case content(ContentRef)
    }

    struct OpenTagRef {
        let name: String
        let value: String
        let attributes: String?
    }

    struct SelfCloseTagRef {
        let name: String
        let value: String
        let attributes: String?
        let tryNext: Bool
    }

    struct CloseTagRef {
        let name: String
        let value: String?
    }

    struct ContentRef {
        let value: String
        let data: Bool
    }

    enum ControlRef {
        case include
        case set
        case unset
        case variable
        case value
        case eval
        case slot
        case block
        case index
        case item
    }

    struct ControlAttrs {
        let ifLine: String?
        let ifElseLine: String?
        let elseLine: String?
        let tagLine: String?
        let forLine: String?
        let addToSlotLine: String?
        let replaceSlotLine: String?
    }

    static func parseHtml(content: String) -> String {
        guard let doc = try? SwiftSoup.parseBodyFragment(content) else { return content }
        guard let body = doc.body() else { return content }
        guard let text = try? doc.text() else { return content }

        var tags: [NodeRef] = []
        var postponedTags: [CloseTagRef] = []

        guard parseDown(current: body, tags: &tags, postponed: &postponedTags) else {
            return content
        }

        if let c = doc.body()?.children().array() {
            for e in c {
                print("Tag: \(e.tagName()) - \(isControlTag(e)).")
                print("Contents: \(String(describing: try? e.html()))")
                if let attrs = e.getAttributes() {
                    print("Attrs: \(String(describing: try? attrs.html()))")
                }

                let children = e.children().array()
                if let first = children.first {
                    print("Child tag: \(first.tagName())")
                    print("Child contents: \(String(describing: try? first.html()))")
                    print("Outer contents: \(String(describing: try? first.outerHtml()))")
                    print("Inner Tag: \(first.tag().getNameNormal())")
                }
            }
        }

        return text
    }

    static func parseElement(current element: Element, tags _: inout [NodeRef], postponed _: inout [CloseTagRef]) {
        let tag = element.tag()
    }

    static func parseDown(current element: Element, tags: inout [NodeRef], postponed: inout [CloseTagRef]) -> Bool {
        guard let node = element.children().first() else { return false }

        // Process node

        // next step

        if !parseDown(current: node, tags: &tags, postponed: &postponed) {
            parseSibling(current: node, tags: &tags, postponed: &postponed)
        }

        return true
    }

    @discardableResult
    static func parseSibling(current element: Element, tags: inout [NodeRef], postponed: inout [CloseTagRef]) -> Bool {
        guard let node = try? element.nextElementSibling() else { return false }

        // Process node

        // next step

        if !parseDown(current: node, tags: &tags, postponed: &postponed) {
            if !parseSibling(current: node, tags: &tags, postponed: &postponed) {
                parseUp(current: node, tags: &tags, postponed: &postponed)
            }
        }

        return true
    }

    static func parseUp(current element: Element, tags: inout [NodeRef], postponed: inout [CloseTagRef]) {
        guard let tag = postponed.popLast() else { return }

        if let _ = tag.value {
            tags.append(.close(tag))
        }

        guard let node = element.parent() else { return }

        parseSibling(current: node, tags: &tags, postponed: &postponed)
    }

    static func isControlTag(_ e: Element) -> Bool {
        let name = e.tagNameNormal()

        let controlTags = [
            "r-include",
            "r-set",
            "r-unset",
            "r-var",
            "r-value",
            "r-eval",
            "r-slot",
            "r-block",
            "r-index",
            "r-item",
        ]

        return controlTags.contains(name)
    }

    static func hasContolAttrs(_ e: Element) -> ControlAttrs? {
        var ifLine: String?
        var ifElseLine: String?
        var elseLine: String?
        var tagLine: String?
        var forLine: String?
        var addToSlotLine: String?
        var replaceSlotLine: String?

        if let v = try? e.attr("r-if"), let _ = try? e.removeAttr("r-if") {
            ifLine = v
        }

        if let v = try? e.attr("r-else-if"), let _ = try? e.removeAttr("r-else-if") {
            ifElseLine = v
        }

        if let v = try? e.attr("r-else"), let _ = try? e.removeAttr("r-else") {
            elseLine = v
        }

        if let v = try? e.attr("r-tag"), let _ = try? e.removeAttr("r-tag") {
            tagLine = v
        }

        if let v = try? e.attr("r-for-every"), let _ = try? e.removeAttr("r-for-every") {
            forLine = v
        }

        if let v = try? e.attr("r-add-to-slot"), let _ = try? e.removeAttr("r-add-to-slot") {
            addToSlotLine = v
        }

        if let v = try? e.attr("r-replace-slot"), let _ = try? e.removeAttr("r-replace-slot") {
            replaceSlotLine = v
        }

        guard ifLine != nil || ifElseLine != nil || elseLine != nil || tagLine != nil || forLine != nil || addToSlotLine != nil || replaceSlotLine != nil else { return nil }

        return .init(ifLine: ifLine, ifElseLine: ifElseLine, elseLine: elseLine, tagLine: tagLine, forLine: forLine, addToSlotLine: addToSlotLine, replaceSlotLine: replaceSlotLine)
    }

    static func wrapInBlock(_ element: Element, tags _: inout [NodeRef], postponed _: inout [CloseTagRef]) {
        if let controlAttr = hasContolAttrs(element) {}

        if isControlTag(element) {}
    }
}
