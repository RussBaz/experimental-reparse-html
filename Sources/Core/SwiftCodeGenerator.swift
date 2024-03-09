import ReparseRuntime

public final class SwiftCodeGenerator {
    let data: ASTStorage
    let signatures: SwiftPageSignatures
    let properties: PageProperties

    init(ast: ASTStorage, signatures globalSignatures: SwiftPageSignatures, page pageProperties: PageProperties) {
        data = ast
        signatures = globalSignatures
        properties = pageProperties
    }

    func run(at indentation: Int = 0) {
        properties.clear()

        generateHeader(at: indentation)
        generateBody(at: indentation + 1)
        properties.append(at: 0)
        properties.append("return lines", at: indentation + 1)
        properties.append("}", at: indentation)
    }

    func indent(level: Int) -> String {
        String(repeating: "    ", count: max(level, 0))
    }

    func generateHeader(at indentation: Int) {
        properties.append(at: indentation) {
            let signature = self.signatures.declaration(of: self.properties.name)
            return ["static func include(\(signature)) -> SwiftLineStorage {"]
        }
        properties.append(at: indentation + 1) {
            var result = [String]()
            for value in self.properties.mutableParameters {
                result.append("var \(value) = \(value)")
            }
            for (assignment, value) in self.properties.defaultValues {
                result.append("let \(assignment) = \(assignment) ?? \(value)")
            }

            return result
        }
        properties.append(at: indentation + 1) {
            if self.properties.lines.isEmpty {
                []
            } else {
                ["let lines = SwiftLineStorage()"]
            }
        }
        properties.append(at: indentation + 1) {
            if self.properties.modifiersPresent {
                ["var attributes: SwiftAttributeStorage"]
            } else {
                []
            }
        }
        properties.append(at: indentation + 1) {
            guard !self.properties.conditionTags.isEmpty else { return [] }

            var result: [String] = []

            for tag in self.properties.conditionTags {
                if tag.read {
                    result.append("var \(tag.name) = false")
                }
            }

            guard !result.isEmpty else { return [] }

            result.append("")

            return result
        }
    }

    func generateBody(at indentation: Int) {
        for node in data.values {
            addLines(for: node, at: indentation)
        }
    }

