public final class SwiftOutputBuilder {
    public struct RendererDef {
        let path: String
        let name: String
        let properties: PageProperties
    }

    var children: [String: SwiftOutputBuilder] = [:]
    var pages: [RendererDef] = []
    let indentation: Int

    let name: String
    let enumName: String
    let fileExtension: String
    let signatures: SwiftPageSignatures
    let protocols: [PageProperties.ProtocolCompliance]

    public init(name: String, enumName: String, fileExtension: String, signatures: SwiftPageSignatures, protocols: [PageProperties.ProtocolCompliance], at indentation: Int) {
        self.name = name
        self.enumName = enumName
        self.fileExtension = fileExtension
        self.signatures = signatures
        self.indentation = indentation
        self.protocols = protocols
    }

    public func add(pages: [PageDef]) {
        for page in pages {
            add(page: page, name: page.name)
        }
    }

    public func add(page: PageDef, name: [String]) {
        guard let fragmentName = name.last else { return }

        if name.count == 1 {
            guard let renderer = RendererDef(page: page, signatures: signatures, protocols: protocols, fileExtension: fileExtension, enumName: enumName, at: indentation + 1) else { return }
            pages.append(renderer)
        } else {
            let child = children[fragmentName] ?? SwiftOutputBuilder(name: fragmentName, enumName: enumName, fileExtension: fileExtension, signatures: signatures, protocols: protocols, at: indentation + 1)
            child.add(page: page, name: name.dropLast())
            children[fragmentName] = child
        }
    }

    public func text(imports: [String] = []) -> String {
        signatures.resolve()

        let topLine = """
        //
        // ------------------------------
        // reparse version: 0.0.13
        // ------------------------------
        // This is an auto-generated file
        // ------------------------------
        //

        import ReparseRuntime

        """

        if imports.isEmpty {
            return topLine + build()
        } else {
            var buffer = [String]()
            for i in imports {
                buffer.append("import \(i)")
            }

            if buffer.isEmpty {
                return topLine + build()
            } else {
                return topLine + buffer.joined(separator: "\n") + "\n\n" + build()
            }
        }
    }

    public func build() -> String {
        let header = """
        \(String(repeating: "    ", count: indentation))enum \(name) {
        """

        let children = children.keys.sorted()
            .compactMap { self.children[$0] }
            .map { $0.build() }
            .joined(separator: "\n\n")

        let renderers = pages.sorted(by: { $0.name < $1.name }).map { p in
            buildPageEnum(for: p, at: indentation + 1)
        }
        .joined(separator: "\n\n")

        let footer = """
        \(String(repeating: "    ", count: indentation))}
        """

        let markNestedPages = """
        \(String(repeating: "    ", count: indentation + 1))// Nested pages
        """

        let markOwnPages = """
        \(String(repeating: "    ", count: indentation + 1))// Own pages
        """

        return switch (children.isEmpty, renderers.isEmpty) {
        case (true, true):
            [header, footer].joined(separator: "\n")
        case (true, false):
            [header, markOwnPages, renderers, footer].joined(separator: "\n")
        case (false, true):
            [header, markNestedPages, children, footer].joined(separator: "\n")
        case (false, false):
            [header, markNestedPages, children, "", markOwnPages, renderers, footer].joined(separator: "\n")
        }
    }

    func buildRenderFunc(for page: RendererDef, at indentation: Int = 0) -> String {
        let signature = signatures.declaration(of: page.properties.name)
        let include = signatures.parameters(of: page.properties.name, in: page.properties.name)
        return """
        \(String(repeating: "    ", count: indentation))static func render(\(signature)) -> String {
        \(String(repeating: "    ", count: indentation))    include(\(include)).render()
        \(String(repeating: "    ", count: indentation))}
        """
    }

    func buildIncludeFunc(for page: RendererDef) -> String {
        page.properties.asText()
    }

    func buildPathFunc(for path: String, at indentation: Int = 0) -> String {
        """
        \(String(repeating: "    ", count: indentation))// Template: ./\(path)
        """
    }

    func buildPageEnum(for page: RendererDef, at indentation: Int = 0) -> String {
        let protocols = if page.properties.protocols.isEmpty { "" } else { ": \(page.properties.protocols.map(\.asDeclaration).joined(separator: ", "))" }
        let associatedTypes: String = if page.properties.protocols.isEmpty {
            ""
        } else {
            page.properties.protocols
                .flatMap(\.asAssociatedType)
                .map { "\(String(repeating: "    ", count: indentation + 1))\($0)" }
                .joined(separator: "\n") + "\n\n"
        }

        if protocols.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return """
            \(String(repeating: "    ", count: indentation))enum \(page.name) {
            \(buildPathFunc(for: page.path, at: indentation + 1))
            \(buildRenderFunc(for: page, at: indentation + 1))
            \(buildIncludeFunc(for: page))
            \(String(repeating: "    ", count: indentation))}
            """
        } else if associatedTypes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return """
            \(String(repeating: "    ", count: indentation))struct \(page.name)\(protocols) {
            \(buildPathFunc(for: page.path, at: indentation + 1))
            \(buildRenderFunc(for: page, at: indentation + 1))
            \(buildIncludeFunc(for: page))
            \(String(repeating: "    ", count: indentation))}
            """
        } else {
            return """
            \(String(repeating: "    ", count: indentation))struct \(page.name)\(protocols) {
            \(associatedTypes)\(buildPathFunc(for: page.path, at: indentation + 1))
            \(buildRenderFunc(for: page, at: indentation + 1))
            \(buildIncludeFunc(for: page))
            \(String(repeating: "    ", count: indentation))}
            """
        }
    }
}

public extension SwiftOutputBuilder.RendererDef {
    init?(page: PageDef, signatures: SwiftPageSignatures, protocols: [PageProperties.ProtocolCompliance], fileExtension ext: String, enumName: String, at indentation: Int) {
        guard let contents = try? String(contentsOfFile: "\(page.root)/\(page.path)") else { return nil }
        guard let storage = Parser.parse(html: contents) else { return nil }
        guard let fragmentName = page.name.first else { return nil }
        let fullName = page.name.reversed().joined(separator: ".")

        let properties = PageProperties(name: fullName, rootPath: page.root, fileExtension: ext, enumName: enumName, protocols: protocols)

        let generator = SwiftCodeGenerator(ast: storage, signatures: signatures, page: properties)

        generator.run(at: indentation + 1)

        name = fragmentName
        path = page.path
        self.properties = properties
    }
}
