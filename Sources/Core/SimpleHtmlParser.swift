import ReparseRuntime

public final class SimpleHtmlParser {
    struct Element {
        let depth: Int
        let content: AST.Content
    }

    enum DataState {
        case script(depth: Int)
        case style
    }

    enum State {
        case lookingForText(buffer: String)
        case lookingForTagName(name: String)
        case lookingForAttributes(tag: String, attributes: SwiftAttributeStorage)
        case lookingForAttributeName(tag: String, attributes: SwiftAttributeStorage, key: String)
        case lookineForAttributeSeparator(tag: String, attributes: SwiftAttributeStorage, key: String)
        case lookingForAttributeValueStart(tag: String, attributes: SwiftAttributeStorage, key: String)
        case lookingForAttributeValue(tag: String, attributes: SwiftAttributeStorage, key: String, value: String, wrapper: SwiftAttributeStorage.AttributeValueWrapper)
        case lookingForVoidTagEnd(tag: String, attributes: SwiftAttributeStorage)
        case lookingForClosingTagName(name: String)
        case lookingForClosingTagEnd(name: String)
    }

    let input: String
    var nodes: [Element] = []

    var currentDepth = 0
    var state: State = .lookingForText(buffer: "")

    var lastTagIndex: String.Index?
    var dataState: DataState?

    init(input: String) {
        self.input = input
    }

    func parse() {
        guard !input.isEmpty else { return }

        var index = input.startIndex

        nodes = []

        for c in input {
            parseCharacter(char: c, at: index)
            index = input.index(after: index)
        }

        switch state {
        case let .lookingForText(buffer: buffer):
            if !buffer.isEmpty {
                nodes.append(.init(depth: currentDepth, content: .text(value: buffer)))
            }
        default:
            cancelTag(till: input.index(before: index))
            if case let .lookingForText(buffer) = state {
                if !buffer.isEmpty {
                    nodes.append(.init(depth: currentDepth, content: .text(value: buffer)))
                }
            }
        }

        currentDepth = 0
        state = .lookingForText(buffer: "")
        lastTagIndex = nil
        dataState = nil
    }

