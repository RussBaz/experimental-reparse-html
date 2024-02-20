final class LineStorage {
    var lines: [String] = []

    func append(_: String) {}
    func extend(_: LineStorage) {}
    func include(_: LineStorage, using _: (LineStorage) -> Void = { _ in }) {}
    func add(slot _: String, using _: (LineStorage) -> Void = { _ in }) {}
    func replace(slot _: String, using _: (LineStorage) -> Void = { _ in }) {}
    func declare(slot _: String, using _: (LineStorage) -> Void = { _ in }) {}

    func render() -> String {
        lines.joined(separator: "\n")
    }
}
