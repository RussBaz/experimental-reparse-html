public final class SwiftCodeGenerator: CodeGenerator {
    struct ParameterDef {
        let type: String
        let name: String
        let label: String?
    }
    
    struct VariableDef {
        let name: String
        let type: String?
    }
        
    var parameters: [ParameterDef] = []
    var globalVariables: [VariableDef] = []
    var conditionTags: [String] = ["previousUnnamedIfTaken"]
    var main: [String] = []
    var includes: [String] = []
    var data: ASTStorage?
    
    let heqader = """
    let lines = LineStorage()
    """
    
    public func load(from storage: ASTStorage) {
        self.data = storage
    }
    
    public func generateText(at indentation: Int) -> String {
        guard let data else { return "" }
        
        for node in data.values {
            switch node {
            case .constant(let contents):
                var tmp: [String] = []
                
                var buffer = ""
                for l in contents.lines {
                    if l == "\n" {
                        if !buffer.isEmpty {
                            tmp.append("\(String(repeating: "    ", count: indentation))\(buffer)")
                            buffer = ""
                        }
                    } else {
                        buffer += l
                    }
                }
                if !buffer.isEmpty {
                    tmp.append("\(String(repeating: "    ", count: indentation))\(buffer)")
                }
                if !tmp.isEmpty {
                    main.append("\(String(repeating: "    ", count: indentation))lines.append(\"\"\"")
                    tmp.forEach { main.append($0) }
                    main.append("\(String(repeating: "    ", count: indentation))\"\"\")")
                }
                
            case .slotDeclaration(let name, let defaults):
                ()
            case .slotCommand(let type, let contents):
                ()
            case .include(let name, let contents):
                let name = ReparseHtml.splitFilenameIntoComponents(name)
                if !name.isEmpty {
                    let name = name.joined(separator: ".")
                    includes.append(name)
                    if !contents.values.isEmpty {
                        let innerGenerator = SwiftCodeGenerator()
                        innerGenerator.load(from: contents)
                        let lines = innerGenerator.generateText(at: indentation+1)
                        innerGenerator.copyInnerVariables(into: self)
                        main.append(lines)
                    }
                }
            case .conditional(let name, let check, let type, let contents):
                let name = name ?? "previousUnnamedIfTaken"
                let innerGenerator = SwiftCodeGenerator()
                innerGenerator.load(from: contents)
                let lines = innerGenerator.generateText(at: indentation+1)
                innerGenerator.copyInnerVariables(into: self)
                
                if !conditionTags.contains(name) {
                    conditionTags.append(name)
                }
                
                switch type {
                case .ifType:
                    main.append("\(String(repeating: "    ", count: indentation))if \(check) {")
                case .elseIfType:
                    main.append("\(String(repeating: "    ", count: indentation))if !\(name), \(check) {")
                case .elseType:
                    main.append("\(String(repeating: "    ", count: indentation))if !\(name) {")
                }
                main.append(lines)
                main.append("\(String(repeating: "    ", count: indentation+1))\(name) = true")
                main.append("\(String(repeating: "    ", count: indentation))}")
            case .loop(let forEvery, let name, let contents):
                let name = name ?? "previousUnnamedIfTaken"
                let innerGenerator = SwiftCodeGenerator()
                innerGenerator.load(from: contents)
                let lines = innerGenerator.generateText(at: indentation+1)
                innerGenerator.copyInnerVariables(into: self)
                main.append("\(String(repeating: "    ", count: indentation))for (index, item) in \(forEvery).enumerated() {")
                main.append(lines)
                main.append("\(String(repeating: "    ", count: indentation))}")
                main.append("\(String(repeating: "    ", count: indentation))\(name) = if \(forEvery).isEmpty { false } else { true }")
            case .modifiers(let applying, let tag):
                ()
            case .eval(let line):
                main.append("\(String(repeating: "    ", count: indentation))lines.append(\"\\(\(line))\")")
            case .value(let of):
                main.append("\(String(repeating: "    ", count: indentation))lines.append(\"\\(\(of))\")")
            case .assignment(let name, let line):
                main.append("\(String(repeating: "    ", count: indentation))let \(name) = \(line)")
            case .index:
                main.append("\(String(repeating: "    ", count: indentation))lines.append(\"\\(index)\")")
            case .item:
                main.append("\(String(repeating: "    ", count: indentation))lines.append(\"\\(item)\")")
            case .endOfBranch:
                ()
            }
        }
        
        return main.joined(separator: "\n")
    }
    
    func copyInnerVariables(into generator: SwiftCodeGenerator) {
        for i in includes {
            if !generator.includes.contains(i) {
                generator.includes.append(i)
            }
        }
    }
}
