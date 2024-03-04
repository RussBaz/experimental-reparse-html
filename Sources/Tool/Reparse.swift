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
    var fileName = "pages.swift"

    @Option(help: "The file extension to be searched for")
    var fileExtension = "html"

    @Option(help: "The name of the generated enum")
    var enumName = "Pages"

    @Option(help: "List of global imports")
    var imports: [String] = []

    @Option(help: "List of shared parameters (parameters to be added to every 'include' function) in a form of '[?][label:]name:type[=default]' where the optional parts are in square brackets. The question mark at the beginning indicates that the parameter will be overriden by a local requirement if it is present.")
    var parameters: [String] = []

    @Option(help: "A list of protocols to apply to enums with render functions in them in a form of 'name[:associatedName:associatedType]' where the optional parts are in square brackets. Optional part can be repeated any number of times.")
    var protocols: [String] = []

    @Flag(help: "Write the output to the console instead of file")
    var dryRun = false

    mutating func run() throws {
        guard ReparseCore.directoryExists(at: location.path) else {
            throw ValidationError("Folder does not exist at \(location.path)")
        }

        guard ReparseCore.directoryExists(at: destination.path) else {
            throw ValidationError("Folder does not exist at \(destination.path)")
        }

        try ReparseCore.run(locations: [location.path], parameters: parameters, imports: imports, protocols: protocols, fileExtension: fileExtension, outFolder: destination.path, outName: fileName, enumName: enumName, dryRun: dryRun)
    }
}
