final class SimpleHtmlParser {
    struct Element {
        let depth: Int
        let content: AST.Content
    }
    
    enum AttributeValueWrapper {
        case single, double, none
    }
    
    enum State {
        case lookingForText(buffer: String)
        case lookingForTagName(name: String)
        case lookingForAttributes(tag: String, attributes: [String: String])
        case lookingForAttributeName(tag: String, attributes: [String: String], key: String)
        case lookineForAttributeSeparator(tag: String, attributes: [String: String], key: String)
        case lookingForAttributeValueStart(tag: String, attributes: [String: String], key: String)
        case lookingForAttributeValue(tag: String, attributes: [String: String], key: String, value: String, wrapper: AttributeValueWrapper)
        case lookingForVoidTagEnd(tag: String, attributes: [String: String])
        case lookingForClosingTagName(name: String)
        case lookingForClosingTagEnd(name: String)
    }
    
    let input: String
    var nodes: [Element] = []
    var currentDepth = 0
    var state: State = .lookingForText(buffer: "")
    var lastTagIndex: String.Index?
    
    init(input: String) {
        self.input = input
    }
    
    func parse() {
        guard !input.isEmpty else { return }
        
        var index = input.startIndex
        
        nodes = []
        
//        print("State: \(state), last: \(String(describing: nodes.last))")
        for c in input {
            parseCharacter(char: c, at: index)
//            print("State: \(state), last: \(String(describing: nodes.last))")
            index = input.index(after: index)
        }
        
        switch state {
        case .lookingForText(buffer: let buffer):
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
    }
    
    func parseCharacter(char: Character, at index: String.Index) {
        switch state {
        case .lookingForText(let buffer):
            if char == "<" {
                if !buffer.isEmpty {
                    nodes.append(.init(depth: currentDepth, content: .text(value: buffer)))
                }
                lastTagIndex = index
                state = .lookingForTagName(name: "")
            } else if char == "\n" {
                if !buffer.isEmpty {
                    nodes.append(.init(depth: currentDepth, content: .text(value: buffer)))
                }
                nodes.append(.init(depth: currentDepth, content: .newLine))
                lastTagIndex = index
                state = .lookingForText(buffer: "")
            } else {
                state = .lookingForText(buffer: buffer+String(char))
            }
        case .lookingForTagName(let name):
            // Closing Tag!
            if name.isEmpty && char == "/" {
                state = .lookingForClosingTagName(name: "")
            } else if isAllowedInTags(char) {
                state = .lookingForTagName(name: name+String(char))
            } else if char == " ", !name.isEmpty {
                state = .lookingForAttributes(tag: name, attributes: [:])
            } else {
                cancelTag(till: index)
            }
        case .lookingForAttributes(let tag, let attributes):
            if char == " " {
                state = .lookingForAttributes(tag: tag, attributes: attributes)
            } else if char == "/" {
                state = .lookingForVoidTagEnd(tag: tag, attributes: attributes)
            } else if char == ">" {
                state = .lookingForText(buffer: "")
                nodes.append(.init(depth: currentDepth, content: .tag(value: .openingTag(name: tag, attributes: AttributeStorage.from(attributes: attributes)))))
                currentDepth += 1
                lastTagIndex = nil
            } else if !["\"", "'", "="].contains(char), !isControlCharacter(char) {
                state = .lookingForAttributeName(tag: tag, attributes: attributes, key: String(char))
            } else {
                cancelTag(till: index)
            }
        case .lookingForAttributeName(let tag, let attributes, let key):
            if char == " " {
                state = .lookineForAttributeSeparator(tag: tag, attributes: attributes, key: key)
            } else if char == "=" {
                state = .lookingForAttributeValueStart(tag: tag, attributes: attributes, key: key)
            } else if char == ">" {
                state = .lookingForText(buffer: "")
                var newAttributes = attributes
                newAttributes[key] = ""
                nodes.append(.init(depth: currentDepth, content: .tag(value: .openingTag(name: tag, attributes: AttributeStorage.from(attributes: newAttributes)))))
                currentDepth += 1
                lastTagIndex = nil
            } else if char == "/" {
                var newAttributes = attributes
                newAttributes[key] = ""
                state = .lookingForVoidTagEnd(tag: tag, attributes: newAttributes)
            } else if !["\"", "'"].contains(char), !isControlCharacter(char) {
                state = .lookingForAttributeName(tag: tag, attributes: attributes, key: key+String(char))
            } else {
                cancelTag(till: index)
            }
        case .lookineForAttributeSeparator(let tag, let attributes, let key):
            if char == " " {
                state = .lookineForAttributeSeparator(tag: tag, attributes: attributes, key: key)
            } else if char == "=" {
                state = .lookingForAttributeValueStart(tag: tag, attributes: attributes, key: key)
            } else if char == ">" {
                state = .lookingForText(buffer: "")
                var newAttributes = attributes
                newAttributes[key] = ""
                nodes.append(.init(depth: currentDepth, content: .tag(value: .openingTag(name: tag, attributes: AttributeStorage.from(attributes: newAttributes)))))
                currentDepth += 1
                lastTagIndex = nil
            } else if char == "/" {
                var newAttributes = attributes
                newAttributes[key] = ""
                state = .lookingForVoidTagEnd(tag: tag, attributes: newAttributes)
            } else if !["\"", "'"].contains(char), !isControlCharacter(char) {
                var newAttributes = attributes
                newAttributes[key] = ""
                state = .lookingForAttributeName(tag: tag, attributes: newAttributes, key: String(char))
            } else {
                cancelTag(till: index)
            }
        case .lookingForAttributeValueStart(let tag, let attributes, let key):
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
        case .lookingForAttributeValue(let tag, let attributes, let key, let value, let wrapper):
            if char == " " {
                if case .none = wrapper {
                    cancelTag(till: index)
                } else {
                    state = .lookingForAttributeValue(tag: tag, attributes: attributes, key: key, value: value+String(char), wrapper: wrapper)
                }
            } else if char == "\"" {
                switch wrapper {
                case .single:
                    state = .lookingForAttributeValue(tag: tag, attributes: attributes, key: key, value: value+String(char), wrapper: wrapper)
                case .double:
                    var newAttributes = attributes
                    newAttributes[key] = value
                    state = .lookingForAttributes(tag: tag, attributes: newAttributes)
                case .none:
                    cancelTag(till: index)
                }
            } else if char == "'" {
                switch wrapper {
                case .single:
                    var newAttributes = attributes
                    newAttributes[key] = value
                    state = .lookingForAttributes(tag: tag, attributes: newAttributes)
                case .double:
                    state = .lookingForAttributeValue(tag: tag, attributes: attributes, key: key, value: value+String(char), wrapper: wrapper)
                case .none:
                    cancelTag(till: index)
                }
            } else if !isControlCharacter(char) {
                state = .lookingForAttributeValue(tag: tag, attributes: attributes, key: key, value: value+String(char), wrapper: wrapper)
            } else {
                cancelTag(till: index)
            }
        case .lookingForVoidTagEnd(let tag, let attributes):
            if char == ">" {
                nodes.append(.init(depth: currentDepth, content: .tag(value: .selfClosingTag(name: tag, attributes: AttributeStorage.from(attributes: attributes)))))
                state = .lookingForText(buffer: "")
                // Do not change the current depth as this is the void tag
                lastTagIndex = nil
            } else {
                cancelTag(till: index)
            }
        case .lookingForClosingTagName(let name):
            if char == " ", !name.isEmpty {
                state = .lookingForClosingTagEnd(name: name)
            } else if char == ">", !name.isEmpty {
                nodes.append(.init(depth: currentDepth, content: .tag(value: .closingTag(name: name))))
                state = .lookingForText(buffer: "")
                currentDepth -= 1
                lastTagIndex = nil
            } else if isAllowedInTags(char) {
                state = .lookingForTagName(name: name+String(char))
            } else {
                cancelTag(till: index)
            }
        case .lookingForClosingTagEnd(let name):
            if char == " " {
                state = .lookingForClosingTagEnd(name: name)
            } else if char == ">" {
                nodes.append(.init(depth: currentDepth, content: .tag(value: .closingTag(name: name))))
                state = .lookingForText(buffer: "")
                currentDepth -= 1
                lastTagIndex = nil
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
                state = .lookingForText(buffer: value+buffer)
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
            if value > 64 && value < 91 {
                return true
            }
            
            if value > 96 && value < 123 {
                return true
            }
        }
        return false
    }
    
    func isAsciiNumber(_ char: Character) -> Bool {
        if let value = char.asciiValue {
            if value > 47 && value < 58 {
                return true
            }
        }
        return false
    }
    
    func isAllowedInTags(_ char: Character) -> Bool {
        isAsciiNumber(char) || isAsciiLetter(char) || char == "-"
    }
}
