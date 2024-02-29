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

    public init(name: String, enumName: String, fileExtension: String, signatures: SwiftPageSignatures, at indentation: Int) {
        self.name = name
        self.enumName = enumName
        self.fileExtension = fileExtension
        self.signatures = signatures
        self.indentation = indentation
    }

    public func add(pages: [PageDef]) {
        for page in pages {
            add(page: page, name: page.name)
        }
    }

    public func add(page: PageDef, name: [String]) {
        guard let fragmentName = name.last else { return }

        if name.count == 1 {
            guard let renderer = RendererDef(page: page, signatures: signatures, fileExtension: fileExtension, enumName: enumName, at: indentation + 1) else { return }
            pages.append(renderer)
        } else {
            let child = children[fragmentName] ?? SwiftOutputBuilder(name: fragmentName, enumName: enumName, fileExtension: fileExtension, signatures: signatures, at: indentation + 1)
            child.add(page: page, name: name.dropLast())
            children[fragmentName] = child
        }
    }

    public func text(imports: [String] = []) -> String {
        signatures.resolve()

        let topLine = """
        //
        // ------------------------------
        // reparse version: 0.0.1
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

        let children = children.map { _, value in
            value.build()
        }
        .joined(separator: "\n\n")

        let renderers = pages.map { p in
            buildPageEnum(for: p, at: indentation + 1)
        }
        .joined(separator: "\n\n")

        let footer = """
        \(String(repeating: "    ", count: indentation))}
        """

        return switch (children.isEmpty, renderers.isEmpty) {
        case (true, true):
            [header, footer].joined(separator: "\n")
        case (true, false):
            [header, renderers, footer].joined(separator: "\n")
        case (false, true):
            [header, children, footer].joined(separator: "\n")
        case (false, false):
            [header, children, "", renderers, footer].joined(separator: "\n")
        }
    }

    func buildRenderFunc(for page: RendererDef, at indentation: Int = 0) -> String {
        let signature = signatures.parameters(of: page.properties.name).map(\.asDeclaration).joined(separator: ", ")
        let include = signatures.parameters(of: page.properties.name).map(\.asParameter).joined(separator: ", ")
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
        \(String(repeating: "    ", count: indentation))static var path: String {
        \(String(repeating: "    ", count: indentation))    \"\"\"
        \(String(repeating: "    ", count: indentation))    \(path)
        \(String(repeating: "    ", count: indentation))    \"\"\"
        \(String(repeating: "    ", count: indentation))}
        """
    }

    func buildPageEnum(for page: RendererDef, at indentation: Int = 0) -> String {
        """
        \(String(repeating: "    ", count: indentation))enum \(page.name.capitalized) {
        \(buildPathFunc(for: page.path, at: indentation + 1))
        \(buildRenderFunc(for: page, at: indentation + 1))
        \(buildIncludeFunc(for: page))
        \(String(repeating: "    ", count: indentation))}
        """
    }
}

public extension SwiftOutputBuilder.RendererDef {
    init?(page: PageDef, signatures: SwiftPageSignatures, fileExtension ext: String, enumName: String, at indentation: Int) {
        guard let contents = try? String(contentsOfFile: page.path) else { return nil }
        guard let storage = Parser.parse(html: contents) else { return nil }
        guard let fragmentName = page.name.first else { return nil }
        let fullName = page.name.reversed().joined(separator: ".")

        let properties = PageProperties(name: fullName, fileExtension: ext, enumName: enumName)

        let generator = SwiftCodeGenerator(ast: storage, signatures: signatures, page: properties)

        generator.run(at: indentation + 1)

        name = fragmentName
        path = page.path
        self.properties = properties
    }
}