import SwiftUI
import AppKit

class MouseTracker: ObservableObject {
    @Published var position: CGPoint = .zero
    @Published var currentScreen: NSScreen?
}

// Manager class to handle multiple windows (one per screen)
class CrosshairsWindowManager {
    private var windows: [NSWindow] = []
    private var trackingTimer: Timer?
    private var mouseTracker = MouseTracker()
    private var settings = CrosshairsSettings.shared
    private var targetPosition: CGPoint = .zero
    private var lastUpdateTime: TimeInterval = 0
    private var lastMouseMoveTime: TimeInterval = 0
    private var isFirstFrame = true  // Skip gliding delay on first frame
    private var debugFrameCount = 0  // For debug printing
    private var shownAt: TimeInterval = 0          // systemUptime when show() last ran
    private var lastTypingCheck: TimeInterval = 0

    // Visibility is driven by independent reasons to hide. None of them may
    // touch the windows directly - see applyVisibility().
    private var hiddenByTyping = false
    private var hiddenByFullscreen = false
    private var windowsVisible = true

    private var shouldBeVisible: Bool { !hiddenByTyping && !hiddenByFullscreen }

    // MARK: - Typing detection

    /// Hides the crosshair for a moment after a key press, so it does not sit
    /// on top of the text being written.
    ///
    /// Reads only how long ago the last key went down - never which key - and
    /// does not listen to the keyboard, so it needs no Input Monitoring.
    /// Listening is what App Review rejected in August 2026 (guideline 2.4.5).
    /// Measured from a sandboxed build without that permission: the value is
    /// the real one, no prompt appears, and the call adds no permission check
    /// of its own. tccd does log silent Input Monitoring checks at launch, but
    /// a plain windowed app with no such call gets exactly the same ones.
    private func updateTypingState(now: TimeInterval) {
        guard settings.autoHideWhileTyping else {
            hiddenByTyping = false
            return
        }
        guard now - lastTypingCheck >= 0.05 else { return }
        lastTypingCheck = now

        let sinceKeyDown = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        // The shortcut that showed the crosshair is itself a key press. It must
        // not count as typing, or the crosshair would vanish as it appears.
        let pressedSinceShown = sinceKeyDown < now - shownAt
        hiddenByTyping = pressedSinceShown && sinceKeyDown < settings.autoHideTypingDelay
    }

    // MARK: - Fullscreen detection

    private var lastFullscreenCheck: TimeInterval = 0

    /// Detects "an app owns the whole screen and the mouse is sitting still",
    /// which is when macOS hides the pointer - a video player, in practice.
    ///
    /// The pointer's hidden state itself cannot be read: CGCursorIsVisible() is
    /// gone from the SDK, the equivalents are private, and NSCursor.currentSystem
    /// reports which cursor is set rather than whether one is visible (measured:
    /// it never goes nil). So detect the situation instead.
    ///
    /// Two signals together, because either alone is ambiguous. Native
    /// fullscreen puts the window on its own Space, so no other app has an
    /// on-screen window - that is what separates it from a merely zoomed
    /// window, which on this machine measured 1350x846 against a fullscreen
    /// 1352x849. The exact size match then confirms it.
    private func updateFullscreenState(now: TimeInterval) {
        guard now - lastFullscreenCheck >= 0.5 else { return }   // window enumeration is costly
        lastFullscreenCheck = now

        guard settings.autoHideInFullscreen else {
            hiddenByFullscreen = false
            return
        }

        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        hiddenByFullscreen = idle >= 3.0 && Self.aWindowOwnsTheScreen()
    }

    private static func aWindowOwnsTheScreen() -> Bool {
        guard let screen = NSScreen.main,
              let infos = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return false }

        var owners = Set<String>()
        var matchesScreen = false
        let target = screen.visibleFrame.size

        for info in infos where (info[kCGWindowLayer as String] as? Int) == 0 {
            if let owner = info[kCGWindowOwnerName as String] as? String {
                owners.insert(owner)
            }
            if let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
               bounds["Width"] == target.width, bounds["Height"] == target.height {
                matchesScreen = true
            }
        }

