public final class SwiftSlotStorage {
    var unnamed: [SwiftLineCommand] = []
    var named: [String: [SwiftLineCommand]] = [:]

    var consumed: [String] = []

    func consume(name: String) {
        if !consumed.contains(name) {
            consumed.append(name)
        }
    }

    func resolve() {
        var result: [SwiftLineCommand] = []

        var selectedSlot: String?

        for command in unnamed {
            switch command {
            case .text:
                if let selectedSlot {
                    var slot = self[selectedSlot]
                    slot.append(command)
                    self[selectedSlot] = slot
                } else {
                    result.append(command)
                }
            case .declare, .startDeclareWithDefaults, .endDeclareWithDefaults:
                ()
            case .include, .startIncludeWithDefaults, .endIncludeWithDefaults:
                ()
            case let .select(slot):
                if slot == "default" {
                    selectedSlot = nil
                } else {
                    selectedSlot = slot
                }
            case .clear:
                if let selectedSlot {
                    self[selectedSlot] = []
                } else {
                    result = []
                }
            case .noop:
                ()
            }

            unnamed = result
        }
    }

    func find(name: String?) -> [SwiftLineCommand]? {
        if name == "default" {
            if unnamed.isEmpty {
                nil
            } else {
                unnamed
            }
        } else if let name {
            if let slot = named[name] {
                slot
            } else {
                nil
            }
        } else {
            if unnamed.isEmpty {
                nil
            } else {
                unnamed
            }
        }
    }

    var innerSlots: SwiftSlotStorage {
        let result = SwiftSlotStorage()
        result.named = named.filter { !consumed.contains($0.key) }
        return result
    }

    subscript(index: String?) -> [SwiftLineCommand] {
        get {
            if index == "default" {
                unnamed
            } else if let index {
                named[index] ?? []
            } else {
                []
            }
        }

        set {
            if index == "default" {
                unnamed = newValue
            } else if let index {
                named[index] = newValue
            } else {
                unnamed = newValue
            }
        }
    }
}
