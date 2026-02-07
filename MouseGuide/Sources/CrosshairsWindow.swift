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
    private var keyboardEventMonitor: Any?  // Global monitor - works when app is NOT frontmost
    private var localKeyboardEventMonitor: Any?  // Local monitor - works when app IS frontmost
    private var isHiddenByTyping = false
    private var unhideTimer: Timer?
    private var lastAutoHideWhileTypingValue: Bool = false

    func show() {
        NSLog("🚀 show() ENTRY - calling hide() first")
        hide() // Clean up any existing windows
        NSLog("✅ hide() completed successfully")

        let settings = CrosshairsSettings.shared
        let licenseState = LicenseManager.shared.licenseState

        NSLog("🚀 show() called - licenseState = \(licenseState), hasFullAccess = \(settings.hasFullAccess)")

        // In free version, only show on main screen
        let screensToUse: [NSScreen]
        if settings.hasFullAccess {
            screensToUse = NSScreen.screens
            NSLog("   ✅ Full access - showing on all \(screensToUse.count) screens")
        } else {
            screensToUse = NSScreen.main.map { [$0] } ?? []
            NSLog("   🔒 Limited access - showing on main screen only")
        }

        NSLog("🔍 DEBUG: After if/else, screensToUse.count = \(screensToUse.count)")
        NSLog("🔍 DEBUG: screensToUse array = \(screensToUse)")

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

        // Start keyboard monitoring if enabled and track initial value
        lastAutoHideWhileTypingValue = settings.autoHideWhileTyping
        startKeyboardMonitoring()

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

        // Listen for license state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(licenseStateChanged),
            name: NSNotification.Name("LicenseStateChanged"),
            object: nil
        )
    }

    @objc private func settingsChanged() {
        NSLog("⚙️ Settings changed - updating crosshairs")

        // Check if autoHideWhileTyping setting specifically changed
        let currentAutoHideWhileTyping = settings.autoHideWhileTyping
        if currentAutoHideWhileTyping != lastAutoHideWhileTypingValue {
            NSLog("   📍 autoHideWhileTyping changed: \(lastAutoHideWhileTypingValue) → \(currentAutoHideWhileTyping)")
            lastAutoHideWhileTypingValue = currentAutoHideWhileTyping

            // Start or stop keyboard monitoring based on new value
            if currentAutoHideWhileTyping {
                startKeyboardMonitoring()
                // Permission check is now handled by the toggle in SettingsView
                // No automatic popups here
            } else {
                stopKeyboardMonitoring()
                // Show windows if they were hidden
                if isHiddenByTyping {
                    unhideAfterTyping()
                }
            }
        }

        // Restart tracking to apply gliding changes
        stopTracking()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.startTracking()
        }

        // Redraw all windows with new settings
        for window in windows {
            window.contentView?.setNeedsDisplay(window.contentView!.bounds)
        }
    }

    @objc private func licenseStateChanged() {
        NSLog("📢 License state changed - updating crosshairs")

        // Check if we need to recreate windows (e.g., multi-monitor restriction)
        let currentWindowCount = windows.count
        let settings = CrosshairsSettings.shared
        let expectedWindowCount = settings.hasFullAccess ? NSScreen.screens.count : 1

        if currentWindowCount != expectedWindowCount {
            // Window count changed - recreate
            hide()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.show()
            }
        } else {
            // Just redraw with new settings
            for window in windows {
                window.contentView?.setNeedsDisplay(window.contentView!.bounds)
            }
        }
    }

    func hide() {
        NSLog("🔴 hide() called - cleaning up \(windows.count) windows")
        stopTracking()
        stopKeyboardMonitoring()
        unhideTimer?.invalidate()
        unhideTimer = nil
        for window in windows {
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
        // Don't update position while hidden by typing
        if isHiddenByTyping {
            return
        }

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

    private func startKeyboardMonitoring() {
        guard settings.autoHideWhileTyping else {
            print("⌨️ Keyboard monitoring NOT started - setting is disabled")
            return
        }

        stopKeyboardMonitoring()

        print("⌨️ Starting keyboard monitoring for hide-while-typing...")

        // Global monitor - works when app is NOT frontmost
        keyboardEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyPress(event)
        }

        // Local monitor - works when app IS frontmost
        localKeyboardEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyPress(event)
            return event  // Pass through - don't consume typing events
        }

        if keyboardEventMonitor != nil {
            print("✅ Global keyboard monitoring started")
        } else {
            print("⚠️ Global keyboard monitoring failed - Input Monitoring permission may be missing")
        }

        if localKeyboardEventMonitor != nil {
            print("✅ Local keyboard monitoring started")
        }
    }

    private func stopKeyboardMonitoring() {
        if let monitor = keyboardEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardEventMonitor = nil
        }
        if let monitor = localKeyboardEventMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyboardEventMonitor = nil
        }
    }

    private func handleKeyPress(_ event: NSEvent) {
        guard settings.autoHideWhileTyping else { return }

        print("⌨️ Key pressed: \(event.charactersIgnoringModifiers ?? "unknown")")

        // Hide windows
        if !isHiddenByTyping {
            print("🙈 Hiding crosshairs due to typing")
            isHiddenByTyping = true
            for window in windows {
                window.orderOut(nil)
            }
        }

        // Reset unhide timer
        unhideTimer?.invalidate()
        unhideTimer = Timer.scheduledTimer(withTimeInterval: settings.autoHideTypingDelay, repeats: false) { [weak self] _ in
            self?.unhideAfterTyping()
        }
    }

    private func unhideAfterTyping() {
        guard isHiddenByTyping else { return }

        print("👀 Showing crosshairs again after typing stopped")

        // FIRST: Update mouse position IMMEDIATELY before clearing flag
        // This ensures views have the correct position when they're shown
        let currentMouseLocation = NSEvent.mouseLocation
        mouseTracker.position = currentMouseLocation
        targetPosition = currentMouseLocation

        // Clear flag to allow position updates
        isHiddenByTyping = false
        isFirstFrame = true  // Skip gliding delay so cursor appears immediately
        lastUpdateTime = 0  // Reset timing so next frame is treated as first

        // Show windows again
        for window in windows {
            window.orderFrontRegardless()
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

// Native NSView implementation for better control over multi-monitor setups
class CrosshairsNativeView: NSView {
    private var mouseTracker: MouseTracker
    private var settings: CrosshairsSettings
    private var screenFrame: NSRect
    private var displayLink: CVDisplayLink?
    private var settingsObserver: Any?

    // Hysteresis state for color adaptation - prevents flickering
    // true = currently using light crosshair, false = currently using dark crosshair
    private var isUsingLightCrosshair: Bool = true

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
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        if let displayLink = displayLink {
            CVDisplayLinkSetOutputCallback(displayLink, { (_, _, _, _, _, userInfo) -> CVReturn in
                let view = Unmanaged<CrosshairsNativeView>.fromOpaque(userInfo!).takeUnretainedValue()
                DispatchQueue.main.async {
                    view.needsDisplay = true
                }
                return kCVReturnSuccess
            }, Unmanaged.passUnretained(self).toOpaque())
            CVDisplayLinkStart(displayLink)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
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

        // Debug
        if Int.random(in: 0...60) == 0 {
            print("🎨 Screen \(screenFrame): mouse=\(mouseLocation), center=\(center), bounds=\(bounds.size)")
        }

        // Draw crosshairs
        drawCrosshairs(in: context, center: center, viewSize: bounds.size)
    }
    
    private func drawCrosshairs(in context: CGContext, center: CGPoint, viewSize: CGSize) {
        let thickness = CGFloat(settings.effectiveThickness)
        let edgePointerThickness = CGFloat(settings.edgePointerThickness)
        let centerRadius = CGFloat(settings.effectiveCenterRadius)
        let baseBorderSize = CGFloat(settings.effectiveBorderSize)

        NSLog("🎨 Drawing with thickness=\(thickness), centerRadius=\(centerRadius), hasFullAccess=\(settings.hasFullAccess)")

        // Get colors
        let crosshairColor: NSColor
        let borderColor: NSColor

        // Effective border size - enforce minimum 1px when color adaptation is active
        let effectiveBorderSize: CGFloat

        if settings.effectiveInvertColors {
            // Dynamic color inversion based on background with hysteresis to prevent flickering
            let backgroundColor = sampleBackgroundColor(at: mouseTracker.position)
            let brightness = backgroundColor.brightnessValue

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
                crosshairColor = NSColor.white.withAlphaComponent(settings.effectiveOpacity)
                borderColor = NSColor.black.withAlphaComponent(settings.effectiveOpacity)
            } else {
                // Dark crosshair with light border
                crosshairColor = NSColor.black.withAlphaComponent(settings.effectiveOpacity)
                borderColor = NSColor.white.withAlphaComponent(settings.effectiveOpacity)
            }

            // Enforce minimum 1px border when color adaptation is active for guaranteed contrast
            effectiveBorderSize = max(baseBorderSize, 1.0)
        } else {
            crosshairColor = NSColor(settings.effectiveCrosshairColor).withAlphaComponent(settings.effectiveOpacity)
            borderColor = NSColor(settings.effectiveBorderColor).withAlphaComponent(settings.effectiveOpacity)
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
                let circleFillColor = NSColor(settings.effectiveCircleFillColor).withAlphaComponent(CGFloat(settings.circleFillOpacity))
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

    // Sample the background color at cursor position
    private func sampleBackgroundColor(at position: CGPoint) -> NSColor {
        // Create a small rect around cursor to sample
        let sampleSize: CGFloat = 20
        let sampleRect = CGRect(
            x: position.x - sampleSize / 2,
            y: position.y - sampleSize / 2,
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