        // Exactly one app on screen means we are on a fullscreen Space
        return owners.count == 1 && matchesScreen
    }

    /// The only place that orders the overlay windows on or off screen.
    ///
    /// Typing is currently the sole reason to hide, but the indirection stays:
    /// it is what keeps re-seating the mouse tracker in one place. Position
    /// updates are paused while hidden, so without that the crosshair would
    /// reappear at a stale location and then glide to the pointer.
    private func applyVisibility() {
        guard windowsVisible != shouldBeVisible else { return }
        windowsVisible = shouldBeVisible
        NSLog("👁 Crosshair \(windowsVisible ? "shown" : "hidden") - typing: \(hiddenByTyping), fullscreen: \(hiddenByFullscreen)")

        if windowsVisible {
            let currentMouseLocation = NSEvent.mouseLocation
            mouseTracker.position = currentMouseLocation
            targetPosition = currentMouseLocation
            isFirstFrame = true   // skip gliding delay so it appears immediately
            lastUpdateTime = 0    // treat next frame as the first
            for window in windows {
                window.orderFrontRegardless()
            }
        } else {
            for window in windows {
                window.orderOut(nil)
            }
        }
    }

    func show() {
        NSLog("🚀 show() ENTRY - calling hide() first")
        hide() // Clean up any existing windows
        NSLog("✅ hide() completed successfully")
        shownAt = ProcessInfo.processInfo.systemUptime

        let screensToUse = NSScreen.screens

        // Create a window for each screen
        NSLog("📍 Creating windows for \(screensToUse.count) screens")
        for screen in screensToUse {
            NSLog("   Creating window for screen: \(screen.frame)")
            let window = createWindow(for: screen)
            windows.append(window)
            window.orderFrontRegardless()
        }

        NSLog("📐 Created \(windows.count) crosshairs windows")
        for (index, screen) in screensToUse.enumerated() {
            NSLog("   Screen \(index): \(screen.frame)")
        }

        // Start tracking mouse
        NSLog("🎯 About to call startTracking()")
        startTracking()
        NSLog("✅ startTracking() completed")

        // Listen for screen configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Listen for settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: NSNotification.Name("CrosshairsSettingsChanged"),
            object: nil
        )
    }

    @objc private func settingsChanged() {
        NSLog("⚙️ Settings changed - updating crosshairs")

        // Restart tracking to apply gliding changes
        stopTracking()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.startTracking()
        }

        // Redraw all windows with new settings
        for window in windows {
            if let contentView = window.contentView {
                contentView.setNeedsDisplay(contentView.bounds)
            }
        }
    }

    func hide() {
        NSLog("🔴 hide() called - cleaning up \(windows.count) windows")
        stopTracking()

        // Reset visibility state so the next show() starts from a clean slate
        hiddenByTyping = false
        windowsVisible = true

        // Stop display links on all views BEFORE removing windows
        for window in windows {
            if let view = window.contentView as? CrosshairsNativeView {
                view.stopDisplayLink()
            }
            window.orderOut(nil)
        }
        windows.removeAll()
        NotificationCenter.default.removeObserver(self)
        NSLog("🔴 hide() completed")
    }

    private func createWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )

        // Configure window to be transparent overlay
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.cursorWindow)) - 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.hasShadow = false

        // Create native view instead of SwiftUI
        // IMPORTANT: Use screen.frame for both window AND view to match coordinate spaces
        let nativeView = CrosshairsNativeView(
            mouseTracker: mouseTracker,
            settings: CrosshairsSettings.shared,
            screenFrame: screen.frame
        )
        // Set view frame to match window's content rect exactly
        nativeView.frame = NSRect(origin: .zero, size: screen.frame.size)
        window.contentView = nativeView

        // Force window and view to update their frames
        window.setFrame(screen.frame, display: true)

        print("   📺 Screen \(screen.frame): view.frame=\(nativeView.frame), window.frame=\(window.frame)")
        print("      backingScaleFactor=\(window.backingScaleFactor)")

        return window
    }

    @objc private func screenConfigurationChanged() {
        // Recreate windows for new screen configuration
        show()
    }

    private func startTracking() {
        NSLog("🎯 startTracking() called")
        // Initialize position and timing
        let currentTime = Date().timeIntervalSince1970
        let mouseLocation = NSEvent.mouseLocation
        mouseTracker.position = mouseLocation
        targetPosition = mouseLocation
        lastUpdateTime = 0  // Set to 0 so first frame jumps to position
        lastMouseMoveTime = currentTime
        isFirstFrame = true  // Skip gliding delay on first frame
        debugFrameCount = 0  // Reset debug counter
        NSLog("   Mouse position: \(mouseLocation)")
        NSLog("   isFirstFrame: \(isFirstFrame)")

        trackingTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updateCursorPosition()
        }
        RunLoop.main.add(trackingTimer!, forMode: .common)
        NSLog("   ✅ Timer created and added to RunLoop")
    }

    private func stopTracking() {
        trackingTimer?.invalidate()
        trackingTimer = nil
    }

    private func updateCursorPosition() {
        updateFullscreenState(now: Date().timeIntervalSince1970)
        updateTypingState(now: ProcessInfo.processInfo.systemUptime)
        applyVisibility()

        // Don't update position while hidden - applyVisibility() re-seats it
        guard windowsVisible else { return }

        // ALWAYS log first call to verify timer is working
        if debugFrameCount == 0 {
            NSLog("🚨 updateCursorPosition() FIRST CALL - timer IS working!")
        }

        let currentTime = Date().timeIntervalSince1970
        let realMouseLocation = NSEvent.mouseLocation

        // Debug print for first few frames
        if debugFrameCount < 5 {
            NSLog("🖱️ updateCursorPosition() frame \(debugFrameCount): mouse=\(realMouseLocation), isFirstFrame=\(isFirstFrame)")
            debugFrameCount += 1
        }

        // Check if mouse has moved since last frame
        let mouseMoved = targetPosition.x != realMouseLocation.x || targetPosition.y != realMouseLocation.y
        if mouseMoved {
            lastMouseMoveTime = currentTime
        }

        // Update target position
        targetPosition = realMouseLocation

        if settings.glidingEnabled && !isFirstFrame {
            // Time since mouse last moved
            let timeSinceMouseMove = currentTime - lastMouseMoveTime

            // Only start gliding after the delay has passed
            if timeSinceMouseMove >= settings.glidingDelay {
                // Smooth gliding interpolation
                let deltaTime = currentTime - lastUpdateTime
                if lastUpdateTime == 0 {
                    // First frame - jump to position
                    mouseTracker.position = realMouseLocation
                } else {
                    // Interpolate smoothly using glidingSpeed (0.0 = slow, 1.0 = instant)
                    let speed = CGFloat(settings.glidingSpeed)
                    let t = min(1.0, speed * CGFloat(deltaTime) * 10.0) // Scale for reasonable speeds

                    let currentPos = mouseTracker.position
                    let newX = currentPos.x + (targetPosition.x - currentPos.x) * t
                    let newY = currentPos.y + (targetPosition.y - currentPos.y) * t

                    mouseTracker.position = CGPoint(x: newX, y: newY)
                }
            }
            // If delay hasn't passed yet, keep crosshair at current position (don't update)
        } else {
            // No gliding OR first frame - direct update
            mouseTracker.position = realMouseLocation
            isFirstFrame = false  // Clear flag after first frame
        }

        lastUpdateTime = currentTime

        // Determine which screen the mouse is on
        mouseTracker.currentScreen = NSScreen.screens.first { screen in
            screen.frame.contains(mouseTracker.position)
        }
    }

    deinit {
        hide()
    }
}

