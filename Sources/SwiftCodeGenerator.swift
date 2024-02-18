public final class SwiftCodeGenerator {
    struct ParameterDef {
        let type: String
        let name: String
        let label: String?
    }

    enum LineType {
        case text(String)
        case deferred(() -> [String])
    }

    struct LineDef {
        let indentation: Int
        let line: LineType
    }

    struct PageSignature {
        let parameters: [ParameterDef]
        let includes: [String]
    }

    final class SwiftPageSignatures {
        var signatures = [String: PageSignature]()
    }

    final class PageProperties {
        let name: String
        let fileExtension: String
        var lines: [LineDef] = []
        var conditionTags: [String] = []
        var defaultValues: [String: String] = [:]
        var modifiersPresent = false

        init(name: String, fileExtension: String) {
            self.name = name
            self.fileExtension = fileExtension
        }

        func clear() {
            lines = []
            conditionTags = []
            defaultValues = [:]
        }
    }

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
            let signature = self.signatures.parameters(of: self.properties.name).map(\.asDeclaration).joined(separator: ", ")
            return ["static func include(\(signature)) -> LineStorage {"]
        }
        properties.append(at: indentation + 1) {
            var result = [String]()
            for (assignment, value) in self.properties.defaultValues {
                result.append("var \(assignment) = \(assignment) ?? \(value)")
            }

            return result
        }
        properties.append(at: indentation + 1) {
            if self.properties.lines.isEmpty {
                []
            } else {
                ["let lines = LineStorage()"]
            }
        }
        properties.append(at: indentation + 1) {
            if self.properties.modifiersPresent {
                ["var attributes = AttributeStorage()"]
            } else {
                []
            }
        }
        properties.append(at: indentation + 1) {
            if self.properties.conditionTags.isEmpty {
                return []
            } else {
                var result: [String] = []

                for tag in self.properties.conditionTags {
                    result.append("var \(tag) = false")
                }

                result.append("")

                return result
            }
        }
    }

    func generateBody(at indentation: Int) {
        for node in data.values {
            switch node {
            case let .constant(contents):
                if !contents.isEmpty {
                    var buffer = ""
                    properties.append("lines.append(\"\"\"", at: indentation)

                    for l in contents.lines {
                        if l == "\n" {
                            if !buffer.isEmpty {
                                properties.append(buffer, at: indentation)
                            }
                            buffer = ""
                        } else {
                            buffer += l
                        }
                    }

                    if !buffer.isEmpty {
                        properties.append(buffer, at: indentation)
                    }

                    properties.append("\"\"\")", at: indentation)
                }

            case let .slotDeclaration(name: name, defaults: contents):
                if contents.isEmpty {
                    properties.append("lines.declare(slot: \"\(name))\")", at: indentation)
                } else {
                    let innerGenerator = SwiftCodeGenerator(ast: contents, signatures: signatures, page: properties)
                    properties.append("lines.declare(slot: \"\(name)\") { lines in", at: indentation)
                    innerGenerator.generateBody(at: indentation + 1)
                    properties.append("}", at: indentation)
                }
            case let .slotCommand(type: type, contents: contents):
                if contents.isEmpty {
                    switch type {
                    case let .add(name: name):
                        properties.append("lines.add(slot: \"\(name)\")", at: indentation)
                    case let .replace(name: name):
                        properties.append("lines.add(slot: \"\(name)\")", at: indentation)
                    }
                } else {
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
                }
            case let .include(name, contents):
                let name = ReparseHtml.splitFilenameIntoComponents(name, dropping: properties.fileExtension)
                if !name.isEmpty {
                    let name = "Pages.\(name.joined(separator: "."))"
                    signatures.append(include: name, to: properties.name)
                    if contents.isEmpty {
                        properties.append(at: indentation) {
                            let signature = self.signatures.parameters(of: name).map(\.asParameter).joined(separator: ", ")
                            return ["lines.include(\(name).include(\(signature)))"]
                        }
                    } else {
                        let innerGenerator = SwiftCodeGenerator(ast: contents, signatures: signatures, page: properties)

                        properties.append(at: indentation) {
                            let signature = self.signatures.parameters(of: name).map(\.asParameter).joined(separator: ", ")
                            return ["lines.include(\(name).include(\(signature))) { lines in"]
                        }
                        innerGenerator.generateBody(at: indentation + 1)
                        properties.append("}", at: indentation)
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
                    properties.append("if !\(name), \(check) {", at: indentation)
                case .elseType:
                    properties.append("if !\(name) {", at: indentation)
                }

                innerGenerator.generateBody(at: indentation + 1)

                properties.append("\(name) = true", at: indentation + 1)
                properties.append("}", at: indentation)
            case let .loop(forEvery, name, contents):
                guard !contents.isEmpty else { return }
                let name = name ?? "previousUnnamedIfTaken"
                properties.append(condition: name)
                let innerGenerator = SwiftCodeGenerator(ast: contents, signatures: signatures, page: properties)

                if let _ = properties.defaultValues[forEvery] {
                    properties.append("for (index, item) in \(forEvery).enumerated() {", at: indentation)
                    innerGenerator.generateBody(at: indentation + 1)
                    properties.append("}", at: indentation)
                } else {
                    properties.append("if let \(forEvery) {", at: indentation)
                    properties.append("for (index, item) in \(forEvery).enumerated() {", at: indentation + 1)
                    innerGenerator.generateBody(at: indentation + 2)
                    properties.append("}", at: indentation + 1)
                    properties.append("\(name) = if \(forEvery).isEmpty { false } else { true }", at: indentation + 1)
                    properties.append("} else {", at: indentation)
                    properties.append("\(name) = false", at: indentation + 1)
                    properties.append("}", at: indentation)
                }
            case let .modifiers(applying: modifiers, tag: tag):
                guard !modifiers.isEmpty else { return }
                let attributes = (tag.attributes ?? AttributeStorage()).codeString(at: indentation)
                properties.modifiersPresent = true
                properties.append("attributes = AttributeStorage.from(attributes: [\(attributes)])", at: indentation)
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
                                properties.append("if !\(cn), \(condition.check) {", at: indentation)
                            case .elseType:
                                properties.append("if !\(cn) {", at: indentation)
                            }
                            properties.append("attributes.update(key: \"\(name)\", with: \(value.codeString), replacing: false)", at: indentation + 1)
                            properties.append("\(name) = true", at: indentation + 1)
                            properties.append("}", at: indentation)
                        } else {
                            properties.append("attributes.update(key: \"\(name)\", with: \(value.codeString), replacing: false)", at: indentation)
                        }
                    case let .replace(name: name, value: value, condition: condition):
                        if let condition {
                            let cn = condition.name ?? "previousUnnamedIfTaken"
                            properties.append(condition: cn)
                            switch condition.type {
                            case .ifType:
                                properties.append("if \(condition.check) {", at: indentation)
                            case .elseIfType:
                                properties.append("if !\(cn), \(condition.check) {", at: indentation)
                            case .elseType:
                                properties.append("if !\(cn) {", at: indentation)
                            }
                            properties.append("attributes.update(key: \"\(name)\", with: \(value.codeString), replacing: true)", at: indentation + 1)
                            properties.append("\(name) = true", at: indentation + 1)
                            properties.append("}", at: indentation)
                        } else {
                            properties.append("attributes.update(key: \"\(name)\", with: \(value.codeString), replacing: true)", at: indentation)
                        }
                    case let .remove(name: name, condition: condition):
                        if let condition {
                            let cn = condition.name ?? "previousUnnamedIfTaken"
                            properties.append(condition: cn)
                            switch condition.type {
                            case .ifType:
                                properties.append("if \(condition.check) {", at: indentation)
                            case .elseIfType:
                                properties.append("if !\(cn), \(condition.check) {", at: indentation)
                            case .elseType:
                                properties.append("if !\(cn) {", at: indentation)
                            }
                            properties.append("attributes.remove(\"\(name)\")", at: indentation + 1)
                            properties.append("\(name) = true", at: indentation + 1)
                            properties.append("}", at: indentation)
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
            case let .requirement(name: name, type: type, label: label, value: value):
                signatures.append(parameter: .init(type: "\(type)?", name: name, label: label), to: properties.name)
                if let value {
                    properties.appendDefault(name: name, value: value)
                }
            case let .eval(line):
                properties.append("lines.append(\"\\(\(line.trimmingCharacters(in: .whitespacesAndNewlines)))\")", at: indentation)
            case let .value(of):
                properties.append("lines.append(\"\\(\(of))\")", at: indentation)
            case let .assignment(name, line):
                properties.append("var \(name) = \(line)", at: indentation)
            case .index:
                properties.append("lines.append(\"\\(index)\")", at: indentation)
            case .item:
                properties.append("lines.append(\"\\(item)\")", at: indentation)
            case .endOfBranch:
                ()
            }
        }
    }
}

