// The Swift Programming Language
// https://docs.swift.org/swift-book
// 
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import ArgumentParser
import Foundation

@main
struct ReparseHtml: ParsableCommand {
    @Argument(help: "The target data folder location.", transform: URL.init(fileURLWithPath:))
    var location: URL
    
    mutating func run() throws {
        guard directoryExists(at: location.path) else {
            throw ValidationError("Folder does not exist at \(location.path)")
        }
        
        let htmls = findAllFiles(in: [location.path])
        
        print("Files:")
        
        for path in htmls {
            print(path)
        }
    }
    
    func directoryExists(at path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
    
    func findAllFiles(in directories: [String]) -> [(String, [String])] {
        var result: [(String, [String])] = []
        
        for path in directories {
            let foundFiles = findFilesInDirectory(at: path)
            result.append(contentsOf: foundFiles)
        }
        
        return result
    }
    
    func findFilesInDirectory(at path: String) -> [(String, [String])] {
        guard directoryExists(at: path) else { return [] }
        
        guard let enumerator = FileManager.default.enumerator(atPath: path) else {
            return []
        }
        let paths = enumerator.allObjects as! [String]
        
        var htmls: [(String, [String])] = []
        
        for i in paths {
            let url = URL.init(fileURLWithPath: "\(path)/\(i)")
            let path = url.path
            if path.hasSuffix(".html") {
                htmls.append((path, splitName(i)))
            }
        }
        
        return htmls
    }
    
    func splitName(_ name: String) -> [String] {
        var r = name.split(separator: "/")
        
        if r.last?.hasSuffix(".html") == true {
            r[r.count-1] = r[r.count-1].dropLast(5)
        }
        
        if r.isEmpty {
            r = ["Index"]
        }
        
        if r.first == "" {
            r[r.startIndex] = "Index"
        }
        
        return r.map(String.init)
    }
}
