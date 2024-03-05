import Foundation
import PackagePlugin

enum Preset {
    case vapor
    case vaporHX
    case none
}

@main
struct ReparsePlugin: CommandPlugin {
    func performCommand(
        context: PluginContext,
        arguments: [String]
    ) throws {
        let reparse = try context.tool(named: "reparse")
        var argExtractor = ArgumentExtractor(arguments)

        let providedPreset = argExtractor.extractOption(named: "preset").first.map { $0.lowercased() }
        let providedSource = argExtractor.extractOption(named: "source").filter { !$0.isEmpty }
        let providedTarget = argExtractor.extractOption(named: "target").first
        let providedDestination = argExtractor.extractOption(named: "destination")

        let providedImports = argExtractor.extractOption(named: "imports")
        let providedParameters = argExtractor.extractOption(named: "parameters")
        let providedProtocols = argExtractor.extractOption(named: "protocols")

        let preset: Preset = if providedPreset == "vapor" { .vapor } else if providedPreset == "vaporhx" { .vaporHX } else { .none }

        let sourceLocation: [String] = if providedSource.isEmpty {
            switch preset {
            case .vapor:
                ["Resources", "Pages"]
            case .vaporHX:
                ["Resources", "Pages"]
            case .none:
                []
            }
        } else {
            providedSource
        }

        let targetPath: Path = if let providedTarget {
            if let target = try? context.package.targets(named: [providedTarget]).first {
                target.sourceModule?.directory ?? context.package.directory
            } else {
                switch preset {
                case .vapor:
                    if let target = try? context.package.targets(named: ["App"]).first {
                        target.sourceModule?.directory ?? context.package.directory
                    } else {
                        context.package.directory
                    }
                case .vaporHX:
                    if let target = try? context.package.targets(named: ["App"]).first {
                        target.sourceModule?.directory ?? context.package.directory
                    } else {
                        context.package.directory
                    }
                case .none:
                    context.package.directory
                }
            }
        } else {
            switch preset {
            case .vapor:
                if let target = try? context.package.targets(named: ["App"]).first {
                    target.sourceModule?.directory ?? context.package.directory
                } else {
                    context.package.directory
                }
            case .vaporHX:
                if let target = try? context.package.targets(named: ["App"]).first {
                    target.sourceModule?.directory ?? context.package.directory
                } else {
                    context.package.directory
                }
            case .none:
                context.package.directory
            }
        }

        let location = context.package.directory.appending(sourceLocation)
        let destination = targetPath.appending(providedDestination)

        let fileName = argExtractor.extractOption(named: "fileName").first
        let fileExtension = argExtractor.extractOption(named: "fileExtension").first
        let enumName = argExtractor.extractOption(named: "enumName").first

        var imports: [String] = []
        var parameters: [String] = []
        var protocols: [String] = []

        switch preset {
        case .vapor:
            imports.append("Vapor")
            imports.append(contentsOf: providedImports)
            parameters.append("req:Request")
            parameters.append(contentsOf: providedParameters)
            protocols.append(contentsOf: providedProtocols)
        case .vaporHX:
            imports.append("Vapor")
            imports.append("VHX")
            imports.append(contentsOf: providedImports)
            parameters.append("req:Request")
            parameters.append("isPage:Bool")
            parameters.append("?context:EmptyContext=EmptyContext()")
            parameters.append(contentsOf: providedParameters)
            protocols.append("HXTemplateable")
            protocols.append(contentsOf: providedProtocols)
        case .none:
            imports.append(contentsOf: providedImports)
            parameters.append(contentsOf: providedParameters)
            protocols.append(contentsOf: providedProtocols)
        }

        let dryRun = argExtractor.extractFlag(named: "dryRun") > 0

        var args: [String] = [location.string, destination.string]

        if let fileName {
            args.append("--fileName")
            args.append(fileName)
        }

        if let fileExtension {
            args.append("--file-extension")
            args.append(fileExtension)
        }

        if let enumName {
            args.append("--enum-name")
            args.append(enumName)
        }

        for i in imports {
            args.append("--imports")
            args.append(i)
        }

        for p in parameters {
            args.append("--parameters")
            args.append(p)
        }

        for p in protocols {
            args.append("--protocols")
            args.append(p)
        }

        if dryRun {
            args.append("--dry-run")
        }

        let toolExec = URL(fileURLWithPath: reparse.path.string)

        let process = try Process.run(toolExec, arguments: args)
        process.waitUntilExit()

        // Check whether the subprocess invocation was successful.
        if process.terminationReason == .exit, process.terminationStatus == 0 {
            print("HTML templates from \(location.string) are compiled into \(destination.string).")
        } else {
            let problem = "\(process.terminationReason):\(process.terminationStatus)"
            Diagnostics.error("HTML templates compilation failed: \(problem)")
        }
    }
}
