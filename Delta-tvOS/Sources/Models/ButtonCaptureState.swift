/// Captures a new press and completes only when that particular input is released.
/// Other held buttons or stick directions must not prevent saving the mapping.
struct ButtonCaptureState<Key: Hashable, Button> {
    enum Event {
        case detected(Button)
        case completed(Button)
    }

    private var blocked: Set<Key>
    private var pending: (key: Key, button: Button)?
    private var completed = false

    var capturedKey: Key? { pending?.key }

    init(initiallyPressed: [Key]) {
        blocked = Set(initiallyPressed)
    }

    mutating func sample(_ pressed: [(key: Key, button: Button)]) -> Event? {
        guard !completed else { return nil }
        let keys = Set(pressed.map { $0.key })
        blocked.formIntersection(keys)
        if let pending {
            guard !keys.contains(pending.key) else { return nil }
            completed = true
            return .completed(pending.button)
        }
        if let newPress = pressed.first(where: { !blocked.contains($0.key) }) {
            pending = newPress
            return .detected(newPress.button)
        }
        return nil
    }
}
