public final class SwiftCodeGenerator: CodeGenerator {
    struct ParameterDef {
        let type: String
        let name: String
        let label: String?
    }

    var parameters: [ParameterDef] = []
    var conditionTags: [String] = ["previousUnnamedIfTaken"]
    var main: [String] = []
    var includes: [String] = []
    var data: ASTStorage?

    public func load(from storage: ASTStorage) {
        data = storage
    }
    
    func generateHeader(at indentation: Int) {
        let signature = parameters.map({ $0.asDeclaration }).joined(separator: ", ")
        main.append("\(String(repeating: "    ", count: indentation))func include(\(signature)) -> LineStorage {")
        main.append("\(String(repeating: "    ", count: indentation+1))let lines = LineStorage()")
        main.append("")
        
    }
    
    public func generateText(at indentation: Int) -> String {
        generateHeader(at: indentation)
        generateBody(at: indentation+1)
        main.append("")
        main.append("\(String(repeating: "    ", count: indentation+1))return lines")
        main.append("\(String(repeating: "    ", count: indentation))}")

        return main.joined(separator: "\n")
    }

    func generateBody(at indentation: Int) {
        guard let data else { return }
        
        let includeSignature = parameters.map({ $0.asParameter }).joined(separator: ", ")

        for node in data.values {
            switch node {
            case let .constant(contents):
                var tmp: [String] = []

                var buffer = ""
                for l in contents.lines {
                    if l == "\n" {
                        if !buffer.isEmpty {
                            tmp.append("\(String(repeating: "    ", count: indentation))\(buffer)")
                            buffer = ""
                        }
                    } else {
                        buffer += l
                    }
                }
                if !buffer.isEmpty {
                    tmp.append("\(String(repeating: "    ", count: indentation))\(buffer)")
                }
                if !tmp.isEmpty {
                    main.append("\(String(repeating: "    ", count: indentation))lines.append(\"\"\"")
                    main.append(contentsOf: tmp)
                    main.append("\(String(repeating: "    ", count: indentation))\"\"\")")
                }

            case let .slotDeclaration(name: name, defaults: contents):
                if contents.isEmpty {
                    main.append("\(String(repeating: "    ", count: indentation))lines.declare(slot: \"\(name))\"")
                } else {
                    let innerGenerator = SwiftCodeGenerator()
                    innerGenerator.load(from: contents)
                    let lines = innerGenerator.generateText(at: indentation + 1)
                    innerGenerator.copyInnerVariables(into: self)
                    main.append("\(String(repeating: "    ", count: indentation))lines.declare(slot: \"\(name)\") {")
                    main.append(lines)
                    main.append("\(String(repeating: "    ", count: indentation))}")
                }
            case let .slotCommand(type: type, contents: contents):
                let innerGenerator = SwiftCodeGenerator()
                innerGenerator.load(from: contents)
                let lines = innerGenerator.generateText(at: indentation + 1)
                innerGenerator.copyInnerVariables(into: self)
                switch type {
                case let .add(name: name):
                    main.append("\(String(repeating: "    ", count: indentation))lines.add(slot: \"\(name)\") { lines in")
                    main.append(lines)
                    main.append("\(String(repeating: "    ", count: indentation))}")
                case let .replace(name: name):
                    main.append("\(String(repeating: "    ", count: indentation))lines.replace(slot: \"\(name)\") { lines in")
                    main.append(lines)
                    main.append("\(String(repeating: "    ", count: indentation))}")
                }
            case let .include(name, contents):
                let name = ReparseHtml.splitFilenameIntoComponents(name)
                if !name.isEmpty {
                    let name = "Pages.\(name.joined(separator: "."))"
                    includes.append(name)
                    if contents.isEmpty {
                        main.append("\(String(repeating: "    ", count: indentation))lines.include(\(name).include(\(includeSignature)))")
                    } else {
                        let innerGenerator = SwiftCodeGenerator()
                        innerGenerator.load(from: contents)
                        let lines = innerGenerator.generateText(at: indentation + 1)
                        innerGenerator.copyInnerVariables(into: self)
                        main.append("\(String(repeating: "    ", count: indentation))lines.include(\(name).include()) { lines in")
                        main.append(lines)
                        main.append("\(String(repeating: "    ", count: indentation))}")
                    }
                }
            case let .conditional(name, check, type, contents):
                let name = name ?? "previousUnnamedIfTaken"
                let innerGenerator = SwiftCodeGenerator()
                innerGenerator.load(from: contents)
                let lines = innerGenerator.generateText(at: indentation + 1)
                innerGenerator.copyInnerVariables(into: self)

                if !conditionTags.contains(name) {
                    conditionTags.append(name)
                }

                switch type {
                case .ifType:
                    main.append("\(String(repeating: "    ", count: indentation))if \(check) {")
                case .elseIfType:
                    main.append("\(String(repeating: "    ", count: indentation))if !\(name), \(check) {")
                case .elseType:
                    main.append("\(String(repeating: "    ", count: indentation))if !\(name) {")
                }
                main.append(lines)
                main.append("\(String(repeating: "    ", count: indentation + 1))\(name) = true")
                main.append("\(String(repeating: "    ", count: indentation))}")
            case let .loop(forEvery, name, contents):
                let name = name ?? "previousUnnamedIfTaken"
                let innerGenerator = SwiftCodeGenerator()
                innerGenerator.load(from: contents)
                let lines = innerGenerator.generateText(at: indentation + 1)
                innerGenerator.copyInnerVariables(into: self)
                main.append("\(String(repeating: "    ", count: indentation))for (index, item) in \(forEvery).enumerated() {")
                main.append(lines)
                main.append("\(String(repeating: "    ", count: indentation))}")
                main.append("\(String(repeating: "    ", count: indentation))\(name) = if \(forEvery).isEmpty { false } else { true }")
            case let .modifiers(applying: modifiers, tag: tag):
                let attributes = (tag.attributes ?? AttributeStorage()).codeString(at: indentation)
                main.append(attributes)
                for modifier in modifiers {
                    switch modifier {
                    case let .append(name: name, value: value, condition: condition):
                        if let condition {
                            let cn = condition.name ?? "previousUnnamedIfTaken"
                            switch condition.type {
                            case .ifType:
                                main.append("\(String(repeating: "    ", count: indentation))if \(condition.check) {")
                            case .elseIfType:
                                main.append("\(String(repeating: "    ", count: indentation))if !\(cn), \(condition.check) {")
                            case .elseType:
                                main.append("\(String(repeating: "    ", count: indentation))if !\(cn) {")
                            }
                            main.append("\(String(repeating: "    ", count: indentation + 1))attributes.update(key: \"\(name)\", with: \(value.codeString), replacing: false)")
                            main.append("\(String(repeating: "    ", count: indentation + 1))\(name) = true")
                            main.append("\(String(repeating: "    ", count: indentation))}")
                        } else {
                            main.append("\(String(repeating: "    ", count: indentation))attributes.update(key: \"\(name)\", with: \(value.codeString), replacing: false)")
                        }
                    case let .replace(name: name, value: value, condition: condition):
                        if let condition {
                            let cn = condition.name ?? "previousUnnamedIfTaken"
                            switch condition.type {
                            case .ifType:
                                main.append("\(String(repeating: "    ", count: indentation))if \(condition.check) {")
                            case .elseIfType:
                                main.append("\(String(repeating: "    ", count: indentation))if !\(cn), \(condition.check) {")
                            case .elseType:
                                main.append("\(String(repeating: "    ", count: indentation))if !\(cn) {")
                            }
                            main.append("\(String(repeating: "    ", count: indentation + 1))attributes.update(key: \"\(name)\", with: \(value.codeString), replacing: true)")
                            main.append("\(String(repeating: "    ", count: indentation + 1))\(name) = true")
                            main.append("\(String(repeating: "    ", count: indentation))}")
                        } else {
                            main.append("\(String(repeating: "    ", count: indentation))attributes.update(key: \"\(name)\", with: \(value.codeString), replacing: true)")
                        }
                    case let .remove(name: name, condition: condition):
                        if let condition {
                            let cn = condition.name ?? "previousUnnamedIfTaken"
                            switch condition.type {
                            case .ifType:
                                main.append("\(String(repeating: "    ", count: indentation))if \(condition.check) {")
                            case .elseIfType:
                                main.append("\(String(repeating: "    ", count: indentation))if !\(cn), \(condition.check) {")
                            case .elseType:
                                main.append("\(String(repeating: "    ", count: indentation))if !\(cn) {")
                            }
                            main.append("\(String(repeating: "    ", count: indentation + 1))attributes.remove(\"\(name)\")")
                            main.append("\(String(repeating: "    ", count: indentation + 1))\(name) = true")
                            main.append("\(String(repeating: "    ", count: indentation))}")
                        } else {
                            main.append("\(String(repeating: "    ", count: indentation))attributes.remove(\"\(name)\")")
                        }
                    }
                }

                let newTag = switch tag {
                case let .openingTag(name, _):
                    "\(String(repeating: "    ", count: indentation))lines.append(\"<\(name)\\(attributes)>\")"
                case let .voidTag(name, _):
                    "\(String(repeating: "    ", count: indentation))lines.append(\"<\(name)\\(attributes)/>\")"
                case .closingTag:
                    "\(String(repeating: "    ", count: indentation))// Error: Impossible tag type"
                }
                main.append(newTag)
            case let .eval(line):
                main.append("\(String(repeating: "    ", count: indentation))lines.append(\"\\(\(line.trimmingCharacters(in: .whitespacesAndNewlines)))\")")
            case let .value(of):
                main.append("\(String(repeating: "    ", count: indentation))lines.append(\"\\(\(of))\")")
            case let .assignment(name, line):
                main.append("\(String(repeating: "    ", count: indentation))var \(name) = \(line)")
            case .index:
                main.append("\(String(repeating: "    ", count: indentation))lines.append(\"\\(index)\")")
            case .item:
                main.append("\(String(repeating: "    ", count: indentation))lines.append(\"\\(item)\")")
            case .endOfBranch:
                ()
            }
        }
    }

    func copyInnerVariables(into generator: SwiftCodeGenerator) {
        for i in includes {
            if !generator.includes.contains(i) {
                generator.includes.append(i)
            }
        }
    }
}

extension SwiftCodeGenerator.ParameterDef {
    var asDeclaration: String {
        let label = if let label { "\(label) " } else { "" }
        return "\(label)\(name): \(type)"
    }
    
    var asParameter: String {
        if let label {
            "\(label): \(name)"
        } else {
            "\(name): \(name)"
        }
    }
}
