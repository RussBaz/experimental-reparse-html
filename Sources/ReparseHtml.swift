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

    mutating func run() throws {
        guard directoryExists(at: location.path) else {
            throw ValidationError("Folder does not exist at \(location.path)")
        }

//        let htmls = findAllFiles(in: [location.path])
//
//        let ast = OutNode.from(htmls)

        print("Looking for file at: \(location.path)/test.html")

        if let contents = try? String(contentsOfFile: "\(location.path)/test.html") {
            if let storage = Parser.parse(html: contents) {
                print("Node count: \(storage.values.count)")
//                let generator = SwiftCodeGenerator()
//                generator.load(from: storage)
//                let result = generator.generateText(at: 1)

//                print("Text:\n\(result)")
                for node in storage.values {
                    switch node {
                    case let .constant(contents):
                        print("\nConstant ->")
                        for c in contents.values {
                            print(": \(c)")
                        }
                    default:
                        print("\nNode -> \(node)")
                    }
                }
            } else {
                print("Could not parse the file.")
            }
        } else {
            print("File not found.")
        }
    }

    func directoryExists(at path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    func findAllFiles(in directories: [String]) -> [PageDef] {
        var result: [PageDef] = []

        for path in directories {
            let foundFiles = findFilesInDirectory(at: path)
            result.append(contentsOf: foundFiles)
        }

        return result
    }

    func findFilesInDirectory(at path: String) -> [PageDef] {
        guard directoryExists(at: path) else { return [] }

        guard let enumerator = FileManager.default.enumerator(atPath: path) else {
            return []
        }
        let paths = enumerator.allObjects as! [String]

        var htmls: [PageDef] = []

        for i in paths {
            let url = URL(fileURLWithPath: "\(path)/\(i)")
            let path = url.path
            if path.hasSuffix(".html") {
                htmls.append(.init(path: path, name: ReparseHtml.splitFilenameIntoComponents(i).reversed()))
            }
        }

        return htmls
    }

    static func splitFilenameIntoComponents(_ name: String) -> [String] {
        var r = name.split(separator: "/")

        if r.last?.hasSuffix(".html") == true {
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
