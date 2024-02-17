final class LineStorage {
    var lines: [String] = []

    func append(_: String) {}
    func include(_: LineStorage, using _: (LineStorage) -> Void = { _ in }) {}
    func add(slot _: String, using _: (LineStorage) -> Void = { _ in }) {}
    func replace(slot _: String, using _: (LineStorage) -> Void = { _ in }) {}
    func declare(slot _: String, using _: (LineStorage) -> Void = { _ in }) {}
}
