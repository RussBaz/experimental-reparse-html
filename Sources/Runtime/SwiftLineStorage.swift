public final class SwiftLineStorage {
    public typealias LineGenerator = (SwiftLineStorage) -> Void

    enum StorageType {
        case empty
        case normal(contents: [SwiftLineCommand])
        case extending(contents: [SwiftLineCommand], templates: [SwiftLineStorage])
    }

    var type: StorageType = .empty

    var selectedSlot: String?

    public func extend(_ storage: SwiftLineStorage) {
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

    public func append(node: SwiftLineCommand) {
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

    public func append(_ text: String) {
        append(node: .text(value: text))
    }

    public func declare(slot name: String, using generator: LineGenerator? = nil) {
        if let generator {
            append(node: .startDeclareWithDefaults(name: name))
            generator(self)
            append(node: .endDeclareWithDefaults)
        } else {
            append(node: .declare(name: name))
        }
    }

    public func include(_ storage: SwiftLineStorage, using generator: LineGenerator? = nil) {
        if let generator {
            append(node: .startIncludeWithDefaults(storage: storage))
            generator(self)
            append(node: .endIncludeWithDefaults)
        } else {
            append(node: .include(storage: storage))
        }
    }

    public func add(slot name: String, using generator: LineGenerator) {
        let previousSelectedSlot = selectedSlot
        selectedSlot = name

        append(node: .select(slot: name))
        generator(self)
        append(node: .select(slot: previousSelectedSlot))

        selectedSlot = previousSelectedSlot
    }

    public func replace(slot name: String, using generator: LineGenerator) {
        let previousSelectedSlot = selectedSlot
        selectedSlot = name

        append(node: .select(slot: name))
        append(node: .clear)
        generator(self)
        append(node: .select(slot: previousSelectedSlot))

        selectedSlot = previousSelectedSlot
    }

    public func render() -> String {
        resolve(SwiftSlotStorage()).compactMap(\.asString).joined()
    }

    func resolve(_ slots: SwiftSlotStorage) -> [SwiftLineCommand] {
        slots.resolve()
        var lines = resolveOuterSlots(commands: contents, slots: slots)
        lines = resolveInnerSlots(commands: lines, slots: slots)
        lines = resolveIncludes(commands: lines, slots: slots)

        if case let .extending(_, templates) = type {
            lines = resolveExtends(contents: lines, templates: templates, slots: slots)
        }
        return lines
    }

    func resolveOuterSlots(commands: [SwiftLineCommand], slots: SwiftSlotStorage) -> [SwiftLineCommand] {
        var result: [SwiftLineCommand] = []
        var including = [true]

        var unavailable: [String] = []

        for command in commands {
            if case let .declare(name) = command {
                if unavailable.contains(name) {
                    ()
                } else if let slot = slots.find(name: name) {
                    slots.consume(name: name)
                    result.append(contentsOf: slot)
                }
            } else if case let .startDeclareWithDefaults(name: name) = command {
                if unavailable.contains(name) {
                    including.append(true)
                } else if let slot = slots.find(name: name) {
                    slots.consume(name: name)
                    result.append(contentsOf: slot)
                    including.append(false)
                } else {
                    including.append(true)
                }
                unavailable.append(name)
            } else if case .endDeclareWithDefaults = command {
                unavailable.removeLast()
                including.removeLast()
            } else {
                guard let last = including.last else { continue }

                if last {
                    result.append(command)
                }
            }
        }

        return result
    }

    func resolveInnerSlots(commands: [SwiftLineCommand], slots: SwiftSlotStorage) -> [SwiftLineCommand] {
        var result: [SwiftLineCommand] = []

        // Tmp data
        var selectedSlot: String?
        var insideInclude = 0
        var slot: [SwiftLineCommand] = []

        for command in commands {
            switch command {
            case .text, .declare, .startDeclareWithDefaults, .endDeclareWithDefaults, .include:
                if selectedSlot != nil {
                    slot.append(command)
                } else {
                    result.append(command)
                }
            case .startIncludeWithDefaults:
                if selectedSlot != nil {
                    slot.append(command)
                } else {
                    result.append(command)
                }
                insideInclude += 1
            case .endIncludeWithDefaults:
                if selectedSlot != nil {
                    slot.append(command)
                } else {
                    result.append(command)
                }
                insideInclude -= 1
            case let .select(slot: name):
                if insideInclude < 1 {
                    if let selectedSlot {
                        slots[selectedSlot] = slot
                    }

                    if let name, !name.isEmpty {
                        slot = slots[name]
                        selectedSlot = name
                    } else {
                        slot = []
                        selectedSlot = nil
                    }
                } else if selectedSlot != nil {
                    slot.append(command)
                } else {
                    result.append(command)
                }
            case .clear:
                if insideInclude < 1 {
                    if selectedSlot != nil {
                        slot = []
                    }
                } else if selectedSlot != nil {
                    slot.append(command)
                }
            case .noop:
                ()
            }
        }

        if let selectedSlot {
            slots[selectedSlot] = slot
        }

        return result
    }

    func resolveIncludes(commands: [SwiftLineCommand], slots: SwiftSlotStorage) -> [SwiftLineCommand] {
        var result: [SwiftLineCommand] = []

        var stashedIncludes: [(SwiftLineStorage, [SwiftLineCommand])] = []

        var currentIncludeStorage: SwiftLineStorage?
        var currentIncludeCommands: [SwiftLineCommand] = []

        for command in commands {
            if case let .include(storage) = command {
                if let _ = currentIncludeStorage {
                    currentIncludeCommands.append(contentsOf: storage.resolve(slots.innerSlots))
                } else {
                    result.append(contentsOf: storage.resolve(slots.innerSlots))
                }
            } else if case let .startIncludeWithDefaults(storage) = command {
                if let currentIncludeStorage {
                    stashedIncludes.append((currentIncludeStorage, currentIncludeCommands))
                }

                currentIncludeStorage = storage
                currentIncludeCommands = []
            } else if case .endIncludeWithDefaults = command {
                var innerCommands: [SwiftLineCommand]

                if let currentIncludeStorage {
                    let innerSlots = slots.innerSlots
                    innerSlots.unnamed = currentIncludeCommands
                    innerCommands = currentIncludeStorage.resolve(innerSlots)
                } else {
                    innerCommands = []
                }

                if let (storage, commands) = stashedIncludes.popLast() {
                    currentIncludeStorage = storage
                    currentIncludeCommands = commands
                    currentIncludeCommands.append(contentsOf: innerCommands)
                } else {
                    currentIncludeStorage = nil
                    currentIncludeCommands = []
                    result.append(contentsOf: innerCommands)
                }
            } else {
                if let _ = currentIncludeStorage {
                    currentIncludeCommands.append(command)
                } else {
                    result.append(command)
                }
            }
        }

        return result
    }

    func resolveExtends(contents: [SwiftLineCommand], templates: [SwiftLineStorage], slots: SwiftSlotStorage) -> [SwiftLineCommand] {
        guard !templates.isEmpty else { return contents }
        var defaultSlot = contents
        var slot = slots.innerSlots
        slot.unnamed = defaultSlot

        for template in templates.reversed() {
            defaultSlot = template.resolve(slot)
            slot = slot.innerSlots
            slot.unnamed = defaultSlot
        }

        return defaultSlot
    }

    var contents: [SwiftLineCommand] {
        switch type {
        case .empty:
            []
        case let .normal(contents):
            contents
        case let .extending(contents, _):
            contents
        }
    }

    public init() {}

    public convenience init(normal contents: [SwiftLineCommand]) {
        self.init()
        type = .normal(contents: contents)
    }
}
