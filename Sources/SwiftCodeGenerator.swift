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
    var main: [String] = []
    var data: ASTStorage?
    
    let heqader = """
    let storage = LineStorage()
    """
    
    public func load(from storage: ASTStorage) {
        self.data = storage
    }
    
    public func generateText(at indentation: Int) -> String {
        guard let data else { return "" }
        
        for node in data.values {
            switch node {
            case .constant(let contents):
                var line = "\(String(repeating: "    ", count: indentation))line.append(\"\"\"\n"
                var buffer = String(repeating: "    ", count: indentation)
                for l in contents.lines {
                    buffer += l
                    if l == "\n" {
                        line.append(buffer)
                        buffer = String(repeating: "    ", count: indentation)
                    }
                }
                line.append("\n\(String(repeating: "    ", count: indentation))\"\"\")")
                main.append(line)
            case .slotDeclaration(let name, let defaults):
                ()
            case .slotCommand(let type, let contents):
                ()
            case .include(let name, let contents):
                ()
            case .conditional(let name, let check, let type, let contents):
                ()
            case .loop(let forEvery, let name, let contents):
                ()
            case .modifiers(let applying, let tag):
                ()
            case .eval(let line):
                ()
            case .value(let of):
                ()
            case .assignment(let name, let line):
                ()
            case .index:
                ()
            case .item:
                ()
            case .endOfBranch:
                ()
            }
        }
        
        return main.joined(separator: "\n")
    }
}