extension SwiftCodeGenerator.ParameterDef {
    var asDeclaration: String {
        let label = if let label { "\(label) " } else { "" }
        if type.hasSuffix("?") {
            return "\(label)\(name): \(type) = nil"
        } else {
            return "\(label)\(name): \(type)"
        }
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
            parameters.parameters
        } else {
            []
        }
    }

    func append(parameter: SwiftCodeGenerator.ParameterDef, to name: String) {
        if let signature = signatures[name] {
            var newParameters = signature.parameters
            newParameters.append(parameter)
            signatures[name] = .init(parameters: newParameters, includes: signature.includes)
        } else {
            signatures[name] = .init(parameters: [parameter], includes: [])
        }
    }

    func append(include: String, to name: String) {
        if let signature = signatures[name] {
            var newIncludes = signature.includes
            newIncludes.append(include)
            signatures[name] = .init(parameters: signature.parameters, includes: newIncludes)
        } else {
            signatures[name] = .init(parameters: [], includes: [include])
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

extension SwiftCodeGenerator.PageProperties {
    func append(at indentation: Int) {
        lines.append(.init(indentation: indentation, line: .text("")))
    }

    func prepend(at indentation: Int) {
        lines.insert(.init(indentation: indentation, line: .text("")), at: 0)
    }

    func append(_ text: String, at indentation: Int) {
        lines.append(.init(indentation: indentation, line: .text(text)))
    }

    func append(at indentation: Int, deferred: @escaping () -> [String]) {
        lines.append(.init(indentation: indentation, line: .deferred(deferred)))
    }

    func prepend(_ text: String, at indentation: Int) {
        lines.insert(.init(indentation: indentation, line: .text(text)), at: 0)
    }

    func prepend(at indentation: Int, deferred: @escaping () -> [String]) {
        lines.insert(.init(indentation: indentation, line: .deferred(deferred)), at: 0)
    }

    func append(contentsOf data: [SwiftCodeGenerator.LineDef]) {
        lines.append(contentsOf: data)
    }

    func prepend(contentsOf data: [SwiftCodeGenerator.LineDef]) {
        lines.insert(contentsOf: data, at: 0)
    }

    func append(condition tag: String) {
        if !conditionTags.contains(tag) {
            conditionTags.append(tag)
        }
    }

    func appendDefault(name: String, value: String) {
        defaultValues[name] = value
    }

    func asText(at indenation: Int = 0) -> String {
        asLines(at: indenation).joined(separator: "\n")
    }

    func asLines(at indentation: Int = 0) -> [String] {
        var result = [String]()

        for l in lines {
            switch l.line {
            case let .text(string):
                result.append("\(String(repeating: "    ", count: indentation + l.indentation))\(string)")
            case let .deferred(f):
                for i in f() {
                    result.append("\(String(repeating: "    ", count: indentation + l.indentation))\(i)")
                }
            }
        }

        return result
    }
}
