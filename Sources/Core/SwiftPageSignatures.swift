public final class SwiftPageSignatures {
    public struct ParameterDef {
        let type: String
        let name: String
        let label: String?
        let defaultValue: String?
        let canBeOverriden: Bool
        let localOnly: Bool
    }

    public struct PageSignature {
        let parameters: [ParameterDef]
        let required: [ParameterDef]
        let includes: [String]
    }

    var signatures = [String: PageSignature]()
    private var resolved: [String: [ParameterDef]] = [:]

    func parameters(of name: String) -> [ParameterDef] {
        if let parameters = resolved[name] {
            parameters
        } else if let parameters = signatures[name] {
            parameters.parameters
        } else {
            []
        }
    }

    func declaration(of name: String) -> String {
        parameters(of: name).map(\.asDeclaration).joined(separator: ", ")
    }

    func isLocal(with name: String) -> Bool {
        parameters(of: name).contains { $0.localOnly }
    }

    func parameters(of name: String, in template: String, override arguments: [AST.ArgumentOverride] = []) -> String {
        let innerParams = parameters(of: name)
        let outerParams = parameters(of: template)

        var result: [String] = []

        for param in innerParams {
            let name = param.label ?? param.name

            if let argument = arguments.first(where: { $0.name == name }) {
                result.append("\(argument.name): \(argument.value)")
            } else if let outer = outerParams.first(where: { $0.name == param.name }) {
                param.asParameter(outerType: outer.type).map { result.append($0) }
            }
        }

        return result.joined(separator: ", ")
    }

    func append(parameter: ParameterDef, to name: String) {
        if let signature = signatures[name] {
            var newParameters = signature.parameters
            var newRequiredParameters = signature.required

            if parameter.canBeOverriden {
                newRequiredParameters.append(parameter)
            } else {
                newParameters.append(parameter)
            }

            signatures[name] = .init(parameters: newParameters, required: newRequiredParameters, includes: signature.includes)
        } else {
            if parameter.canBeOverriden {
                signatures[name] = .init(parameters: [], required: [parameter], includes: [])
            } else {
                signatures[name] = .init(parameters: [parameter], required: [], includes: [])
            }
        }
    }

    func append(include: String, to name: String) {
        if let signature = signatures[name] {
            var newIncludes = signature.includes
            newIncludes.append(include)
            signatures[name] = .init(parameters: signature.parameters, required: signature.required, includes: newIncludes)
        } else {
            signatures[name] = .init(parameters: [], required: [], includes: [include])
        }
    }

    public static func shared(for pages: [PageDef], with parameters: [ParameterDef]) -> SwiftPageSignatures {
        let signatures = SwiftPageSignatures()

        for page in pages {
            for parameter in parameters {
                signatures.append(parameter: parameter, to: page.name.reversed().joined(separator: "."))
            }
        }

        return signatures
    }

    public static func shared(for pages: [PageDef], with parameters: [String]) -> SwiftPageSignatures {
        let parameters = parameters.compactMap(ParameterDef.init)

        return SwiftPageSignatures.shared(for: pages, with: parameters)
    }
}

extension SwiftPageSignatures {
    class SignatureResolver {
        enum ResolverError: Error {
            case circularDependency
            case missingSignature
            case missingResolution
            case redefenitionOfParameters
        }

        let input: SwiftPageSignatures
        var resolved: [String: [ParameterDef]] = [:]
        var currentSearch: [String] = []

        init(input: SwiftPageSignatures) {
            self.input = input
        }

        func parse() {
            for (key, value) in input.signatures {
                currentSearch = []
                parseSignature(value, with: key)
            }

            for (key, value) in input.signatures {
                guard var result = resolved[key] else { continue }

                for p in value.required {
                    if !result.contains(where: { $0.name == p.name }) {
                        result.append(p)
                    }
                }

                resolved[key] = result
            }

            input.resolved = resolved
        }

        func parseSignature(_ signature: PageSignature, with name: String) {
            // I originaly planned to throw an appropriate exception on a parse failure
            // but I realised that I could not think of a good way of recovering from those exceptions
            // So I decided to go with skip on error for now and deal with this later if the need ever arises

            // Break on circular references
            guard !currentSearch.contains(name) else { return }
            currentSearch.append(name)

            if let _ = resolved[name] {
                ()
            } else {
                var buffer = signature.parameters

                for i in signature.includes {
                    guard let s = input.signatures[i] else { continue }
                    parseSignature(s, with: i)
                    guard let cached = resolved[i] else { continue }

                    for c in cached {
                        if !c.localOnly, !buffer.contains(where: { $0.name == c.name }) {
                            buffer.append(c)
                        }
                    }
                }

                resolved[name] = buffer
            }
        }
    }

    func resolve() {
        let resolver = SignatureResolver(input: self)
        resolver.parse()
    }
}

extension SwiftPageSignatures.ParameterDef {
    var asDeclaration: String {
        let label = if let label { "\(label) " } else { "" }
        let d = if let defaultValue { " = \(defaultValue)" } else { "" }
        return "\(label)\(name): \(type)\(d)"
    }

    func asParameter(outerType: String) -> String? {
        guard outerType == type else { return nil }

        if let label {
            return "\(label): \(name)"
        } else {
            return "\(name): \(name)"
        }
    }
}

extension SwiftPageSignatures.ParameterDef: Equatable {}
extension SwiftPageSignatures.ParameterDef: LosslessStringConvertible {
    public init?(_ description: String) {
        let checkedDescription: String

        localOnly = false

        if description.starts(with: "?") {
            canBeOverriden = true
            checkedDescription = String(description.dropFirst())
        } else {
            canBeOverriden = false
            checkedDescription = description
        }

        let input = checkedDescription.split(separator: ":")

        if input.count == 2 {
            let inputName = String(input[0].trimmingCharacters(in: .whitespacesAndNewlines))

            guard !inputName.isEmpty else { return nil }

            let splitType = input[1].split(separator: "=")

            guard !splitType.isEmpty, splitType.count < 3 else { return nil }

            let inputType = String(splitType[0].trimmingCharacters(in: .whitespacesAndNewlines))

            let inputDefaultValue: String? = if splitType.count == 1 {
                nil
            } else {
                String(splitType[1].trimmingCharacters(in: .whitespacesAndNewlines))
            }

            guard !inputType.isEmpty else { return nil }

            label = nil
            name = inputName
            type = inputType
            defaultValue = inputDefaultValue
        } else if input.count == 3 {
            let inputLabel = String(input[0].trimmingCharacters(in: .whitespacesAndNewlines))
            let inputName = String(input[1].trimmingCharacters(in: .whitespacesAndNewlines))

            guard !inputName.isEmpty else { return nil }

            let splitType = input[2].split(separator: "=")

            guard !splitType.isEmpty, splitType.count < 3 else { return nil }

            let inputType = String(splitType[0].trimmingCharacters(in: .whitespacesAndNewlines))

            let inputDefaultValue: String? = if splitType.count == 1 {
                nil
            } else {
                String(splitType[1].trimmingCharacters(in: .whitespacesAndNewlines))
            }

            guard !inputType.isEmpty else { return nil }

            label = if inputLabel.isEmpty { nil } else { inputLabel }
            name = inputName
            type = inputType
            defaultValue = inputDefaultValue
        } else {
            return nil
        }
    }

    public var description: String {
        let d = if let defaultValue { "=\(defaultValue)" } else { "" }
        return if let label {
            "\(label):\(name):\(type)\(d)"
        } else {
            ":\(name):\(type)\(d)"
        }
    }
}
