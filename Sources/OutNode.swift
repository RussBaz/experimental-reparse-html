struct OutNode {
    var children: [String: OutNode]
    var pages: [RendererDef]
}

extension OutNode {
    static func from(_ pages: [PageDef], with _: SwiftCodeGenerator.SwiftPageSignatures) -> Self {
        var root = OutNode(children: [:], pages: [])

        for p in pages {
            root.add(page: p)
        }

        return root
    }

    mutating func add(page: PageDef) {
        guard let fragmentName = page.name.last else { return }

        if page.name.count == 1 {
            pages.append(.init(path: page.path, name: fragmentName))
        } else {
            var child = children[fragmentName] ?? OutNode(children: [:], pages: [])
            child.add(page: .init(path: page.path, name: page.name.dropLast()))
            children[fragmentName] = child
        }
    }

    func debugPrint(offset: Int = 0) {
        for p in pages {
            print("\(String(repeating: " ", count: offset * 2))Name: \(p.name), path: \(p.path)")
        }

        for c in children {
            print("\(String(repeating: " ", count: offset * 2))Child: \(c.key)")
            c.value.debugPrint(offset: offset + 1)
        }
    }

    func build(name: String, extensionName ext: String, with signatures: SwiftCodeGenerator.SwiftPageSignatures, offset: Int = 0) -> String {
        let header = """
        \(String(repeating: " ", count: offset * 4))enum \(name.capitalized) {
        """

        let children = children.map { c in
            c.value.build(name: c.key, extensionName: ext, with: signatures, offset: offset + 1)
        }
        .joined(separator: "\n\n")

        let renderers = pages.map { p in
            buildPageEnum(for: p, signatures: signatures, extensionName: ext, at: offset + 1)
        }
        .joined(separator: "\n\n")

        let footer = """
        \(String(repeating: " ", count: offset * 4))}
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

    func indentContentOf(path: String, offset: Int) -> String {
        guard let contents = try? String(contentsOfFile: path) else { return "" }

        return contents.replacingOccurrences(of: "\n", with: "\n\(String(repeating: " ", count: offset * 4))")
    }

    func buildRenderFunc(for _: String, offset: Int = 0) -> String {
        """
        \(String(repeating: " ", count: offset * 4))// Hello Renderer!
        """
    }

    func buildIncludeFunc(for page: RendererDef, signatures: SwiftCodeGenerator.SwiftPageSignatures, extensionName ext: String, offset: Int = 0) -> String {
        guard let contents = try? String(contentsOfFile: page.path) else { return "" }
        guard let storage = Parser.parse(html: contents) else { return "" }

        let properties = SwiftCodeGenerator.PageProperties(name: page.name, fileExtension: ext)

        let generator = SwiftCodeGenerator(ast: storage, signatures: signatures, page: properties)

        generator.run(at: offset + 1)

        return properties.asText()
    }

    func buildPathFunc(for path: String, offset: Int = 0) -> String {
        """
        \(String(repeating: " ", count: offset * 4))static func path() -> String {
        \(String(repeating: " ", count: offset * 4))    \"\"\"
        \(String(repeating: " ", count: offset * 4))    \(path)
        \(String(repeating: " ", count: offset * 4))    \"\"\"
        \(String(repeating: " ", count: offset * 4))}
        """
    }

    func buildPageEnum(for page: RendererDef, signatures: SwiftCodeGenerator.SwiftPageSignatures, extensionName ext: String, at offset: Int = 0) -> String {
        """
        \(String(repeating: " ", count: offset * 4))enum \(page.name.capitalized) {
        \(buildPathFunc(for: page.path, offset: offset + 1))
        \(buildRenderFunc(for: page.path, offset: offset + 1))
        \(buildIncludeFunc(for: page, signatures: signatures, extensionName: ext, offset: offset))
        \(String(repeating: " ", count: offset * 4))}
        """
    }
}