    func parseCharacter(char: Character, at index: String.Index) {
        switch state {
        case let .lookingForText(buffer):
            if char == "<" {
                if !buffer.isEmpty {
                    if dataState != nil {
                        nodes.append(.init(depth: currentDepth, content: .data(value: buffer)))
                    } else {
                        nodes.append(.init(depth: currentDepth, content: .text(value: buffer)))
                    }
                }
                lastTagIndex = index
                state = .lookingForTagName(name: "")
            } else if char == "\n" {
                if !buffer.isEmpty {
                    if dataState != nil {
                        nodes.append(.init(depth: currentDepth, content: .data(value: buffer)))
                    } else {
                        nodes.append(.init(depth: currentDepth, content: .text(value: buffer)))
                    }
                }
                nodes.append(.init(depth: currentDepth, content: .newLine))
                lastTagIndex = index
                state = .lookingForText(buffer: "")
            } else {
                state = .lookingForText(buffer: buffer + String(char))
            }
        case let .lookingForTagName(name):
            if name.isEmpty, char == "/" {
                state = .lookingForClosingTagName(name: "")
            } else if name.isEmpty, char == " " || char == "\n" {
                state = .lookingForTagName(name: name)
            } else if char == "/" {
                state = .lookingForVoidTagEnd(tag: name, attributes: SwiftAttributeStorage())
            } else if !name.isEmpty, char == ">" {
                appendTag(.openingTag(name: name, attributes: SwiftAttributeStorage()), till: index)
            } else if !name.isEmpty, char == "-" || char == "." {
                state = .lookingForTagName(name: name + String(char))
            } else if isAllowedInTags(char) {
                state = .lookingForTagName(name: name + String(char))
            } else if char == " " || char == "\n", !name.isEmpty, name.last != "-", name.last != "." {
                state = .lookingForAttributes(tag: name, attributes: SwiftAttributeStorage())
            } else {
                cancelTag(till: index)
            }
        case let .lookingForAttributes(tag, attributes):
            if char == " " || char == "\n" {
                state = .lookingForAttributes(tag: tag, attributes: attributes)
            } else if char == "/" {
                state = .lookingForVoidTagEnd(tag: tag, attributes: attributes)
            } else if char == ">" {
                appendTag(.openingTag(name: tag, attributes: attributes), till: index)
            } else if !["\"", "'", "="].contains(char), !isControlCharacter(char) {
                state = .lookingForAttributeName(tag: tag, attributes: attributes, key: String(char))
            } else {
                cancelTag(till: index)
            }
        case let .lookingForAttributeName(tag, attributes, key):
            if char == " " {
                state = .lookineForAttributeSeparator(tag: tag, attributes: attributes, key: key)
            } else if char == "\n" {
                state = .lookingForAttributeName(tag: tag, attributes: attributes, key: key)
            } else if char == "=" {
                state = .lookingForAttributeValueStart(tag: tag, attributes: attributes, key: key)
            } else if char == ">" {
                attributes.append(key: key, value: "", wrapper: .none)
                state = .lookingForText(buffer: "")
                appendTag(.openingTag(name: tag, attributes: attributes), till: index)
            } else if char == "/" {
                attributes.append(key: key, value: "", wrapper: .none)
                state = .lookingForVoidTagEnd(tag: tag, attributes: attributes)
            } else if !["\"", "'"].contains(char), !isControlCharacter(char) {
                state = .lookingForAttributeName(tag: tag, attributes: attributes, key: key + String(char))
            } else {
                cancelTag(till: index)
            }
        case let .lookineForAttributeSeparator(tag, attributes, key):
            if char == " " {
                state = .lookineForAttributeSeparator(tag: tag, attributes: attributes, key: key)
            } else if char == "=" {
                state = .lookingForAttributeValueStart(tag: tag, attributes: attributes, key: key)
            } else if char == ">" {
                state = .lookingForText(buffer: "")
                attributes.append(key: key, value: "", wrapper: .none)
                appendTag(.openingTag(name: tag, attributes: attributes), till: index)
            } else if char == "/" {
                attributes.append(key: key, value: "", wrapper: .none)
                state = .lookingForVoidTagEnd(tag: tag, attributes: attributes)
            } else if char == "\n" {
                attributes.append(key: key, value: "", wrapper: .none)
                state = .lookingForAttributes(tag: tag, attributes: attributes)
            } else if !["\"", "'"].contains(char), !isControlCharacter(char) {
                attributes.append(key: key, value: "", wrapper: .none)
                state = .lookingForAttributeName(tag: tag, attributes: attributes, key: String(char))
            } else {
                cancelTag(till: index)
            }
        case let .lookingForAttributeValueStart(tag, attributes, key):
            if char == " " {
                state = .lookingForAttributeValueStart(tag: tag, attributes: attributes, key: key)
            } else if char == "\"" {
                state = .lookingForAttributeValue(tag: tag, attributes: attributes, key: key, value: "", wrapper: .double)
            } else if char == "'" {
                state = .lookingForAttributeValue(tag: tag, attributes: attributes, key: key, value: "", wrapper: .single)
            } else if !["=", "`", "<", ">"].contains(char), !isControlCharacter(char) {
                state = .lookingForAttributeValue(tag: tag, attributes: attributes, key: key, value: String(char), wrapper: .none)
            } else {
                cancelTag(till: index)
            }
        case let .lookingForAttributeValue(tag, attributes, key, value, wrapper):
            if char == " " {
                if case .none = wrapper {
                    attributes.append(key: key, value: value, wrapper: .none)
                    state = .lookingForAttributes(tag: tag, attributes: attributes)
                } else {
                    state = .lookingForAttributeValue(tag: tag, attributes: attributes, key: key, value: value + String(char), wrapper: wrapper)
                }
            } else if char == "\n", wrapper != .none {
                state = .lookingForAttributeValue(tag: tag, attributes: attributes, key: key, value: value + String(" "), wrapper: wrapper)
            } else if char == "\"" {
                switch wrapper {
                case .single:
                    state = .lookingForAttributeValue(tag: tag, attributes: attributes, key: key, value: value + String(char), wrapper: .single)
                case .double:
                    attributes.append(key: key, value: value, wrapper: .double)
                    state = .lookingForAttributes(tag: tag, attributes: attributes)
                case .none:
                    cancelTag(till: index)
                }
            } else if char == "'" {
                switch wrapper {
                case .single:
                    attributes.append(key: key, value: value, wrapper: .single)
                    state = .lookingForAttributes(tag: tag, attributes: attributes)
                case .double:
                    state = .lookingForAttributeValue(tag: tag, attributes: attributes, key: key, value: value + String(char), wrapper: .double)
                case .none:
                    cancelTag(till: index)
                }
            } else if char == ">", case .none = wrapper, !value.isEmpty {
                attributes.append(key: key, value: value, wrapper: .none)
                appendTag(.openingTag(name: tag, attributes: attributes), till: index)
            } else if char == "/", case .none = wrapper, !value.isEmpty {
                attributes.append(key: key, value: value, wrapper: .none)
                state = .lookingForVoidTagEnd(tag: tag, attributes: attributes)
            } else if !isControlCharacter(char) {
                state = .lookingForAttributeValue(tag: tag, attributes: attributes, key: key, value: value + String(char), wrapper: wrapper)
            } else {
                cancelTag(till: index)
            }
        case let .lookingForVoidTagEnd(tag, attributes):
            if char == ">" {
                appendTag(.voidTag(name: tag, attributes: attributes), till: index)
            } else {
                cancelTag(till: index)
            }
        case let .lookingForClosingTagName(name):
            if name.isEmpty, char == " " || char == "\n" {
                state = .lookingForClosingTagName(name: name)
            } else if !name.isEmpty, name.last != "-", name.last != ".", char == " " || char == "\n" {
                state = .lookingForClosingTagEnd(name: name)
            } else if !name.isEmpty, char == ">" {
                appendTag(.closingTag(name: name), till: index)
            } else if !name.isEmpty, char == "-" || char == "." {
                state = .lookingForClosingTagName(name: name + String(char))
            } else if isAllowedInTags(char) {
                state = .lookingForClosingTagName(name: name + String(char))
            } else {
                cancelTag(till: index)
            }
        case let .lookingForClosingTagEnd(name):
            if char == " " {
                state = .lookingForClosingTagEnd(name: name)
            } else if char == ">" {
                appendTag(.closingTag(name: name), till: index)
            } else {
                cancelTag(till: index)
            }
        }
    }

