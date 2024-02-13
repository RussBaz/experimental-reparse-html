struct OutNode {
    var children: [String: OutNode]
    var pages: [RendererDef]
}

extension OutNode {
    static func from(_ pages: [PageDef]) -> Self {
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

    func build(name: String = "Pages", offset: Int = 0) -> String {
        let header = """
        \(String(repeating: " ", count: offset * 4))enum \(name.capitalized) {
        """
        let children = children.map { c in
            c.value.build(name: c.key, offset: offset + 1)
        }
        .joined(separator: "\n\n")

        let renderers = pages.map { p in
            buildPageEnum(for: p.name, at: p.path, offset: offset + 1)
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

    func buildRenderFunc(for path: String, offset: Int = 0) -> String {
        """
        \(String(repeating: " ", count: offset * 4))static func render() -> String {
        \(String(repeating: " ", count: offset * 4))    \"\"\"
        \(String(repeating: " ", count: offset * 4))    \(indentContentOf(path: path, offset: offset + 1))
        \(String(repeating: " ", count: offset * 4))    \"\"\"
        \(String(repeating: " ", count: offset * 4))}
        """
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

    func buildPageEnum(for name: String, at path: String, offset: Int = 0) -> String {
        """
        \(String(repeating: " ", count: offset * 4))enum \(name.capitalized) {
        \(buildPathFunc(for: path, offset: offset + 1))

        \(buildRenderFunc(for: path, offset: offset + 1))
        \(String(repeating: " ", count: offset * 4))}
        """
    }
}
