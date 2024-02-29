import ArgumentParser
import Foundation
import ReparseCore

@main
struct Reparse: ParsableCommand {
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

    @Option(help: "List of shared parameters (parameters to be added to every 'include' function) in a form of 'label:name:type' or 'name:type'")
    var parameters: [String] = []

    @Flag(help: "Write the output to the console instead of file")
    var dryRun = false

    mutating func run() throws {
        guard directoryExists(at: location.path) else {
            throw ValidationError("Folder does not exist at \(location.path)")
        }

        let htmls = findAllFiles(in: [location.path], searching: fileExtension)

        let signatures = SwiftPageSignatures.shared(for: htmls, with: parameters)

        let builder = SwiftOutputBuilder(name: enumName, enumName: enumName, fileExtension: fileExtension, signatures: signatures, at: 0)

        builder.add(pages: htmls)

        let output = builder.text(imports: imports)

        let destination = destination.appendingPathComponent(fileName)

        if dryRun {
            print(output)
        } else {
            try output.write(to: destination, atomically: true, encoding: .utf8)
        }
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
                htmls.append(PageDef(path: path, name: splitFilenameIntoComponents(i, dropping: ext).reversed()))
            }
        }

        return htmls
    }
}
