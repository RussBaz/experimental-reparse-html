final class PageProperties {
    enum LineType {
        case text(String)
        case deferred(() -> [String])
    }

    struct LineDef {
        let indentation: Int
        let line: LineType
    }

    let name: String
    let fileExtension: String
    let enumName: String
    var lines: [LineDef] = []
    var conditionTags: [String] = []
    var defaultValues: [String: String] = [:]
    var modifiersPresent = false

    init(name: String, fileExtension: String, enumName: String) {
        self.name = name
        self.fileExtension = fileExtension
        self.enumName = enumName
    }

    func clear() {
        lines = []
        conditionTags = []
        defaultValues = [:]
    }

    func append(at indentation: Int) {
        lines.append(.init(indentation: indentation, line: .text("")))
    }

    func prepend(at indentation: Int) {
        lines.insert(.init(indentation: indentation, line: .text("")), at: 0)
    }

    func append(_ text: String, at indentation: Int) {
        lines.append(.init(indentation: indentation, line: .text(text)))
    }

    func append(at indentation: Int, deferred: @escaping () -> [String]) {
        lines.append(.init(indentation: indentation, line: .deferred(deferred)))
    }

    func prepend(_ text: String, at indentation: Int) {
        lines.insert(.init(indentation: indentation, line: .text(text)), at: 0)
    }

    func prepend(at indentation: Int, deferred: @escaping () -> [String]) {
        lines.insert(.init(indentation: indentation, line: .deferred(deferred)), at: 0)
    }

    func append(contentsOf data: [LineDef]) {
        lines.append(contentsOf: data)
    }

    func prepend(contentsOf data: [LineDef]) {
        lines.insert(contentsOf: data, at: 0)
    }

    func append(condition tag: String) {
        if !conditionTags.contains(tag) {
            conditionTags.append(tag)
        }
    }

    func appendDefault(name: String, value: String) {
        defaultValues[name] = value
    }

    func asText(at indenation: Int = 0) -> String {
        asLines(at: indenation).joined(separator: "\n")
    }

    func asLines(at indentation: Int = 0) -> [String] {
        var result = [String]()

        for l in lines {
            switch l.line {
            case let .text(string):
                result.append("\(String(repeating: "    ", count: indentation + l.indentation))\(string)")
            case let .deferred(f):
                for i in f() {
                    result.append("\(String(repeating: "    ", count: indentation + l.indentation))\(i)")
                }
            }
        }

        return result
    }
}
