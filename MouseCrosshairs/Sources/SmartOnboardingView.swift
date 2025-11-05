import SwiftUI
import AppKit

// MARK: - Smart Onboarding with Dynamic Permission Flow

struct SmartOnboardingView: View {
    @State private var currentStep = 0
    @State private var hasAccessibility = false
    @State private var hasInputMonitoring = false
    @State private var hasScreenRecording = false
    @State private var permissionCheckTimer: Timer?

    let onComplete: () -> Void

    // Dynamic steps based on what's needed
    private var steps: [OnboardingStep] {
        var allSteps: [OnboardingStep] = [.welcome]

        // Add Accessibility if missing (REQUIRED)
        if !hasAccessibility {
            allSteps.append(.accessibility)
        }

        // Add Input Monitoring if missing AND feature is enabled
        let settings = CrosshairsSettings.shared
        if !hasInputMonitoring && settings.autoHideWhileTyping {
            allSteps.append(.inputMonitoring)
        }

        // Add Screen Recording if missing AND feature is enabled
        if !hasScreenRecording && settings.invertColors {
            allSteps.append(.screenRecording)
        }

        allSteps.append(.complete)
        return allSteps
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with app icon
                VStack(spacing: 16) {
                    Image(systemName: "scope")
                        .font(.system(size: 60, weight: .thin))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 40)

                    Text("Mouse Guide")
                        .font(.system(size: 28, weight: .bold))
                }
                .padding(.bottom, 30)

                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(currentStep >= index ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: CGFloat(400 / steps.count), height: 4)
                            .animation(.spring(), value: currentStep)
                    }
                }
                .padding(.horizontal, 80)
                .padding(.bottom, 30)

                // Current step content
                ZStack {
                    ForEach(0..<steps.count, id: \.self) { index in
                        if currentStep == index {
                            stepView(for: steps[index])
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        }
                    }
                }
                .frame(height: 400)
                .padding(.horizontal, 60)

                Spacer()
            }
        }
        .frame(width: 600, height: 700)
        .onAppear {
            checkAllPermissions()
            // Start periodic permission checking
            permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                checkAllPermissions()
            }
        }
        .onDisappear {
            permissionCheckTimer?.invalidate()
            permissionCheckTimer = nil
        }
    }

    @ViewBuilder
    private func stepView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeStepView(onContinue: nextStep)
        case .accessibility:
            AccessibilityStepView(
                hasPermission: hasAccessibility,
                onRequestPermission: requestAccessibility,
                onContinue: nextStep
            )
        case .inputMonitoring:
            InputMonitoringStepView(
                hasPermission: hasInputMonitoring,
                onRequestPermission: requestInputMonitoring,
                onSkip: nextStep,
                onContinue: nextStep
            )
        case .screenRecording:
            ScreenRecordingStepView(
                hasPermission: hasScreenRecording,
                onRequestPermission: requestScreenRecording,
                onSkip: nextStep,
                onContinue: nextStep
            )
        case .complete:
            CompleteStepView(onFinish: onComplete)
        }
    }

    private func nextStep() {
        withAnimation {
            if currentStep < steps.count - 1 {
                currentStep += 1
            } else {
                onComplete()
            }
        }
    }

    private func checkAllPermissions() {
        // Check Accessibility
        let accessibilityOptions: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false]
        hasAccessibility = AXIsProcessTrustedWithOptions(accessibilityOptions)

        // Check Input Monitoring
        let testMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { _ in }
        hasInputMonitoring = (testMonitor != nil)
        if let monitor = testMonitor {
            NSEvent.removeMonitor(monitor)
        }

        // Check Screen Recording
        hasScreenRecording = CGPreflightScreenCaptureAccess()
    }

    private func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func requestInputMonitoring() {
        // Open System Settings to Input Monitoring
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    private func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
    }
}

// MARK: - Onboarding Steps Enum

enum OnboardingStep {
    case welcome
    case accessibility
    case inputMonitoring
    case screenRecording
    case complete
}

// MARK: - Welcome Step

struct WelcomeStepView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Text(LocalizedStringKey("onboarding.welcome.title"))
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(LocalizedStringKey("onboarding.welcome.tagline"))
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)

                Text(LocalizedStringKey("onboarding.welcome.description1"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)

                Text(LocalizedStringKey("onboarding.welcome.description2"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
            }

            VStack(alignment: .leading, spacing: 12) {
                FeatureItem(icon: "plus.circle", text: LocalizedStringKey("onboarding.welcome.feature1"))
                FeatureItem(icon: "minus.rectangle", text: LocalizedStringKey("onboarding.welcome.feature2"))
                FeatureItem(icon: "keyboard", text: LocalizedStringKey("onboarding.welcome.feature3"))
                FeatureItem(icon: "paintbrush.pointed", text: LocalizedStringKey("onboarding.welcome.feature4"))
            }
            .padding(.horizontal, 40)

            Button(action: onContinue) {
                HStack {
                    Text(LocalizedStringKey("onboarding.welcome.button"))
                        .font(.headline)
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 60)
        }
    }
}

struct FeatureItem: View {
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
                .font(.body)
        }
    }
}

// MARK: - Accessibility Step

struct AccessibilityStepView: View {
    let hasPermission: Bool
    let onRequestPermission: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            // Status icon
            ZStack {
                Circle()
                    .fill(hasPermission ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: hasPermission ? "checkmark.circle.fill" : "hand.raised.fill")
                    .font(.system(size: 50))
                    .foregroundColor(hasPermission ? .green : .orange)
            }