// Legacy support - wrap the manager in a window-like interface
class CrosshairsWindow: NSWindow {
    private static var manager: CrosshairsWindowManager?

    init() {
        // Create a dummy window (won't be used)
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Use the manager instead
        if CrosshairsWindow.manager == nil {
            CrosshairsWindow.manager = CrosshairsWindowManager()
        }
        CrosshairsWindow.manager?.show()
    }

    override func orderOut(_ sender: Any?) {
        CrosshairsWindow.manager?.hide()
        super.orderOut(sender)
    }

}

// Wrapper class to safely pass weak reference to CVDisplayLink callback
private class DisplayLinkContext {
    weak var view: CrosshairsNativeView?
    init(view: CrosshairsNativeView) { self.view = view }
}

// Native NSView implementation for better control over multi-monitor setups
class CrosshairsNativeView: NSView {
    private var mouseTracker: MouseTracker
    private var settings: CrosshairsSettings
    private var screenFrame: NSRect
    private var displayLink: CVDisplayLink?
    private var settingsObserver: Any?
    private var displayLinkContext: UnsafeMutablePointer<DisplayLinkContext>?

    // Hysteresis state for color adaptation - prevents flickering
    // true = currently using light crosshair, false = currently using dark crosshair
    private var isUsingLightCrosshair: Bool = true

