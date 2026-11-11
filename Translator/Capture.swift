import AppKit
import ApplicationServices

/// Reads the Selection by sending ⌘C, then restores the previous clipboard.
enum Capture {
    @MainActor private(set) static var diagnostic = "Capture has not run."
    @MainActor
    static func selection() async -> String? {
        // Wait for the user to release ⌥ so it does not modify the copy command.
        for _ in 0..<100 {
            if !CGEventSource.flagsState(.combinedSessionState).contains(.maskAlternate) { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        guard !CGEventSource.flagsState(.combinedSessionState).contains(.maskAlternate) else {
            diagnostic = "Option still held after 1 second. Release ⌥T promptly and retry."
            return nil
        }
        let targetApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown app"
        diagnostic = "Copy requested from \(targetApp)."
        let pb = NSPasteboard.general
        let saved =
            pb.pasteboardItems?.map { item in
                item.types.reduce(into: [NSPasteboard.PasteboardType: Data]()) { $0[$1] = item.data(forType: $1) }
            } ?? []
        let before = pb.changeCount
        let source = CGEventSource(stateID: .privateState)
        guard let commandDown = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: true),
            let cDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true),
            let cUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false),
            let commandUp = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: false)
        else {
            diagnostic = "Cannot create copy events."
            return nil
        }
        commandDown.type = .flagsChanged
        commandDown.flags = .maskCommand
        cDown.flags = .maskCommand
        cUp.flags = .maskCommand
        commandUp.type = .flagsChanged
        commandUp.flags = []
        // Some apps need modifier transitions, not just flags on the C events.
        // Always release Command, including if the task is cancelled.
        await sendCopyChord(commandDown, cDown, cUp, commandUp)
        for _ in 0..<100 {
            if pb.changeCount != before { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        guard pb.changeCount != before else {
            diagnostic =
                "No clipboard update within 1 second. Target: \(targetApp). Event posting allowed: \(CGPreflightPostEventAccess())."
            return nil
        }
        let copiedVersion = pb.changeCount
        let text = pb.string(forType: .string)
        let restored = saved.map { data in
            let item = NSPasteboardItem()
            for (type, bytes) in data { item.setData(bytes, forType: type) }
            return item
        }
        // Do not replace a newer clipboard value while reading promised data.
        if pb.changeCount == copiedVersion {
            pb.clearContents()
            if !restored.isEmpty { pb.writeObjects(restored) }
        }
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            diagnostic = "Clipboard changed but has no nonempty text. Target: \(targetApp)."
            return nil
        }
        diagnostic = "Capture succeeded. Target: \(targetApp)."
        return text
    }

    @MainActor
    private static func sendCopyChord(
        _ commandDown: CGEvent, _ cDown: CGEvent,
        _ cUp: CGEvent, _ commandUp: CGEvent
    ) async {
        defer { commandUp.post(tap: .cgSessionEventTap) }
        commandDown.post(tap: .cgSessionEventTap)
        try? await Task.sleep(for: .milliseconds(20))
        cDown.post(tap: .cgSessionEventTap)
        try? await Task.sleep(for: .milliseconds(20))
        cUp.post(tap: .cgSessionEventTap)
        try? await Task.sleep(for: .milliseconds(20))
    }
}
