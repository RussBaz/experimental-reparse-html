final class SwiftLineStorage {
    typealias LineGenerator = (SwiftLineStorage) -> Void

    enum StorageType {
        case empty
        case normal(contents: [LineCommand])
        case extending(contents: [LineCommand], templates: [SwiftLineStorage])
    }

    enum LineCommand {
        case text(value: String, slot: String?, replace: Bool)
        case declare(name: String, generator: LineGenerator?)
        case include(storage: SwiftLineStorage, generator: LineGenerator?)
        case noop
    }

    var type: StorageType = .empty

    var selectedSlot: String?
    var replacing = false

    func extend(_ storage: SwiftLineStorage) {
        switch type {
        case .empty:
            type = .extending(contents: [], templates: [storage])
        case .normal:
            ()
        case .extending(contents: let contents, templates: var templates):
            if contents.isEmpty {
                templates.append(storage)
                type = .extending(contents: contents, templates: templates)
            }
        }
    }

    func append(node: LineCommand) {
        switch type {
        case .empty:
            type = .normal(contents: [node])
        case var .normal(contents):
            contents.append(node)
            type = .normal(contents: contents)
        case .extending(var contents, let templates):
            contents.append(node)
            type = .extending(contents: contents, templates: templates)
        }
    }

    func append(_ text: String) {
        append(node: .text(value: text, slot: selectedSlot, replace: replacing))
    }

    func declare(slot name: String, using generator: LineGenerator? = nil) {
        append(node: .declare(name: name, generator: generator))
    }

    func include(_ storage: SwiftLineStorage, using generator: LineGenerator? = nil) {
        append(node: .include(storage: storage, generator: generator))
    }

    func add(slot name: String, using generator: LineGenerator? = nil) {
        guard let generator else { return }

        let previousSelectedSlot = selectedSlot
        let previouslyReplacing = replacing

        selectedSlot = name
        replacing = false

        generator(self)

        selectedSlot = previousSelectedSlot
        replacing = previouslyReplacing
    }

    func replace(slot name: String, using generator: LineGenerator? = nil) {
        guard let generator else { return }

        let previousSelectedSlot = selectedSlot
        let previouslyReplacing = replacing

        selectedSlot = name
        replacing = true

        generator(self)

        selectedSlot = previousSelectedSlot
        replacing = previouslyReplacing
    }

    func render() -> String {
        resolve([:]).compactMap(\.asString).joined()
    }

    func resolve(_ slots: [String: [LineCommand]]) -> [LineCommand] {
        let contents = if case let .extending(commands, templates) = type {
            transformExtends(commands, templates)
        } else {
            contents
        }
        let (flattenedLines, outerSlots) = resolveOuterSlots(contents, slots)
        let (preIncludeLines, innerSlots) = resolveInnerSlots(flattenedLines, outerSlots)
        let postIncludeLines = resolveIncludes(preIncludeLines, innerSlots)

        return postIncludeLines
    }

    func resolveOuterSlots(_ contents: [LineCommand], _ slots: [String: [LineCommand]]) -> (lines: [LineCommand], slots: [String: [LineCommand]]) {
        var consumedSlots: [String] = []
        var result: [LineCommand] = []

        guard !contents.isEmpty else { return (lines: [], slots: slots) }

        for command in contents {
            if case let .declare(name, generator) = command {
                if let item = slots[name] {
                    if !consumedSlots.contains(name) {
                        consumedSlots.append(name)
                    }
                    // A slot declaration right inside the default slot content would be ignored
                    // It is ok to have nested slot declaration if it is inside an include
                    result.append(contentsOf: item.filter { if case .declare = $0 { false } else { true } })
                } else if let generator {
                    let storage = SwiftLineStorage(normal: [])
                    generator(storage)
                    // A slot declaration right inside the default slot content would be ignored
                    // It is ok to have nested slot declaration if it is inside an include
                    result.append(contentsOf: storage.contents.filter { if case .declare = $0 { false } else { true } })
                }
            } else {
                result.append(command)
            }
        }

        let slots = slots.filter { !consumedSlots.contains($0.key) }

        return (lines: result, slots: slots)
    }

    func resolveInnerSlots(_ commands: [LineCommand], _ slots: [String: [LineCommand]]) -> (lines: [LineCommand], slots: [String: [LineCommand]]) {
        var slots = slots
        var result: [LineCommand] = []

        for command in commands {
            if case let .text(value, slot, replace) = command {
                if let name = slot {
                    var slot: [LineCommand] = if replace { [] } else if let slot = slots[name] { slot } else { [] }
                    slot.append(.text(value: value, slot: nil, replace: false))
                    slots[name] = slot
                } else {
                    result.append(command)
                }
            } else {
                result.append(command)
            }
        }

        return (lines: result, slots: slots)
    }

    func resolveIncludes(_ commands: [LineCommand], _ slots: [String: [LineCommand]]) -> [LineCommand] {
        var result: [LineCommand] = []

        for line in commands {
            if case let .include(storage, generator) = line {
                if let generator {
                    var slots = slots
                    let defaults = SwiftLineStorage(normal: [])
                    generator(defaults)

                    for content in defaults.contents {
                        if case let .text(value, slot, replace) = content {
                            let name = slot ?? "default"
                            var slot: [LineCommand] = if replace { [] } else if let slot = slots[name] { slot } else { [] }
                            slot.append(.text(value: value, slot: nil, replace: false))
                            slots[name] = slot
                        } else {
                            var slot: [LineCommand] = if let slot = slots["default"] { slot } else { [] }
                            slot.append(content)
                            slots["default"] = slot
                        }
                    }

                    result.append(contentsOf: storage.resolve(slots))
                } else {
                    result.append(contentsOf: storage.resolve(slots))
                }
            } else {
                result.append(line)
            }
        }

        return result
    }

    func transformExtends(_ commands: [LineCommand], _ templates: [SwiftLineStorage]) -> [LineCommand] {
        func generateGenerator(for commands: [LineCommand]) -> LineGenerator {
            func outerGenerator(_ storage: SwiftLineStorage) {
                switch storage.type {
                case .empty:
                    storage.type = .normal(contents: commands)
                case var .normal(contents):
                    contents.append(contentsOf: commands)
                    storage.type = .normal(contents: contents)
                case .extending(var contents, let templates):
                    contents.append(contentsOf: commands)
                    storage.type = .extending(contents: contents, templates: templates)
                }
            }

            return outerGenerator
        }

        guard let last = templates.last else { return [] }
        var lastInclude: LineCommand = .include(storage: last, generator: generateGenerator(for: commands))

        let remainingTemplates = templates.dropLast().reversed()

        guard !remainingTemplates.isEmpty else { return [lastInclude] }

        for template in remainingTemplates {
            lastInclude = .include(storage: template, generator: generateGenerator(for: [lastInclude]))
        }

        return [lastInclude]
    }

    var contents: [LineCommand] {
        switch type {
        case .empty:
            []
        case let .normal(contents):
            contents
        case let .extending(contents, _):
            contents
        }
    }

    convenience init(normal contents: [LineCommand]) {
        self.init()
        type = .normal(contents: contents)
    }
}

extension SwiftLineStorage.LineCommand {
    var asString: String? {
        if case let .text(value, slot, replace) = self {
            if slot == nil, !replace {
                value
            } else {
                nil
            }
        } else {
            nil
        }
    }
}
