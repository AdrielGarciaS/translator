import Carbon.HIToolbox

/// Registers only the two translation shortcuts. Does not monitor other keys.
@MainActor
enum Hotkey {
    enum Shortcut: UInt32, CaseIterable {
        case selection = 1
        case typed = 2

        var modifiers: UInt32 {
            switch self {
            case .selection: UInt32(optionKey)
            case .typed: UInt32(optionKey | shiftKey)
            }
        }

        var label: String { self == .selection ? "⌥T" : "⌥⇧T" }
    }

    private static var actions: [Shortcut: () -> Void] = [:]
    private static var references: [EventHotKeyRef] = []
    private(set) static var failures: [Shortcut: OSStatus] = [:]

    static func register(selection: @escaping () -> Void, typed: @escaping () -> Void) {
        actions = [.selection: selection, .typed: typed]
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ in
                var identifier = EventHotKeyID()
                guard
                    GetEventParameter(
                        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                        nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier) == noErr,
                    identifier.signature == 0x5452_4E53
                else { return OSStatus(eventNotHandledErr) }
                let rawID = identifier.id
                Task { @MainActor in
                    if let shortcut = Hotkey.Shortcut(rawValue: rawID) { Hotkey.actions[shortcut]?() }
                }
                return noErr
            }, 1, &spec, nil, nil)
        guard status == noErr else {
            failures = Dictionary(uniqueKeysWithValues: Shortcut.allCases.map { ($0, status) })
            return
        }
        for shortcut in Shortcut.allCases {
            var reference: EventHotKeyRef?
            let result = RegisterEventHotKey(
                UInt32(kVK_ANSI_T), shortcut.modifiers,
                EventHotKeyID(signature: 0x5452_4E53, id: shortcut.rawValue),
                GetApplicationEventTarget(), 0, &reference)
            if result != noErr { failures[shortcut] = result }
            if let reference { references.append(reference) }
        }
    }
}
