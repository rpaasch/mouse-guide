import SwiftUI
import AppKit
import Carbon.HIToolbox

struct KeyboardShortcutRecorder: NSViewRepresentable {
    @Binding var keyCode: Int
    @Binding var modifiers: NSEvent.ModifierFlags

    func makeNSView(context: Context) -> ShortcutRecorderView {
        let view = ShortcutRecorderView()
        view.onShortcutRecorded = { recordedKeyCode, recordedModifiers in
            keyCode = recordedKeyCode
            modifiers = recordedModifiers
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderView, context: Context) {
        nsView.currentKeyCode = keyCode
        nsView.currentModifiers = modifiers
    }
}

class ShortcutRecorderView: NSView {
    var onShortcutRecorded: ((Int, NSEvent.ModifierFlags) -> Void)?
    var currentKeyCode: Int = CrosshairsSettings.Defaults.activationKeyCode
    var currentModifiers: NSEvent.ModifierFlags = CrosshairsSettings.Defaults.activationModifiers

    private var isRecording = false
    private var localMonitor: Any?
    private var clickMonitor: Any?
    private let button = NSButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        button.title = shortcutString()
        button.bezelStyle = .rounded
        button.target = self
        button.action = #selector(startRecording)
        button.translatesAutoresizingMaskIntoConstraints = false

        // Accessibility
        updateAccessibility()

        addSubview(button)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    private func updateAccessibility() {
        let shortcut = shortcutString()
        button.setAccessibilityLabel(String(format: LocalizedString.accessibilityShortcutRecorderLabel, shortcut))
        button.setAccessibilityHelp(LocalizedString.accessibilityShortcutRecorderHint)
        button.setAccessibilityRole(.button)
        button.setAccessibilityElement(true)
    }

    private func shortcutString() -> String {
        KeyboardShortcut.displayString(keyCode: currentKeyCode, modifiers: currentModifiers)
    }

    @objc private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        // The registered hot key would otherwise fire instead of being recorded.
        NotificationCenter.default.post(name: KeyboardShortcut.recordingChanged, object: true)
        button.title = LocalizedString.shortcutRecorderRecording
        button.highlight(true)

        // Update accessibility for recording state
        button.setAccessibilityLabel(LocalizedString.accessibilityShortcutRecorderRecording)

        // Start monitoring keyboard events
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handleKeyEvent(event)
            return nil // Consume the event
        }

        // Also add a click monitor to cancel recording if clicking elsewhere
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                if event.window != self?.window {
                    self?.stopRecording()
                }
                return event
            }
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard isRecording, event.type == .keyDown else { return }

        // Only the four real modifiers: arrow and function keys also carry
        // .function and .numericPad, which would leak into the label and menu.
        let modifiers = event.modifierFlags.intersection(KeyboardShortcut.relevantModifiers)
        let keyCode = Int(event.keyCode)

        if keyCode == kVK_Escape && modifiers.isEmpty {
            stopRecording()
            return
        }

        guard KeyboardShortcut.isAllowed(modifiers) else {
            // Say why, not just beep - the title is also what VoiceOver reads.
            NSSound.beep()
            button.title = LocalizedString.shortcutRecorderNeedsModifier
            button.setAccessibilityLabel(LocalizedString.shortcutRecorderNeedsModifier)
            NSAccessibility.post(
                element: button,
                notification: .announcementRequested,
                userInfo: [.announcement: LocalizedString.shortcutRecorderNeedsModifier]
            )
            return
        }

        // Update the shortcut
        currentKeyCode = keyCode
        currentModifiers = modifiers

        // Notify callback
        onShortcutRecorded?(keyCode, modifiers)

        // Stop recording
        stopRecording()

        // Update display
        button.title = shortcutString()
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        NotificationCenter.default.post(name: KeyboardShortcut.recordingChanged, object: false)
        button.highlight(false)
        button.title = shortcutString()

        // Update accessibility to reflect the new shortcut
        updateAccessibility()

        // Remove keyboard monitor
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        // Remove click monitor
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            stopRecording()
        }
    }
}