    func cancelTag(till index: String.Index, otherwise using: () -> String = { "<!-- Simple HTML Parser Error -->" }) {
        let buffer = if let lastTagIndex {
            String(input[lastTagIndex ... index])
        } else {
            using()
        }

        lastTagIndex = nil

        if let last = nodes.popLast() {
            if case let .text(value: value) = last.content {
                state = .lookingForText(buffer: value + buffer)
            } else {
                nodes.append(last)
                state = .lookingForText(buffer: buffer)
            }
        } else {
            state = .lookingForText(buffer: buffer)
        }
    }

    func isControlCharacter(_ char: Character, includeSpace: Bool = false) -> Bool {
        if let value = char.asciiValue {
            if includeSpace {
                if value < 33 {
                    return true
                }
            } else {
                if value < 32 {
                    return true
                }
            }
            if value == 127 {
                return true
            }
        }

        return false
    }

    func isAsciiLetter(_ char: Character) -> Bool {
        if let value = char.asciiValue {
            if value > 64, value < 91 {
                return true
            }

            if value > 96, value < 123 {
                return true
            }
        }
        return false
    }

    func isAsciiNumber(_ char: Character) -> Bool {
        if let value = char.asciiValue {
            if value > 47, value < 58 {
                return true
            }
        }
        return false
    }

    func isAllowedInTags(_ char: Character) -> Bool {
        isAsciiNumber(char) || isAsciiLetter(char)
    }

    func lastTag() -> AST.TagType? {
        nodes.last(where: { if case .tag = $0.content { true } else { false } }).flatMap { (e: Element) -> AST.TagType? in
            if case let .tag(value) = e.content {
                value
            } else {
                nil
            }
        }
    }

