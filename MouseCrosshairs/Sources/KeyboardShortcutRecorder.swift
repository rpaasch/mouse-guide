import SwiftUI
import AppKit

struct KeyboardShortcutRecorder: NSViewRepresentable {
    @Binding var key: String
    @Binding var modifiers: NSEvent.ModifierFlags

    func makeNSView(context: Context) -> ShortcutRecorderView {
        let view = ShortcutRecorderView()
        view.onShortcutRecorded = { recordedKey, recordedModifiers in
            key = recordedKey
            modifiers = recordedModifiers
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderView, context: Context) {
        nsView.currentKey = key
        nsView.currentModifiers = modifiers
    }
}

class ShortcutRecorderView: NSView {
    var onShortcutRecorded: ((String, NSEvent.ModifierFlags) -> Void)?
    var currentKey: String = "L"
    var currentModifiers: NSEvent.ModifierFlags = [.shift, .control]

    private var isRecording = false
    private var localMonitor: Any?
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

        addSubview(button)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    private func shortcutString() -> String {
        var parts: [String] = []
        if currentModifiers.contains(.control) { parts.append("⌃") }
        if currentModifiers.contains(.option) { parts.append("⌥") }
        if currentModifiers.contains(.shift) { parts.append("⇧") }
        if currentModifiers.contains(.command) { parts.append("⌘") }

        if !parts.isEmpty {
            return parts.joined() + currentKey
        }
        return "Klik for at optage..."
    }

    @objc private func startRecording() {
        isRecording = true
        button.title = "⌨️ Tryk tastekombination..."
        button.highlight(true)

        // Start monitoring keyboard events
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handleKeyEvent(event)
            return nil // Consume the event
        }

        // Also add a click monitor to cancel recording if clicking elsewhere
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                if event.window != self?.window {
                    self?.stopRecording()
                }
                return event
            }
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard isRecording else { return }

        // Get the key
        guard let characters = event.charactersIgnoringModifiers?.uppercased(),
              !characters.isEmpty,
              event.type == .keyDown else { return }

        let key = characters
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Require at least one modifier
        guard !modifiers.intersection([.command, .option, .control, .shift]).isEmpty else {
            NSSound.beep()
            return
        }

        // Update the shortcut
        currentKey = key
        currentModifiers = modifiers

        // Notify callback
        onShortcutRecorded?(key, modifiers)

        // Stop recording
        stopRecording()

        // Update display
        button.title = shortcutString()
    }

    private func stopRecording() {
        isRecording = false
        button.highlight(false)
        button.title = shortcutString()

        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            stopRecording()
        }
    }
}