            VStack(spacing: 12) {
                Text("Tilgængelighed")
                    .font(.title2)
                    .fontWeight(.bold)

                if hasPermission {
                    Text("✅ Tilladelse er givet!")
                        .font(.body)
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                } else {
                    Text("⚠️ Påkrævet for at bruge appen")
                        .font(.body)
                        .foregroundColor(.orange)
                        .fontWeight(.semibold)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Hvorfor har vi brug for dette?")
                    .font(.headline)

                Text("Tilgængelighed tilladelse gør det muligt for Mouse Guide at:")
                    .font(.body)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        Text("•")
                        Text("Lytte til din globale genvejstast (⇧⌃L)")
                    }
                    HStack(alignment: .top, spacing: 10) {
                        Text("•")
                        Text("Vise/skjule trådkorset uanset hvilket program du bruger")
                    }
                }
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
            }
            .padding(.horizontal, 40)

            if hasPermission {
                Button(action: onContinue) {
                    HStack {
                        Text("Fortsæt")
                            .font(.headline)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 60)
            } else {
                VStack(spacing: 12) {
                    Button(action: onRequestPermission) {
                        HStack {
                            Image(systemName: "lock.open.fill")
                            Text("Anmod om Tilladelse")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text("Klik på knappen, og vælg 'Åbn Systemindstillinger' i dialogen. Sæt derefter checkmark ved Mouse Guide.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 60)
            }
        }
    }
}

// MARK: - Input Monitoring Step

struct InputMonitoringStepView: View {
    let hasPermission: Bool
    let onRequestPermission: () -> Void
    let onSkip: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            // Status icon
            ZStack {
                Circle()
                    .fill(hasPermission ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: hasPermission ? "checkmark.circle.fill" : "keyboard")
                    .font(.system(size: 50))
                    .foregroundColor(hasPermission ? .green : .blue)
            }

            VStack(spacing: 12) {
                Text("Indtastningsovervågning")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("ℹ️ Valgfri - kun til 'Skjul mens du skriver'")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Hvad bruges dette til?")
                    .font(.headline)

                Text("Denne tilladelse gør det muligt at automatisk skjule trådkorset når du begynder at skrive på tastaturet.")
                    .font(.body)
                    .foregroundColor(.secondary)

                Text("Du kan aktivere denne funktion senere i Indstillinger → Adfærd.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
            .padding(.horizontal, 40)

            if hasPermission {
                Button(action: onContinue) {
                    HStack {
                        Text("Fortsæt")
                            .font(.headline)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 60)
            } else {
                HStack(spacing: 12) {
                    Button(action: onSkip) {
                        Text("Spring over")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button(action: onRequestPermission) {
                        HStack {
                            Image(systemName: "lock.open.fill")
                            Text("Giv Tilladelse")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.horizontal, 60)
            }
        }
    }
}

// MARK: - Screen Recording Step

struct ScreenRecordingStepView: View {
    let hasPermission: Bool
    let onRequestPermission: () -> Void
    let onSkip: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            // Status icon
            ZStack {
                Circle()
                    .fill(hasPermission ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: hasPermission ? "checkmark.circle.fill" : "record.circle")
                    .font(.system(size: 50))
                    .foregroundColor(hasPermission ? .green : .blue)
            }

            VStack(spacing: 12) {
                Text("Skærmoptagelse")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("ℹ️ Valgfri - kun til automatisk farvetilpasning")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Hvad bruges dette til?")
                    .font(.headline)

                Text("Denne tilladelse gør det muligt at automatisk vælge sort eller hvid farve på trådkorset baseret på baggrunden under markøren.")
                    .font(.body)
                    .foregroundColor(.secondary)

                Text("Du kan aktivere denne funktion senere i Indstillinger → Adfærd.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
            .padding(.horizontal, 40)

            if hasPermission {
                Button(action: onContinue) {
                    HStack {
                        Text("Fortsæt")
                            .font(.headline)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 60)
            } else {
                HStack(spacing: 12) {
                    Button(action: onSkip) {
                        Text("Spring over")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button(action: onRequestPermission) {
                        HStack {
                            Image(systemName: "lock.open.fill")
                            Text("Giv Tilladelse")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.horizontal, 60)
            }
        }
    }
}

// MARK: - Complete Step

struct CompleteStepView: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            // Success icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
            }

            VStack(spacing: 12) {
                Text("Alt er klar!")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Mouse Guide er nu sat op og klar til brug")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Quick Tips:")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 12) {
                    TipItem(
                        icon: "keyboard",
                        title: "Genvejstast",
                        description: "Tryk ⇧⌃L for at vise/skjule trådkorset"
                    )

                    TipItem(
                        icon: "menubar.rectangle",
                        title: "Menu Bar",
                        description: "Klik på trådkors ikonet for at åbne menuen"
                    )

                    TipItem(
                        icon: "gearshape",
                        title: "Indstillinger",
                        description: "Tilpas farver, størrelse og meget mere"
                    )
                }
            }
            .padding(.horizontal, 40)

            Button(action: onFinish) {
                HStack {
                    Text("Kom i gang!")
                        .font(.headline)
                    Image(systemName: "checkmark")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.green)
            .padding(.horizontal, 60)
        }
    }
}

struct TipItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

struct SmartOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        SmartOnboardingView(onComplete: {})
    }
}
