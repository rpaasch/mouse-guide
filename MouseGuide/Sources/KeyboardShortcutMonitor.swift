import AppKit
import Carbon.HIToolbox

/// Registers the show/hide shortcut as a system-wide hot key.
///
/// `RegisterEventHotKey` works in the App Sandbox and needs no permission. The
/// previous version watched every keystroke with a global NSEvent monitor,
/// which requires Input Monitoring - App Review rejected that under guideline
/// 2.4.5 in August 2026.
///
/// A hot key takes its combination away from the frontmost app, which is why
/// the recorder only accepts combinations with ⌘ or ⌃ - see
/// `KeyboardShortcut.isAllowed`.
class KeyboardShortcutMonitor {
    /// False when macOS refuses the combination. It does not catch another app
    /// holding the same one: measured on macOS 27.2, both registrations succeed.
    private(set) var isRegistered = false

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var settings = CrosshairsSettings.shared
    weak var appDelegate: AppDelegate?

    private static let hotKeyID = EventHotKeyID(signature: 0x43534C4E, id: 1)  // 'CSLN'

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        installHandler()
        register()

        // The recorder needs the current combination to reach it, not us.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(recordingChanged(_:)),
            name: KeyboardShortcut.recordingChanged,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        unregister()
        if let handlerRef = handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    private func installHandler() {
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            Unmanaged<KeyboardShortcutMonitor>.fromOpaque(userData).takeUnretainedValue().hotKeyPressed()
            return noErr
        }, 1, &pressed, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }

    private func register() {
        unregister()
        let status = RegisterEventHotKey(
            UInt32(settings.activationKeyCode),
            KeyboardShortcut.carbonModifiers(settings.activationModifiers),
            Self.hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        isRegistered = status == noErr
        if isRegistered {
            NSLog("✅ Shortcut registered: \(KeyboardShortcut.displayString(keyCode: settings.activationKeyCode, modifiers: settings.activationModifiers))")
        } else {
            NSLog("⚠️ Shortcut could not be registered (OSStatus \(status))")
        }
    }

    private func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
        isRegistered = false
    }

    @objc private func recordingChanged(_ notification: Notification) {
        if notification.object as? Bool == true {
            unregister()
        } else {
            register()
        }
    }

    private func hotKeyPressed() {
        NSSound.beep()
        appDelegate?.toggleCrosshairs()
    }
}

/// Rules and labels for the show/hide shortcut, shared by the hot key, the
/// recorder and the menu.
enum KeyboardShortcut {
    static let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    /// Posted by the recorder with `true` when it starts listening and `false`
    /// when it stops.
    static let recordingChanged = Notification.Name("ShortcutRecordingChanged")

    /// A hot key swallows its combination in every app. Without ⌘ or ⌃ that
    /// would take ordinary typing away: ⇧L is a capital L, and ⌥ combinations
    /// type characters on Mac layouts (⌥2 is @ on a Danish keyboard).
    static func isAllowed(_ modifiers: NSEvent.ModifierFlags) -> Bool {
        !modifiers.intersection([.command, .control]).isEmpty
    }

    static func carbonModifiers(_ modifiers: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if modifiers.contains(.command) { carbon |= UInt32(cmdKey) }
        if modifiers.contains(.option) { carbon |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbon |= UInt32(controlKey) }
        if modifiers.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }

    /// "⌃⇧L" - modifiers in the order macOS menus use.
    static func displayString(keyCode: Int, modifiers: NSEvent.ModifierFlags) -> String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + keyName(for: keyCode)
    }

    /// The key's label on the current keyboard layout. A hot key is bound to a
    /// physical key, so the label is looked up rather than stored - on AZERTY
    /// or Dvorak the key at the US "L" position is not labelled L.
    static func keyName(for keyCode: Int) -> String {
        if let name = specialKeys[keyCode] { return name }
        return character(for: keyCode)?.uppercased() ?? "#\(keyCode)"
    }

    /// The character an NSMenuItem needs as key equivalent, or "" when the key
    /// has no plain character (arrows, function keys).
    static func menuKeyEquivalent(for keyCode: Int) -> String {
        guard specialKeys[keyCode] == nil else { return "" }
        return character(for: keyCode)?.lowercased() ?? ""
    }

    private static let specialKeys: [Int: String] = [
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "␣", kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦", kVK_Escape: "⎋",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12", kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15",
        kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]

    private static func character(for keyCode: Int) -> String? {
        // Input methods such as Japanese carry no layout data of their own.
        guard let layout = layoutData(TISCopyCurrentKeyboardLayoutInputSource())
                ?? layoutData(TISCopyCurrentASCIICapableKeyboardLayoutInputSource())
        else { return nil }

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = layout.withUnsafeBytes { raw -> OSStatus in
            guard let base = raw.baseAddress else { return OSStatus(paramErr) }
            return UCKeyTranslate(
                base.assumingMemoryBound(to: UCKeyboardLayout.self),
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysMask),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
        }
        guard status == noErr, length > 0 else { return nil }

        let string = String(utf16CodeUnits: chars, count: length)
        let printable = string.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        return printable.isEmpty ? nil : printable
    }

    private static func layoutData(_ source: Unmanaged<TISInputSource>?) -> Data? {
        guard let source = source?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        return Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
    }
}
