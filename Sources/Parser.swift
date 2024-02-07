import Foundation
import SwiftSoup

enum Parser {}

extension Parser {
    class ParseContext {
        var parent: ParseContext?
        var current: [AST] = []
        var postponed: [CloseTagRef] = []
        var level: Int = 1
        var lastElement: Element?

        init(parent: ParseContext? = nil, current: [AST], postponed: [CloseTagRef], level: Int, lastElement: Element? = nil) {
            self.parent = parent
            self.current = current
            self.postponed = postponed
            self.level = level
            self.lastElement = lastElement
        }

        init(parent p: ParseContext) {
            parent = p
            current = []
            postponed = []
            level = 1
            lastElement = nil
        }

        init() {}

        func appendConstant(_ value: String) {
            if let last = current.popLast() {
                switch last {
                case var .constant(contents):
                    contents.append(value)
                    current.append(.constant(contents: contents))
                default:
                    current.append(last)
                    current.append(.constant(contents: [value]))
                }
            } else {
                current.append(.constant(contents: [value]))
            }
        }

        func appendChildContext(_ context: ParseContext) {
            print("Appending")
            if let last = current.popLast() {
                switch last {
                case let .slotDeclaration(name, _):
                    current.append(.slotDeclaration(name: name, defaults: context.current))
                case let .slotCommand(type, _):
                    current.append(.slotCommand(type: type, contents: context.current))
                case let .include(name, _):
                    current.append(.include(name: name, contents: context.current))
                case let .conditional(name, check, type, _):
                    current.append(.conditional(name: name, check: check, type: type, contents: context.current))
                case let .loop(forEvery, name, _):
                    current.append(.loop(forEvery: forEvery, name: name, contents: context.current))
                default:
                    current.append(last)
                }
            } else {
                print("Append failed")
            }
        }

        func next(current element: Element, skip: Bool = false) -> (element: Element, context: ParseContext)? {
            if let node = element.children().first() {
                level += 1
                return (element: node, context: self)
            } else if level > 0, let node = try? element.nextElementSibling() {
                if !skip, let closing = postponed.popLast(), let value = closing.tag {
                    appendConstant(value)
                }
                return (element: node, context: self)
            } else {
                var e: Element? = element
                while level > 0 {
                    level -= 1
                    if let closing = postponed.popLast(), let value = closing.tag {
                        appendConstant(value)
                    }
                    guard let parent = e?.parent() else { break }
                    e = parent
                    if let next = try? e?.nextElementSibling() {
                        if let closing = postponed.popLast(), let value = closing.tag {
                            appendConstant(value)
                        }
                        return (element: next, context: self)
                    }
                }

                for i in postponed.reversed() {
                    if let value = i.tag {
                        appendConstant(value)
                    }
                }

                if let parent {
                    parent.appendChildContext(self)
                    if let last = parent.lastElement {
                        return parent.next(current: last, skip: true)
                    }
                }

                return nil
            }
        }
    }

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

        var tag: String? {
            if let value {
                "</\(value)>"
            } else {
                nil
            }
        }
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

    static func parseHtml(content: String) -> [AST]? {
        guard let doc = try? SwiftSoup.parseBodyFragment(content) else { return nil }
        guard let body = doc.body() else { return nil }
        guard let first = body.children().first() else { return nil }

        let context = ParseContext()

        parseElement(current: first, context: context)

        return context.current
    }

