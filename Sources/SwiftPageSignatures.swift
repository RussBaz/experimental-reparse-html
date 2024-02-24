final class SwiftPageSignatures {
    struct ParameterDef {
        let type: String
        let name: String
        let label: String?
    }

    struct PageSignature {
        let parameters: [ParameterDef]
        let includes: [String]
    }

    var signatures = [String: PageSignature]()
    private var ressolved: [String: [ParameterDef]] = [:]

    func parameters(of name: String) -> [ParameterDef] {
        if let parameters = ressolved[name] {
            parameters
        } else if let parameters = signatures[name] {
            parameters.parameters
        } else {
            []
        }
    }

    func append(parameter: ParameterDef, to name: String) {
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

    static func shared(for pages: [PageDef], with parameters: [ParameterDef]) -> SwiftPageSignatures {
        let signatures = SwiftPageSignatures()

        for page in pages {
            for parameter in parameters {
                signatures.append(parameter: parameter, to: page.name.reversed().joined(separator: "."))
            }
        }

        return signatures
    }

    static func shared(for pages: [PageDef], with parameters: [String]) -> SwiftPageSignatures {
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

            input.ressolved = resolved
        }

        func parseSignature(_ signature: PageSignature, with name: String) {
            // I originaly planned to throw an appropriate exception on a parse failure
            // but I realised that I could not think of a good way of recovering from those exceptions
            // So I decided to go with skip on error for now and deal with this later if the need ever arises
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
                        let r = buffer.filter { $0.name == c.name }

                        if r.isEmpty {
                            buffer.append(c)
                        } else if r.count == 1, let item = r.first {
                            guard c == item else { continue }
                        } else {
                            buffer.removeAll(where: { $0.name == c.name })
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

extension SwiftPageSignatures.ParameterDef: Equatable {}
extension SwiftPageSignatures.ParameterDef: LosslessStringConvertible {
    init?(_ description: String) {
        let input = description.split(separator: ":")
        if input.count == 2 {
            let inputName = String(input[0].trimmingCharacters(in: .whitespacesAndNewlines))
            let inputType = String(input[1].trimmingCharacters(in: .whitespacesAndNewlines))

            guard !inputName.isEmpty, !inputType.isEmpty else { return nil }

            label = nil
            name = inputName
            type = inputType
        } else if input.count == 3 {
            let inputLabel = String(input[0].trimmingCharacters(in: .whitespacesAndNewlines))
            let inputName = String(input[1].trimmingCharacters(in: .whitespacesAndNewlines))
            let inputType = String(input[2].trimmingCharacters(in: .whitespacesAndNewlines))

            guard !inputName.isEmpty, !inputType.isEmpty else { return nil }

            label = if inputLabel.isEmpty { nil } else { inputLabel }
            name = inputName
            type = inputType
        } else {
            return nil
        }
    }

    var description: String {
        if let label {
            "\(label):\(name):\(type)"
        } else {
            ":\(name):\(type)"
        }
    }
}
