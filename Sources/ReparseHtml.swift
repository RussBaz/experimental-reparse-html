// The Swift Programming Language
// https://docs.swift.org/swift-book
//
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import ArgumentParser
import Foundation
import SwiftSoup

struct PageDef {
    let path: String
    let name: [String]
}

struct RendererDef {
    let path: String
    let name: String
}

@main
struct ReparseHtml: ParsableCommand {
    @Argument(help: "The target data folder location.", transform: URL.init(fileURLWithPath:))
    var location: URL

    @Argument(help: "The destination folder for the output file.", transform: URL.init(fileURLWithPath:))
    var destination: URL

    @Option(help: "Output file name")
    var fileName = "Pages.swift"

    @Option(help: "The file extension to be searched for")
    var fileExtension = "html"

    @Option(help: "The name of the generated enum")
    var enumName = "Pages"

    @Option(help: "List of global imports")
    var imports: [String] = []

    mutating func run() throws {
        guard directoryExists(at: location.path) else {
            throw ValidationError("Folder does not exist at \(location.path)")
        }

        var buffer = [String]()
        for i in imports {
            buffer.append("import \(i)")
        }

        if !imports.isEmpty {
            buffer.append("")
            buffer.append("")
        }

        let htmls = findAllFiles(in: [location.path], searching: fileExtension)

        let signatures = SwiftCodeGenerator.SwiftPageSignatures.shared(for: htmls, with: [.init(type: "String", name: "req", label: nil)])

        let ast = OutNode.from(htmls, with: signatures)

        let output = buffer.joined(separator: "\n") + ast.build(name: enumName, extensionName: fileExtension, with: signatures)

        let destination = destination.appendingPathComponent(fileName)

        try output.write(to: destination, atomically: true, encoding: .utf8)
    }

    func directoryExists(at path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    func findAllFiles(in directories: [String], searching ext: String) -> [PageDef] {
        var result: [PageDef] = []

        for path in directories {
            let foundFiles = findFilesInDirectory(at: path, searching: ext)
            result.append(contentsOf: foundFiles)
        }

        return result
    }

    func findFilesInDirectory(at path: String, searching ext: String) -> [PageDef] {
        guard directoryExists(at: path) else { return [] }

        guard let enumerator = FileManager.default.enumerator(atPath: path) else {
            return []
        }
        let paths = enumerator.allObjects as! [String]

        var htmls: [PageDef] = []

        for i in paths {
            let url = URL(fileURLWithPath: "\(path)/\(i)")
            let path = url.path
            if path.hasSuffix(".\(ext)") {
                htmls.append(.init(path: path, name: ReparseHtml.splitFilenameIntoComponents(i, dropping: ext).reversed()))
            }
        }

        return htmls
    }

    static func splitFilenameIntoComponents(_ name: String, dropping ext: String) -> [String] {
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
}