    func addLines(for node: AST, at indentation: Int) {
        switch node {
        case let .constant(contents):
            guard !contents.isEmpty else { return }
            var buffer = ""
            properties.append("lines.append(\"\"\"", at: indentation)

            for l in contents.lines {
                if l == "\n" {
                    properties.append(buffer, at: indentation)
                    buffer = ""
                } else {
                    buffer += l
                }
            }

            if !buffer.isEmpty {
                properties.append(buffer, at: indentation)
            }

            properties.append("\"\"\")", at: indentation)

        case let .slotDeclaration(name: name, defaults: contents):
            if contents.isEmpty {
                properties.append("lines.declare(slot: \"\(name)\")", at: indentation)
            } else {
                let innerGenerator = SwiftCodeGenerator(ast: contents, signatures: signatures, page: properties)
                properties.append("lines.declare(slot: \"\(name)\") { lines in", at: indentation)
                innerGenerator.generateBody(at: indentation + 1)
                properties.append("}", at: indentation)
            }
        case let .slotCommand(type: type, contents: contents):
            guard !contents.isEmpty else { return }

            let innerGenerator = SwiftCodeGenerator(ast: contents, signatures: signatures, page: properties)
            switch type {
            case let .add(name: name):
                properties.append("lines.add(slot: \"\(name)\") { lines in", at: indentation)
                innerGenerator.generateBody(at: indentation + 1)
                properties.append("}", at: indentation)
            case let .replace(name: name):
                properties.append("lines.replace(slot: \"\(name)\") { lines in", at: indentation)
                innerGenerator.generateBody(at: indentation + 1)
                properties.append("}", at: indentation)
            }
        case let .include(name, contents):
            let name = splitFilenameIntoComponents(name, dropping: properties.fileExtension)
            if !name.isEmpty {
                let name = name.joined(separator: ".")
                signatures.append(include: name, to: properties.name)
                if contents.isEmpty {
                    properties.append(at: indentation) {
                        let signature = self.signatures.parameters(of: name, in: self.properties.name)
                        return ["lines.include(\(self.properties.enumName).\(name).include(\(signature)))"]
                    }
                } else {
                    let innerGenerator = SwiftCodeGenerator(ast: contents, signatures: signatures, page: properties)

                    properties.append(at: indentation) {
                        let signature = self.signatures.parameters(of: name, in: self.properties.name)
                        return ["lines.include(\(self.properties.enumName).\(name).include(\(signature))) { lines in"]
                    }
                    innerGenerator.generateBody(at: indentation + 1)
                    properties.append("}", at: indentation)
                }
            }
        case let .extend(name, condition):
            guard !name.isEmpty else { return }

            if let condition {
                let name = splitFilenameIntoComponents(name, dropping: properties.fileExtension)
                    .joined(separator: ".")

                signatures.append(include: name, to: properties.name)

                let cn = condition.name ?? "previousUnnamedIfTaken"
                properties.append(condition: cn)

                switch condition.type {
                case .ifType:
                    properties.append("if \(condition.check) {", at: indentation)
                case .elseIfType:
                    properties.markAsRead(condition: cn)
                    properties.append("if !\(cn), \(condition.check) {", at: indentation)
                case .elseType:
                    properties.markAsRead(condition: cn)
                    properties.append("if !\(cn) {", at: indentation)
                }

                properties.append(at: indentation + 1) {
                    guard self.properties.isRead(condition: cn) else { return [] }

                    return ["\(cn) = true"]
                }

                properties.append(at: indentation + 1) {
                    let signature = self.signatures.parameters(of: name, in: self.properties.name)
                    return ["lines.extend(\(self.properties.enumName).\(name).include(\(signature)))"]
                }

                properties.append("}", at: indentation)
            } else {
                let name = splitFilenameIntoComponents(name, dropping: properties.fileExtension)
                    .joined(separator: ".")

                signatures.append(include: name, to: properties.name)

                properties.append(at: indentation) {
                    let signature = self.signatures.parameters(of: name, in: self.properties.name)

                    return ["lines.extend(\(self.properties.enumName).\(name).include(\(signature)))"]
                }
            }
        case let .conditional(name, check, type, contents):
            guard !contents.isEmpty else { return }
            let name = name ?? "previousUnnamedIfTaken"
            properties.append(condition: name)

            let innerGenerator = SwiftCodeGenerator(ast: contents, signatures: signatures, page: properties)

            switch type {
            case .ifType:
                properties.append("if \(check) {", at: indentation)
            case .elseIfType:
                properties.markAsRead(condition: name)
                properties.append("if !\(name), \(check) {", at: indentation)
            case .elseType:
                properties.markAsRead(condition: name)
                properties.append("if !\(name) {", at: indentation)
            }

            innerGenerator.generateBody(at: indentation + 1)

            properties.append(at: indentation) {
                guard self.properties.isRead(condition: name) else { return ["}"] }
                guard type != .elseType else { return ["    \(name) = true", "}"] }

                return [
                    "    \(name) = true",
                    "} else {",
                    "    \(name) = false",
                    "}",
                ]
            }
        case let .loop(forEvery, name, contents):
            guard !contents.isEmpty else { return }

            let name = name ?? "previousUnnamedIfTaken"
            properties.append(condition: name)
            let innerGenerator = SwiftCodeGenerator(ast: contents, signatures: signatures, page: properties)

            properties.append(at: indentation) {
                guard self.properties.isRead(condition: name) else { return [] }

                return ["if \(forEvery).isEmpty { \(name) = false }"]
            }
            properties.append("for (index, item) in \(forEvery).enumerated() {", at: indentation)
            innerGenerator.generateBody(at: indentation + 1)
            properties.append(at: indentation + 1) {
                guard self.properties.isRead(condition: name) else { return [] }

                return ["\(name) = true"]
            }
            properties.append("}", at: indentation)
        case let .modifiers(applying: modifiers, tag: tag):
            guard !modifiers.isEmpty else { return }
            let attributes = (tag.attributes ?? SwiftAttributeStorage()).codeString
            properties.modifiersPresent = true
            properties.append("attributes = SwiftAttributeStorage.from(attributes: [\(attributes)])", at: indentation)
            for modifier in modifiers {
                switch modifier {
                case let .append(name: name, value: value, condition: condition):
                    if let condition {
                        let cn = condition.name ?? "previousUnnamedIfTaken"
                        properties.append(condition: cn)
                        switch condition.type {
                        case .ifType:
                            properties.append("if \(condition.check) {", at: indentation)
                        case .elseIfType:
                            properties.markAsRead(condition: cn)
                            properties.append("if !\(cn), \(condition.check) {", at: indentation)
                        case .elseType:
                            properties.markAsRead(condition: cn)
                            properties.append("if !\(cn) {", at: indentation)
                        }
                        properties.append("attributes.append(to: \"\(name)\", value: \(value.codeString))", at: indentation + 1)
                        properties.append(at: indentation) {
                            guard self.properties.isRead(condition: cn) else { return ["}"] }
                            guard condition.type != .elseType else { return ["    \(cn) = true", "}"] }

                            return [
                                "    \(cn) = true",
                                "} else {",
                                "    \(cn) = false",
                                "}",
                            ]
                        }
                    } else {
                        properties.append("attributes.append(to: \"\(name)\", value: \(value.codeString))", at: indentation)
                    }
                case let .replace(name: name, value: value, condition: condition):
                    if let condition {
                        let cn = condition.name ?? "previousUnnamedIfTaken"
                        properties.append(condition: cn)
                        switch condition.type {
                        case .ifType:
                            properties.append("if \(condition.check) {", at: indentation)
                        case .elseIfType:
                            properties.markAsRead(condition: cn)
                            properties.append("if !\(cn), \(condition.check) {", at: indentation)
                        case .elseType:
                            properties.markAsRead(condition: cn)
                            properties.append("if !\(cn) {", at: indentation)
                        }
                        properties.append("attributes.replace(key: \"\(name)\", with: \(value.codeString))", at: indentation + 1)
                        properties.append(at: indentation) {
                            guard self.properties.isRead(condition: cn) else { return ["}"] }
                            guard condition.type != .elseType else { return ["    \(cn) = true", "}"] }

                            return [
                                "    \(cn) = true",
                                "} else {",
                                "    \(cn) = false",
                                "}",
                            ]
                        }
                    } else {
                        properties.append("attributes.replace(key: \"\(name)\", with: \(value.codeString))", at: indentation)
                    }
                case let .remove(name: name, condition: condition):
                    if let condition {
                        let cn = condition.name ?? "previousUnnamedIfTaken"
                        properties.append(condition: cn)
                        switch condition.type {
                        case .ifType:
                            properties.append("if \(condition.check) {", at: indentation)
                        case .elseIfType:
                            properties.markAsRead(condition: cn)
                            properties.append("if !\(cn), \(condition.check) {", at: indentation)
                        case .elseType:
                            properties.markAsRead(condition: cn)
                            properties.append("if !\(cn) {", at: indentation)
                        }
                        properties.append("attributes.remove(\"\(name)\")", at: indentation + 1)
                        properties.append(at: indentation) {
                            guard self.properties.isRead(condition: cn) else { return ["}"] }
                            guard condition.type != .elseType else { return ["    \(cn) = true", "}"] }

                            return [
                                "    \(cn) = true",
                                "} else {",
                                "    \(cn) = false",
                                "}",
                            ]
                        }
                    } else {
                        properties.append("attributes.remove(\"\(name)\")", at: indentation)
                    }
                }
            }

            switch tag {
            case let .openingTag(name, _):
                properties.append("lines.append(\"<\(name)\\(attributes)>\")", at: indentation)
            case let .voidTag(name, _):
                properties.append("lines.append(\"<\(name)\\(attributes)/>\")", at: indentation)
            case .closingTag:
                properties.append("// Error: Impossible tag type", at: indentation)
            }
        case let .requirement(name, type, label, value, mutable):
            signatures.append(parameter: .init(type: type, name: name, label: label, defaultValue: value, canBeOverriden: false), to: properties.name)

            if mutable {
                properties.appendMutable(name: name)
            }
        case let .eval(line):
            properties.append("lines.append(\"\\(\(line.trimmingCharacters(in: .whitespacesAndNewlines)))\")", at: indentation)
        case let .value(of: name, defaultValue):
            properties.append(at: indentation) {
                if let _ = self.properties.defaultValues[name] {
                    ["lines.append(\"\\(\(name))\")"]
                } else if self.properties.markAsRead(condition: name) {
                    ["lines.append(\"\\(\(name))\")"]
                } else if let defaultValue {
                    ["lines.append(\"\\(\(name) ?? \"\(defaultValue)\")\")"]
                } else {
                    ["lines.append(\"\\(\(name))\")"]
                }
            }
        case let .assignment(name, line):
            properties.append("let \(name) = \(line)", at: indentation)
        case .index:
            properties.append("lines.append(\"\\(index)\")", at: indentation)
        case .item:
            properties.append("lines.append(\"\\(item)\")", at: indentation)
        case .endOfBranch:
            ()
        case .noop:
            ()
        }
    }
}
