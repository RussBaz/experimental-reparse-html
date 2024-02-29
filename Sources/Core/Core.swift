public struct PageDef {
    let path: String
    let name: [String]

    public init(path: String, name: [String]) {
        self.path = path
        self.name = name
    }
}

public func splitFilenameIntoComponents(_ name: String, dropping ext: String) -> [String] {
    var r = name.split(separator: "/")

    if r.last?.hasSuffix(".\(ext)") == true {
        r[r.count - 1] = r[r.count - 1].dropLast(5)
    }

    if r.isEmpty {
        r = ["Index"]
    }

    if r.first == "" {
        r[r.startIndex] = "Index"
    }

    return r.map(String.init).map(\.capitalized)
}
