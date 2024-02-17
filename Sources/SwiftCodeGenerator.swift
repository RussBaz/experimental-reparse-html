public final class SwiftCodeGenerator {
    struct ParameterDef {
        let type: String
        let name: String
        let label: String?
    }

    final class SwiftPageSignatures {
        var signatures = [String: [ParameterDef]]()
    }

    var conditionTags: [String] = ["previousUnnamedIfTaken"]
    var main: [String] = []
    var includes: [String] = []
    let data: ASTStorage?
    let signatures: SwiftPageSignatures
    let currentFile: String

    init(_ name: String, for data: ASTStorage?, with signatures: SwiftPageSignatures? = nil) {
        currentFile = name
        self.data = data
        self.signatures = signatures ?? SwiftPageSignatures()
    }

    func run(at indentation: Int = 0) {
        main = []

        generateBody(at: indentation + 1)
        main.append("")
        main.append("\(indent(level: indentation + 1))return lines")
        main.append("\(indent(level: indentation))}")
        generateHeader(at: indentation)
    }

    func indent(level: Int) -> String {
        String(repeating: "    ", count: max(level, 0))
    }

    func generateHeader(at indentation: Int) {
        let signature = signatures.parameters(of: currentFile).map(\.asDeclaration).joined(separator: ", ")
        var tmp = [String]()
        
        tmp.append("\(indent(level: indentation))static func include(\(signature)) -> LineStorage {")
        tmp.append("\(indent(level: indentation + 1))let lines = LineStorage()")
        tmp.append("\(indent(level: indentation + 1))var attributes = AttributeStorage()")
        for tag in conditionTags {
            tmp.append("\(indent(level: indentation + 1))var \(tag) = false")
        }
        tmp.append("")
        
        main.insert(contentsOf: tmp, at: 0)
    }

    func generateBody(at indentation: Int) {
        guard let data else { return }

        let includeSignature = signatures.parameters(of: currentFile).map(\.asParameter).joined(separator: ", ")

        for node in data.values {
            switch node {
            case let .constant(contents):
                var tmp: [String] = []

                var buffer = ""
                for l in contents.lines {
                    if l == "\n" {
                        if !buffer.isEmpty {
                            tmp.append("\(indent(level: indentation))\(buffer)")
                            buffer = ""
                        }
                    } else {
                        buffer += l
                    }
                }
                if !buffer.isEmpty {
                    tmp.append("\(indent(level: indentation))\(buffer)")
                }
                if !tmp.isEmpty {
                    main.append("\(indent(level: indentation))lines.append(\"\"\"")
                    main.append(contentsOf: tmp)
                    main.append("\(indent(level: indentation))\"\"\")")
                }

            case let .slotDeclaration(name: name, defaults: contents):
                if contents.isEmpty {
                    main.append("\(indent(level: indentation))lines.declare(slot: \"\(name))\")")
                } else {
                    let innerGenerator = SwiftCodeGenerator(name, for: contents, with: signatures)
                    innerGenerator.generateBody(at: indentation + 1)
                    innerGenerator.copyInnerVariables(into: self)
                    main.append("\(indent(level: indentation))lines.declare(slot: \"\(name)\") { lines in")
                    main.append(contentsOf: innerGenerator.main)
                    main.append("\(indent(level: indentation))}")
                }
            case let .slotCommand(type: type, contents: contents):
                let innerGenerator = SwiftCodeGenerator(currentFile, for: contents, with: signatures)
                innerGenerator.generateBody(at: indentation + 1)
                innerGenerator.copyInnerVariables(into: self)
                switch type {
                case let .add(name: name):
                    main.append("\(indent(level: indentation))lines.add(slot: \"\(name)\") { lines in")
                    main.append(contentsOf: innerGenerator.main)
                    main.append("\(indent(level: indentation))}")
                case let .replace(name: name):
                    main.append("\(indent(level: indentation))lines.replace(slot: \"\(name)\") { lines in")
                    main.append(contentsOf: innerGenerator.main)
                    main.append("\(indent(level: indentation))}")
                }
            case let .include(name, contents):
                let name = ReparseHtml.splitFilenameIntoComponents(name)
                if !name.isEmpty {
                    let name = "Pages.\(name.joined(separator: "."))"
                    includes.append(name)
                    if contents.isEmpty {
                        main.append("\(indent(level: indentation))lines.include(\(name).include(\(includeSignature)))")
                    } else {
                        let innerGenerator = SwiftCodeGenerator(name, for: contents, with: signatures)
                        innerGenerator.generateBody(at: indentation + 1)
                        innerGenerator.copyInnerVariables(into: self)
                        main.append("\(indent(level: indentation))lines.include(\(name).include()) { lines in")
                        main.append(contentsOf: innerGenerator.main)
                        main.append("\(indent(level: indentation))}")
                    }
                }
            case let .conditional(name, check, type, contents):
                let name = name ?? "previousUnnamedIfTaken"
                if !conditionTags.contains(name) {
                    conditionTags.append(name)
                }
                let innerGenerator = SwiftCodeGenerator(currentFile, for: contents, with: signatures)
                innerGenerator.generateBody(at: indentation + 1)
                innerGenerator.copyInnerVariables(into: self)

                if !conditionTags.contains(name) {
                    conditionTags.append(name)
                }

                switch type {
                case .ifType:
                    main.append("\(indent(level: indentation))if \(check) {")
                case .elseIfType:
                    main.append("\(indent(level: indentation))if !\(name), \(check) {")
                case .elseType:
                    main.append("\(indent(level: indentation))if !\(name) {")
                }
                main.append(contentsOf: innerGenerator.main)
                main.append("\(indent(level: indentation + 1))\(name) = true")
                main.append("\(indent(level: indentation))}")
            case let .loop(forEvery, name, contents):
                let name = name ?? "previousUnnamedIfTaken"
                if !conditionTags.contains(name) {
                    conditionTags.append(name)
                }
                let innerGenerator = SwiftCodeGenerator(currentFile, for: contents, with: signatures)
                innerGenerator.generateBody(at: indentation + 1)
                innerGenerator.copyInnerVariables(into: self)
                main.append("\(indent(level: indentation))for (index, item) in \(forEvery).enumerated() {")
                main.append(contentsOf: innerGenerator.main)
                main.append("\(indent(level: indentation))}")
                main.append("\(indent(level: indentation))\(name) = if \(forEvery).isEmpty { false } else { true }")
            case let .modifiers(applying: modifiers, tag: tag):
                let attributes = (tag.attributes ?? AttributeStorage()).codeString(at: indentation)
                main.append(attributes)
                for modifier in modifiers {
                    switch modifier {
                    case let .append(name: name, value: value, condition: condition):
                        if let condition {
                            let cn = condition.name ?? "previousUnnamedIfTaken"
                            if !conditionTags.contains(cn) {
                                conditionTags.append(cn)
                            }
                            switch condition.type {
                            case .ifType:
                                main.append("\(indent(level: indentation))if \(condition.check) {")
                            case .elseIfType:
                                main.append("\(indent(level: indentation))if !\(cn), \(condition.check) {")
                            case .elseType:
                                main.append("\(indent(level: indentation))if !\(cn) {")
                            }
                            main.append("\(indent(level: indentation + 1))attributes.update(key: \"\(name)\", with: \(value.codeString), replacing: false)")
                            main.append("\(indent(level: indentation + 1))\(name) = true")
                            main.append("\(indent(level: indentation))}")
                        } else {
                            main.append("\(indent(level: indentation))attributes.update(key: \"\(name)\", with: \(value.codeString), replacing: false)")
                        }
                    case let .replace(name: name, value: value, condition: condition):
                        if let condition {
                            let cn = condition.name ?? "previousUnnamedIfTaken"
                            if !conditionTags.contains(cn) {
                                conditionTags.append(cn)
                            }
                            switch condition.type {
                            case .ifType:
                                main.append("\(indent(level: indentation))if \(condition.check) {")
                            case .elseIfType:
                                main.append("\(indent(level: indentation))if !\(cn), \(condition.check) {")
                            case .elseType:
                                main.append("\(indent(level: indentation))if !\(cn) {")
                            }
                            main.append("\(indent(level: indentation + 1))attributes.update(key: \"\(name)\", with: \(value.codeString), replacing: true)")
                            main.append("\(indent(level: indentation + 1))\(name) = true")
                            main.append("\(indent(level: indentation))}")
                        } else {
                            main.append("\(indent(level: indentation))attributes.update(key: \"\(name)\", with: \(value.codeString), replacing: true)")
                        }
                    case let .remove(name: name, condition: condition):
                        if let condition {
                            let cn = condition.name ?? "previousUnnamedIfTaken"
                            if !conditionTags.contains(cn) {
                                conditionTags.append(cn)
                            }
                            switch condition.type {
                            case .ifType:
                                main.append("\(indent(level: indentation))if \(condition.check) {")
                            case .elseIfType:
                                main.append("\(indent(level: indentation))if !\(cn), \(condition.check) {")
                            case .elseType:
                                main.append("\(indent(level: indentation))if !\(cn) {")
                            }
                            main.append("\(indent(level: indentation + 1))attributes.remove(\"\(name)\")")
                            main.append("\(indent(level: indentation + 1))\(name) = true")
                            main.append("\(indent(level: indentation))}")
                        } else {
                            main.append("\(indent(level: indentation))attributes.remove(\"\(name)\")")
                        }
                    }
                }

                let newTag = switch tag {
                case let .openingTag(name, _):
                    "\(indent(level: indentation))lines.append(\"<\(name)\\(attributes)>\")"
                case let .voidTag(name, _):
                    "\(indent(level: indentation))lines.append(\"<\(name)\\(attributes)/>\")"
                case .closingTag:
                    "\(indent(level: indentation))// Error: Impossible tag type"
                }
                main.append(newTag)
            case let .eval(line):
                main.append("\(indent(level: indentation))lines.append(\"\\(\(line.trimmingCharacters(in: .whitespacesAndNewlines)))\")")
            case let .value(of):
                main.append("\(indent(level: indentation))lines.append(\"\\(\(of))\")")
            case let .assignment(name, line):
                main.append("\(indent(level: indentation))var \(name) = \(line)")
            case .index:
                main.append("\(indent(level: indentation))lines.append(\"\\(index)\")")
            case .item:
                main.append("\(indent(level: indentation))lines.append(\"\\(item)\")")
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

    var text: String {
        main.joined(separator: "\n")
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

extension SwiftCodeGenerator.SwiftPageSignatures {
    func parameters(of name: String) -> [SwiftCodeGenerator.ParameterDef] {
        if let parameters = signatures[name] {
            parameters
        } else {
            []
        }
    }

    func append(parameter: SwiftCodeGenerator.ParameterDef, to name: String) {
        if var parameters = signatures[name] {
            parameters.append(parameter)
            signatures[name] = parameters
        } else {
            signatures[name] = [parameter]
        }
    }

    static func shared(for pages: [PageDef], with parameters: [SwiftCodeGenerator.ParameterDef]) -> SwiftCodeGenerator.SwiftPageSignatures {
        let signatures = SwiftCodeGenerator.SwiftPageSignatures()

        for page in pages {
            for parameter in parameters {
                signatures.append(parameter: parameter, to: page.name.reversed().joined(separator: "."))
            }
        }

        return signatures
    }
}
