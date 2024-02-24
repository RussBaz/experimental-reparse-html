final class SwiftLineStorage {
    typealias LineGenerator = (SwiftLineStorage) -> Void

    enum StorageType {
        case normal
        case slot(name: String, replace: Bool)
    }

    enum LineCommand {
        case text(value: String, replace: Bool)
        case slot(name: String, otherwise: LineGenerator?)
    }

    var type: StorageType = .normal
    var extending: SwiftLineStorage?

    var lines: [LineCommand] = []
    var stashed: [LineCommand] = []

    var declaredSlot: [String] = []

    var innerSlots: [String: SwiftLineStorage] = [:]

    var insideSlotDeclaration = false

    func append(_ text: String) {
        lines.append(.text(value: text, replace: false))
    }

    func extend(_ storage: SwiftLineStorage) {
        if let extending {
            extending.extend(storage)
        } else if case .normal = type, lines.isEmpty {
            extending = storage
            type = .slot(name: "default", replace: false)
        }
    }

    func include(_: SwiftLineStorage, using _: LineGenerator? = nil) {}
    func declare(slot name: String, using generator: LineGenerator? = nil) {
        if !declaredSlot.contains(name) {
            declaredSlot.append(name)
        }
        lines.append(.slot(name: name, otherwise: generator))
    }

    func add(slot name: String, using generator: LineGenerator) {
        if let item = innerSlots[name] {
            generator(item)
        } else {
            let item = SwiftLineStorage(slot: name, replace: false)
            innerSlots[name] = item
            generator(item)
        }
    }

    func replace(slot name: String, using generator: LineGenerator) {
        if let item = innerSlots[name] {
            generator(item)
        } else {
            let item = SwiftLineStorage(slot: name, replace: true)
            innerSlots[name] = item
            generator(item)
        }
    }

    func render() -> String {
        ""
    }

    func stash(from: Int) {
        guard from < lines.endIndex else { return }
        guard stashed.isEmpty else { return }
        guard !lines.isEmpty else { return }

        stashed = Array(lines[from ..< lines.endIndex])
        lines.removeSubrange(from ..< lines.endIndex)
    }

    func unstash() {
        lines.append(contentsOf: stashed)
        stashed = []
    }

    convenience init(slot: String, replace: Bool) {
        self.init()
        type = .slot(name: slot, replace: replace)
    }
}