    func lastOpeningTagIndex() -> Int? {
        nodes.lastIndex(where: { if $0.depth < currentDepth, case let .tag(value) = $0.content, value.isOpening { true } else { false } })
    }

    func lastUnclosedTag(name: String? = nil) -> AST.TagType? {
        if let name {
            nodes.last(where: { if case let .tag(value: value) = $0.content, $0.depth < currentDepth, value.name == name, value.isOpening { true } else { false } }).flatMap { e -> AST.TagType? in
                if case let .tag(value) = e.content {
                    value
                } else {
                    nil
                }
            }
        } else {
            nodes.last(where: { if case let .tag(value: value) = $0.content, $0.depth < currentDepth, value.isOpening { true } else { false } }).flatMap { e -> AST.TagType? in
                if case let .tag(value) = e.content {
                    value
                } else {
                    nil
                }
            }
        }
    }

    func voidUnmatchedOpeningTags(for name: String) {
        if let index = lastOpeningTagIndex() {
            let item = nodes[index]
            guard case let .tag(value: .openingTag(name: lastTagName, attributes: attributes)) = item.content else { return }

            if lastTagName != name {
                nodes[index] = .init(depth: item.depth, content: .tag(value: .voidTag(name: lastTagName, attributes: attributes)))

                for i in stride(from: nodes.count - 1, through: 0, by: -1) {
                    let item = nodes[i]

                    if item.depth == currentDepth {
                        nodes[i] = .init(depth: currentDepth - 1, content: item.content)
                    } else {
                        break
                    }
                }

                currentDepth -= 1

                voidUnmatchedOpeningTags(for: name)
            }
        } else {
            currentDepth += 1
        }
    }

    func appendTag(_ tag: AST.TagType, till index: String.Index) {
        switch tag {
        case let .openingTag(name: name, _):
            switch dataState {
            case let .script(depth):
                if name == "script" {
                    state = .lookingForText(buffer: "")
                    nodes.append(.init(depth: currentDepth, content: .tag(value: tag)))
                    currentDepth += 1
                    lastTagIndex = nil
                    dataState = .script(depth: depth + 1)
                } else {
                    cancelTag(till: index)
                }
            case .style:
                cancelTag(till: index)
            case nil:
                state = .lookingForText(buffer: "")
                nodes.append(.init(depth: currentDepth, content: .tag(value: tag)))
                currentDepth += 1
                lastTagIndex = nil
                if name == "script" {
                    dataState = .script(depth: 1)
                } else if name == "style" {
                    dataState = .style
                }
            }

        case .voidTag:
            switch dataState {
            case .script:
                cancelTag(till: index)
            case .style:
                cancelTag(till: index)
            case nil:
                nodes.append(.init(depth: currentDepth, content: .tag(value: tag)))
                state = .lookingForText(buffer: "")
                // Do not change the current depth as this is the void tag
                lastTagIndex = nil
            }
        case let .closingTag(name):
            switch dataState {
            case let .script(depth):
                if name == "script" {
                    voidUnmatchedOpeningTags(for: name)
                    currentDepth -= 1
                    lastTagIndex = nil
                    nodes.append(.init(depth: currentDepth, content: .tag(value: tag)))
                    state = .lookingForText(buffer: "")

                    if depth > 1 {
                        dataState = .script(depth: depth - 1)
                    } else {
                        dataState = nil
                    }
                } else {
                    cancelTag(till: index)
                }
            case .style:
                if name == "style" {
                    voidUnmatchedOpeningTags(for: name)
                    currentDepth -= 1
                    lastTagIndex = nil
                    nodes.append(.init(depth: currentDepth, content: .tag(value: tag)))
                    state = .lookingForText(buffer: "")
                    dataState = nil
                } else {
                    cancelTag(till: index)
                }
            case nil:
                voidUnmatchedOpeningTags(for: name)
                currentDepth -= 1
                lastTagIndex = nil
                nodes.append(.init(depth: currentDepth, content: .tag(value: tag)))
                state = .lookingForText(buffer: "")
            }
        }
    }
}
