public protocol CodeGenerator {
    func load(from storage: ASTStorage)
    func generateText(at indentation: Int) -> String
}