    // The last capture of the background. Every capture makes macOS check the
    // Screen Recording permission, so draws reuse this until a new one is due.
    private var cachedBrightness: CGFloat?
    private var lastSampleTime: TimeInterval = 0
    private var lastSamplePosition: CGPoint = .zero

    private static let sampleSize: CGFloat = 20
    private static let sampleInterval: TimeInterval = 0.1
    private static let movingSampleInterval: TimeInterval = 1.0 / 30.0

    init(mouseTracker: MouseTracker, settings: CrosshairsSettings, screenFrame: NSRect) {
        self.mouseTracker = mouseTracker
        self.settings = settings
        self.screenFrame = screenFrame
        super.init(frame: .zero)

        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor

        // Disable autoresizing to maintain exact size
        self.autoresizingMask = []
        self.translatesAutoresizingMaskIntoConstraints = false

        // Listen for settings changes
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .init("CrosshairsSettingsChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.needsDisplay = true
        }

        // Setup display link for smooth 60fps updates
        // Use a context wrapper with weak reference to prevent crash on deallocation
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        if let displayLink = displayLink {
            // Allocate context on heap so it survives beyond init
            let context = DisplayLinkContext(view: self)
            displayLinkContext = UnsafeMutablePointer<DisplayLinkContext>.allocate(capacity: 1)
            displayLinkContext?.initialize(to: context)

            CVDisplayLinkSetOutputCallback(displayLink, { (_, _, _, _, _, userInfo) -> CVReturn in
                guard let userInfo = userInfo else { return kCVReturnSuccess }
                let context = userInfo.assumingMemoryBound(to: DisplayLinkContext.self).pointee
                // Use weak reference - safely returns nil if view was deallocated
                guard let view = context.view else { return kCVReturnSuccess }
                DispatchQueue.main.async { [weak view] in
                    view?.needsDisplay = true
                }
                return kCVReturnSuccess
            }, displayLinkContext)
            CVDisplayLinkStart(displayLink)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func stopDisplayLink() {
        // Call this before removing view from window
        if let dl = displayLink {
            CVDisplayLinkStop(dl)
            displayLink = nil
        }
        // Clean up the context pointer
        if let context = displayLinkContext {
            context.deinitialize(count: 1)
            context.deallocate()
            displayLinkContext = nil
        }
    }

    deinit {
        // Stop display link FIRST to prevent callbacks during deallocation
        stopDisplayLink()
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // Make view use top-left coordinate system (flipped)
    override var isFlipped: Bool {
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let mouseLocation = mouseTracker.position

        // Check if mouse is on this screen
        guard screenFrame.contains(mouseLocation) else { return }

        // Convert to view coordinates
        // macOS screen coordinates: origin at bottom-left, Y goes up
        // Flipped NSView coordinates: origin at top-left, Y goes down
        let center = CGPoint(
            x: mouseLocation.x - screenFrame.minX,
            y: screenFrame.maxY - mouseLocation.y  // Flip Y coordinate
        )

        // Draw crosshairs
        drawCrosshairs(in: context, center: center, viewSize: bounds.size)
    }
    
    private func drawCrosshairs(in context: CGContext, center: CGPoint, viewSize: CGSize) {
        let thickness = CGFloat(settings.thickness)
        let edgePointerThickness = CGFloat(settings.edgePointerThickness)
        let centerRadius = CGFloat(settings.centerRadius)
        let baseBorderSize = CGFloat(settings.borderSize)

        // No logging in here: this runs on every display-link tick, on every
        // screen. NSLog serialises a string and hits the unified log each time,
        // which at 120 Hz across two displays is hundreds of writes a second.

        // Get colors
        let crosshairColor: NSColor
        let borderColor: NSColor

        // Effective border size - enforce minimum 1px when color adaptation is active
        let effectiveBorderSize: CGFloat

        // Capturing the screen without permission makes macOS show its own prompt,
        // which must only ever follow the user switching this on in Settings. If the
        // permission is gone, draw the chosen colors; Settings explains why.
        if settings.invertColors && settings.hasScreenRecordingPermission() {
            // Dynamic color inversion based on background with hysteresis to prevent flickering
            let brightness = backgroundBrightness(at: mouseTracker.position)

            // Hysteresis thresholds to prevent flickering at boundary
            let switchToDarkThreshold: CGFloat = 0.6   // Switch to dark crosshair only if clearly light
            let switchToLightThreshold: CGFloat = 0.4  // Switch to light crosshair only if clearly dark

            // Update color state with hysteresis
            if brightness > switchToDarkThreshold {
                // Clearly light background → use dark crosshair
                isUsingLightCrosshair = false
            } else if brightness < switchToLightThreshold {
                // Clearly dark background → use light crosshair
                isUsingLightCrosshair = true
            }
            // If between 0.4-0.6, keep current state (hysteresis zone)

            if isUsingLightCrosshair {
                // Light crosshair with dark border
                crosshairColor = NSColor.white.withAlphaComponent(settings.opacity)
                borderColor = NSColor.black.withAlphaComponent(settings.opacity)
            } else {
                // Dark crosshair with light border
                crosshairColor = NSColor.black.withAlphaComponent(settings.opacity)
                borderColor = NSColor.white.withAlphaComponent(settings.opacity)
            }

            // Enforce minimum 1px border when color adaptation is active for guaranteed contrast
            effectiveBorderSize = max(baseBorderSize, 1.0)
        } else {
            crosshairColor = NSColor(settings.crosshairColor).withAlphaComponent(settings.opacity)
            borderColor = NSColor(settings.borderColor).withAlphaComponent(settings.opacity)
            effectiveBorderSize = baseBorderSize
        }
        
        context.setLineCap(.round)

        // Set line style (solid, dashed, dotted)
        switch settings.lineStyle {
        case .solid:
            context.setLineDash(phase: 0, lengths: [])
        case .dashed:
            let dashLength = thickness * 3
            context.setLineDash(phase: 0, lengths: [dashLength, dashLength])
        case .dotted:
            let dotLength = thickness
            context.setLineDash(phase: 0, lengths: [dotLength, dotLength * 2])
        }

        // Draw circle orientation mode
        if settings.orientation == .circle {
            let circleRadius = CGFloat(settings.circleRadius)
            let circlePath = CGPath(ellipseIn: CGRect(
                x: center.x - circleRadius,
                y: center.y - circleRadius,
                width: circleRadius * 2,
                height: circleRadius * 2
            ), transform: nil)

            // Draw circle fill if opacity > 0
            if settings.circleFillOpacity > 0 {
                let circleFillColor = NSColor(settings.circleFillColor).withAlphaComponent(CGFloat(settings.circleFillOpacity))
                context.setFillColor(circleFillColor.cgColor)
                context.addPath(circlePath)
                context.fillPath()
            }

            // Draw circle border
            if effectiveBorderSize > 0 {
                context.setStrokeColor(borderColor.cgColor)
                context.setLineWidth(thickness + effectiveBorderSize * 2)
                context.addPath(circlePath)
                context.strokePath()
            }

            // Draw circle main line
            context.setStrokeColor(crosshairColor.cgColor)
            context.setLineWidth(thickness)
            context.addPath(circlePath)
            context.strokePath()

            // Don't draw any lines - circle mode only shows circle
            return
        }

        // Draw horizontal line
        if settings.orientation == .horizontal || settings.orientation == .both {
            let leftStart: CGPoint
            let rightEnd: CGPoint

            if settings.useFixedLength {
                let halfLength = CGFloat(settings.fixedLength) / 2
                leftStart = CGPoint(x: max(0, center.x - halfLength), y: center.y)
                rightEnd = CGPoint(x: min(viewSize.width, center.x + halfLength), y: center.y)
            } else {
                leftStart = CGPoint(x: 0, y: center.y)
                rightEnd = CGPoint(x: viewSize.width, y: center.y)
            }

            // Check if reading line mode is enabled (only for horizontal orientation)
            let useReadingLine = (settings.orientation == .horizontal && settings.useReadingLine)

            if useReadingLine {
                // Reading line mode: draw continuous line with no gap
                // Draw border
                if effectiveBorderSize > 0 {
                    context.setStrokeColor(borderColor.cgColor)
                    context.setLineWidth(thickness + effectiveBorderSize * 2)
                    context.move(to: leftStart)
                    context.addLine(to: rightEnd)
                    context.strokePath()
                }

                // Draw main line (continuous, no gap)
                context.setStrokeColor(crosshairColor.cgColor)
                context.setLineWidth(thickness)
                context.move(to: leftStart)
                context.addLine(to: rightEnd)
                context.strokePath()
            } else {
                // Normal crosshair with center gap
                let leftEnd = CGPoint(x: center.x - centerRadius, y: center.y)
                let rightStart = CGPoint(x: center.x + centerRadius, y: center.y)

                // Draw borders
                if effectiveBorderSize > 0 {
                    context.setStrokeColor(borderColor.cgColor)
                    context.setLineWidth(thickness + effectiveBorderSize * 2)
                    context.move(to: leftStart)
                    context.addLine(to: leftEnd)
                    context.strokePath()
                    context.move(to: rightStart)
                    context.addLine(to: rightEnd)
                    context.strokePath()
                }

                // Draw main line
                context.setStrokeColor(crosshairColor.cgColor)
                context.setLineWidth(thickness)
                context.move(to: leftStart)
                context.addLine(to: leftEnd)
                context.strokePath()
                context.move(to: rightStart)
                context.addLine(to: rightEnd)
                context.strokePath()
            }
        }
        
        // Draw vertical line
        if settings.orientation == .vertical || settings.orientation == .both {
            let topStart: CGPoint
            let bottomEnd: CGPoint
            
            if settings.useFixedLength {
                let halfLength = CGFloat(settings.fixedLength) / 2
                topStart = CGPoint(x: center.x, y: max(0, center.y - halfLength))
                bottomEnd = CGPoint(x: center.x, y: min(viewSize.height, center.y + halfLength))
            } else {
                topStart = CGPoint(x: center.x, y: 0)
                bottomEnd = CGPoint(x: center.x, y: viewSize.height)
            }
            
            let topEnd = CGPoint(x: center.x, y: center.y - centerRadius)
            let bottomStart = CGPoint(x: center.x, y: center.y + centerRadius)
            
            // Draw borders
            if effectiveBorderSize > 0 {
                context.setStrokeColor(borderColor.cgColor)
                context.setLineWidth(thickness + effectiveBorderSize * 2)
                context.move(to: topStart)
                context.addLine(to: topEnd)
                context.strokePath()
                context.move(to: bottomStart)
                context.addLine(to: bottomEnd)
                context.strokePath()
            }
            
            // Draw main line
            context.setStrokeColor(crosshairColor.cgColor)
            context.setLineWidth(thickness)
            context.move(to: topStart)
            context.addLine(to: topEnd)
            context.strokePath()
            context.move(to: bottomStart)
            context.addLine(to: bottomEnd)
            context.strokePath()
        }

        // Draw edge pointers
        if settings.orientation == .edgePointers {
            // Pointer size controlled by edgePointerThickness
            let pointerSize = (edgePointerThickness * 4) + centerRadius / 4

            // Hide distance - pointer disappears when mouse is within this distance
            let hideDistance = pointerSize * 1.5

            // Top pointer (pointing down towards mouse)
            let topX = center.x
            let topY: CGFloat = 0
            let topDist = abs(center.y - topY)
            if topDist > hideDistance {
                drawTrianglePointer(in: context,
                                  at: CGPoint(x: topX, y: topY),
                                  size: pointerSize,
                                  direction: .down,
                                  color: crosshairColor,
                                  borderColor: borderColor,
                                  thickness: edgePointerThickness,
                                  effectiveBorderSize: effectiveBorderSize)
            }

            // Bottom pointer (pointing up towards mouse)
            let bottomX = center.x
            let bottomY = viewSize.height
            let bottomDist = abs(center.y - bottomY)
            if bottomDist > hideDistance {
                drawTrianglePointer(in: context,
                                  at: CGPoint(x: bottomX, y: bottomY),
                                  size: pointerSize,
                                  direction: .up,
                                  color: crosshairColor,
                                  borderColor: borderColor,
                                  thickness: edgePointerThickness,
                                  effectiveBorderSize: effectiveBorderSize)
            }

            // Left pointer (pointing right towards mouse)
            let leftX: CGFloat = 0
            let leftY = center.y
            let leftDist = abs(center.x - leftX)
            if leftDist > hideDistance {
                drawTrianglePointer(in: context,
                                  at: CGPoint(x: leftX, y: leftY),
                                  size: pointerSize,
                                  direction: .right,
                                  color: crosshairColor,
                                  borderColor: borderColor,
                                  thickness: edgePointerThickness,
                                  effectiveBorderSize: effectiveBorderSize)
            }

            // Right pointer (pointing left towards mouse)
            let rightX = viewSize.width
            let rightY = center.y
            let rightDist = abs(center.x - rightX)
            if rightDist > hideDistance {
                drawTrianglePointer(in: context,
                                  at: CGPoint(x: rightX, y: rightY),
                                  size: pointerSize,
                                  direction: .left,
                                  color: crosshairColor,
                                  borderColor: borderColor,
                                  thickness: edgePointerThickness,
                                  effectiveBorderSize: effectiveBorderSize)
            }
        }
    }

    private enum PointerDirection {
        case up, down, left, right
    }

    private func drawTrianglePointer(in context: CGContext,
                                     at position: CGPoint,
                                     size: CGFloat,
                                     direction: PointerDirection,
                                     color: NSColor,
                                     borderColor: NSColor,
                                     thickness: CGFloat,
                                     effectiveBorderSize: CGFloat) {
        let path = CGMutablePath()

        // Create triangle based on direction
        switch direction {
        case .down:
            // Triangle pointing down from top edge
            path.move(to: CGPoint(x: position.x, y: position.y + size))  // Point
            path.addLine(to: CGPoint(x: position.x - size/2, y: position.y))  // Left corner
            path.addLine(to: CGPoint(x: position.x + size/2, y: position.y))  // Right corner
            path.closeSubpath()

        case .up:
            // Triangle pointing up from bottom edge
            path.move(to: CGPoint(x: position.x, y: position.y - size))  // Point
            path.addLine(to: CGPoint(x: position.x - size/2, y: position.y))  // Left corner
            path.addLine(to: CGPoint(x: position.x + size/2, y: position.y))  // Right corner
            path.closeSubpath()

        case .right:
            // Triangle pointing right from left edge
            path.move(to: CGPoint(x: position.x + size, y: position.y))  // Point
            path.addLine(to: CGPoint(x: position.x, y: position.y - size/2))  // Top corner
            path.addLine(to: CGPoint(x: position.x, y: position.y + size/2))  // Bottom corner
            path.closeSubpath()

        case .left:
            // Triangle pointing left from right edge
            path.move(to: CGPoint(x: position.x - size, y: position.y))  // Point
            path.addLine(to: CGPoint(x: position.x, y: position.y - size/2))  // Top corner
            path.addLine(to: CGPoint(x: position.x, y: position.y + size/2))  // Bottom corner
            path.closeSubpath()
        }

        // Draw border if needed
        if effectiveBorderSize > 0 {
            context.setStrokeColor(borderColor.cgColor)
            context.setLineWidth(effectiveBorderSize * 2)
            context.addPath(path)
            context.strokePath()
        }

        // Fill triangle with main color
        context.setFillColor(color.cgColor)
        context.addPath(path)
        context.fillPath()
    }

    // Brightness under the cursor, captured again only when due: steadily while the
    // pointer rests, so a change underneath it still shows, and sooner once half the
    // sampled square is new. A fast swipe passes that distance on every frame, so
    // the shorter interval is what limits capturing while the pointer moves.
    private func backgroundBrightness(at position: CGPoint) -> CGFloat {
        let now = ProcessInfo.processInfo.systemUptime

        if let cachedBrightness {
            let elapsed = now - lastSampleTime
            let moved = hypot(position.x - lastSamplePosition.x, position.y - lastSamplePosition.y)
            let isDue = elapsed >= Self.sampleInterval
                || (elapsed >= Self.movingSampleInterval && moved >= Self.sampleSize / 2)
            guard isDue else { return cachedBrightness }
        }

        let brightness = sampleBackgroundColor(at: position).brightnessValue
        cachedBrightness = brightness
        lastSampleTime = now
        lastSamplePosition = position
        return brightness
    }

    // Sample the background color at cursor position
    private func sampleBackgroundColor(at position: CGPoint) -> NSColor {
        // Create a small rect around cursor to sample
        let sampleSize = Self.sampleSize
        // The position counts from the bottom of the primary screen, the capture
        // from its top. Without this the color comes from the mirrored spot.
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let sampleRect = CGRect(
            x: position.x - sampleSize / 2,
            y: primaryScreenHeight - position.y - sampleSize / 2,
            width: sampleSize,
            height: sampleSize
        )

        // Capture screenshot of the area
        guard let screenImage = CGWindowListCreateImage(
            sampleRect,
            .optionOnScreenBelowWindow,
            CGWindowID(window?.windowNumber ?? 0),
            .bestResolution
        ) else {
            // Fallback to white if capture fails
            return NSColor.white
        }

        // Get average color from the sampled region
        return averageColor(of: screenImage)
    }

    private func averageColor(of image: CGImage) -> NSColor {
        let width = image.width
        let height = image.height
        guard width > 0 && height > 0 else { return NSColor.white }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let totalBytes = bytesPerRow * height

        var pixelData = [UInt8](repeating: 0, count: totalBytes)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return NSColor.white
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Calculate average RGB
        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0
        let pixelCount = width * height

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * bytesPerPixel
                totalR += CGFloat(pixelData[offset])
                totalG += CGFloat(pixelData[offset + 1])
                totalB += CGFloat(pixelData[offset + 2])
            }
        }

        let avgR = totalR / CGFloat(pixelCount) / 255.0
        let avgG = totalG / CGFloat(pixelCount) / 255.0
        let avgB = totalB / CGFloat(pixelCount) / 255.0

        return NSColor(red: avgR, green: avgG, blue: avgB, alpha: 1.0)
    }
}

// Extension to calculate brightness of a color
extension NSColor {
    var brightnessValue: CGFloat {
        guard let rgbColor = self.usingColorSpace(.deviceRGB) else { return 0.5 }
        // Use perceived brightness formula
        return (rgbColor.redComponent * 0.299 + rgbColor.greenComponent * 0.587 + rgbColor.blueComponent * 0.114)
    }
}
