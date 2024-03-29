import Foundation

public struct PageDef {
    let path: String
    let root: String
    let name: [String]

    public init(path: String, name: [String], root: String) {
        self.path = path
        self.name = name
        self.root = root
    }
}

func splitFilenameIntoComponents(_ name: String, dropping ext: String) -> [String] {
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

    return r.map {
        $0.split(whereSeparator: { $0 == " " || $0 == "-" })
            .map(\.capitalized)
            .joined()
    }
}

public enum ReparseCore {
    public static func run(locations: [String], parameters: [String], imports: [String], protocols: [String], fileExtension: String, outFolder: String, outName: String, enumName: String, dryRun: Bool) throws {
        let htmls = findAllFiles(in: locations, searching: fileExtension)

        let signatures = SwiftPageSignatures.shared(for: htmls, with: parameters)
        let protocols = protocols.map(PageProperties.ProtocolCompliance.init).compactMap { $0 }

        let builder = SwiftOutputBuilder(name: enumName, enumName: enumName, fileExtension: fileExtension, signatures: signatures, protocols: protocols, at: 0)

        builder.add(pages: htmls)

        let output = builder.text(imports: imports)

        let destination = "\(outFolder)/\(outName)"

        if dryRun {
            print(output)
        } else {
            try output.write(toFile: destination, atomically: true, encoding: .utf8)
        }
    }

    public static func directoryExists(at path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    static func findAllFiles(in directories: [String], searching ext: String) -> [PageDef] {
        var result: [PageDef] = []

        for path in directories {
            let foundFiles = findFilesInDirectory(at: path, searching: ext)
            result.append(contentsOf: foundFiles)
        }

        return result
    }

    static func findFilesInDirectory(at path: String, searching ext: String) -> [PageDef] {
        guard directoryExists(at: path) else { return [] }

        guard let enumerator = FileManager.default.enumerator(atPath: path) else {
            return []
        }
        let paths = enumerator.allObjects as! [String]

        var htmls: [PageDef] = []

        for i in paths {
            let url = URL(fileURLWithPath: "\(path)/\(i)")
            let resultPath = url.path
            if resultPath.hasSuffix(".\(ext)") {
                htmls.append(PageDef(path: i, name: splitFilenameIntoComponents(i, dropping: ext).reversed(), root: path))
            }
        }

        return htmls
    }
}