    static func hasContolAttrs(_ e: Element) -> ControlAttrs? {
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

    static func nextElement(current element: Element, context: ParseContext, skip: Bool = false) -> Element? {
        if !skip, let node = element.children().first() {
            context.level += 1
            return node
        } else if let node = try? element.nextElementSibling() {
            return node
        } else {
            return nil
        }
    }

    static func parseElement(current element: Element, context: ParseContext) {
        print("\nCurrent: \(String(describing: try? element.outerHtml()))")
        context.lastElement = element
        if let controlAttrs = hasContolAttrs(element) {
            let conditional = parseConditional(controlAttrs)
            let loop = parseLoop(controlAttrs)
            let slotCommand = parseSlotCommand(controlAttrs)
            if let conditional {
                context.current.append(conditional)
                let conditionalContext = ParseContext(parent: context)
                conditionalContext.level = 0
                if let loop {
                    conditionalContext.current.append(loop)
                    let loopContext = ParseContext(parent: conditionalContext)
                    loopContext.level = 0
                    parseElement(current: element, context: loopContext)
                } else if let slotCommand {
                    conditionalContext.current.append(slotCommand)
                    let slotCommandContext = ParseContext(parent: conditionalContext)
                    slotCommandContext.level = 0
                    parseElement(current: element, context: slotCommandContext)
                } else {
                    parseElement(current: element, context: conditionalContext)
                }
            } else {
                if let loop {
                    context.current.append(loop)
                    let loopContext = ParseContext(parent: context)
                    loopContext.level = 0
                    parseElement(current: element, context: loopContext)
                } else if let slotCommand {
                    context.current.append(slotCommand)
                    let slotCommandContext = ParseContext(parent: context)
                    slotCommandContext.level = 0
                    parseElement(current: element, context: slotCommandContext)
                } else {
                    // Impossible to reach
                    parseElement(current: element, context: context)
                }
            }

        } else {
            let tag = element.tag()
            let tagName = tag.getNameNormal()
            let attrs = try? element.getAttributes()?.html()
            let value: String

            if tagName == "h1" {
                ()
            }

            if tag.isSelfClosing() {
                value = "<\(tagName)\(attrs ?? "") />"
            } else {
                value = "<\(tagName)\(attrs ?? "")>"
                context.postponed.append(.init(name: tagName, value: tagName))
            }

            context.appendConstant(value)

            if element.hasText(), let first = element.textNodes().first {
                let text = first.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    context.appendConstant(text)
                }
            }

            if let (next, context) = context.next(current: element) {
                print("Next: \(String(describing: try? next.outerHtml()))")
                return parseElement(current: next, context: context)
            }

//            switch tagName {
//            case "r-include":
//                if tag.isSelfClosing() {
//
//                } else {
//
//                }
//            case "r-set":
//                if tag.isSelfClosing() {
//
//                } else {
//
//                }
//            case "r-unset":
//                if tag.isSelfClosing() {
//
//                } else {
//
//                }
//            case "r-var":
//                if tag.isSelfClosing() {
//
//                } else {
//
//                }
//            case "r-value":
//                if tag.isSelfClosing() {
//
//                } else {
//
//                }
//            case "r-eval":
//                if tag.isSelfClosing() {
//
//                } else {
//
//                }
//            case "r-slot":
//                if tag.isSelfClosing() {
//
//                } else {
//
//                }
//            case "r-block":
//                if tag.isSelfClosing() {
//
//                } else {
//
//                }
//            case "r-index":
//                if tag.isSelfClosing() {
//
//                } else {
//
//                }
//            case "r-item":
//                if tag.isSelfClosing() {
//
//                } else {
//
//                }
//            default:
//                let attrs = try? element.getAttributes()?.html()
//                let value: String
//
//                if tag.isSelfClosing() {
//                    value = "<\(tagName)\(attrs ?? "") />"
//                } else {
//                    value = "<\(tagName)\(attrs ?? "")>"
//                    context.postponed.append(.init(name: tagName, value: tagName))
//                }
//
//                context.appendConstant(value)
//
//                if let next = nextElement(current: element, context: context) {
//                    parseElement(current: next, context: context)
//                } else if let parent = context.parent {
//                    parent.appendChildContext(context)
//                }
//            }
        }
    }

    static func parseConditional(_ attrs: ControlAttrs) -> AST? {
        switch (attrs.ifLine, attrs.ifElseLine, attrs.elseLine, attrs.tagLine) {
        case let (.some(line), _, _, tag):
            .conditional(name: tag, check: line, type: .ifType, contents: [])
        case let (.none, .some(line), _, tag):
            .conditional(name: tag, check: line, type: .elseIfType, contents: [])
        case let (.none, .none, .some(line), tag):
            .conditional(name: tag, check: line, type: .elseType, contents: [])
        case (.none, .none, .none, _):
            nil
        }
    }

    static func parseLoop(_ attrs: ControlAttrs) -> AST? {
        switch (attrs.forLine, attrs.tagLine) {
        case let (.some(line), tag):
            .loop(forEvery: line, name: tag, contents: [])
        case (.none, _):
            nil
        }
    }

    static func parseSlotCommand(_ attrs: ControlAttrs) -> AST? {
        if let name = attrs.addToSlotLine {
            return .slotCommand(type: .add(name: name), contents: [])
        }

        if let name = attrs.replaceSlotLine {
            return .slotCommand(type: .replace(name: name), contents: [])
        }

        return nil
    }

    static func parse(current _: Element, context _: ParseContext) {}
}