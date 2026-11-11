import AppKit
import ApplicationServices

/// AX coordinates use a top-left origin. AppKit uses the main display's bottom-left origin.
enum SelectionBounds {
    static func appKitRect(from rect: CGRect, mainDisplayTop: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: mainDisplayTop - rect.maxY, width: rect.width, height: rect.height)
    }

    @MainActor static func current() -> CGRect? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        var focused: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
            let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return nil }
        let element = unsafeDowncast(focused, to: AXUIElement.self)
        var range: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &range) == .success,
            let range, CFGetTypeID(range) == AXValueGetTypeID()
        else { return nil }
        let rangeValue = unsafeDowncast(range, to: AXValue.self)
        var selectedRange = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &selectedRange), selectedRange.length > 0 else { return nil }
        var bounds: CFTypeRef?
        guard
            AXUIElementCopyParameterizedAttributeValue(
                element, kAXBoundsForRangeParameterizedAttribute as CFString,
                range, &bounds) == .success,
            let bounds, CFGetTypeID(bounds) == AXValueGetTypeID()
        else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(unsafeDowncast(bounds, to: AXValue.self), .cgRect, &rect),
            rect.origin.x.isFinite, rect.origin.y.isFinite, rect.width.isFinite, rect.height.isFinite,
            rect.width > 0, rect.height > 0,
            let mainScreen = NSScreen.screens.first
        else { return nil }
        return appKitRect(from: rect, mainDisplayTop: mainScreen.frame.maxY)
    }
}

enum PopupPosition: String, CaseIterable {
    case pointer
    case belowSelection

    static let defaultsKey = "popupPosition"
    static var saved: Self {
        Self(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .pointer
    }

    var label: String {
        self == .pointer ? "At pointer" : "Below selected text"
    }

    func origin(size: CGSize, pointer: CGPoint, selection: CGRect?, visibleFrame: CGRect) -> CGPoint {
        let selection = self == .belowSelection ? selection : nil
        let anchor = selection.map { CGPoint(x: $0.minX, y: $0.minY) } ?? pointer
        return CGPoint(
            x: max(visibleFrame.minX, min(anchor.x, visibleFrame.maxX - size.width)),
            y: max(visibleFrame.minY, min(anchor.y - size.height - 12, visibleFrame.maxY - size.height))
        )
    }
}
