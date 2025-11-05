import SwiftUI
import AppKit

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var hasAccessibilityPermission = false
    @State private var permissionCheckTimer: Timer?
    let onComplete: () -> Void

    let totalPages = 5  // Added permissions page

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
                // Large icon header
                VStack(spacing: 20) {
                    Image(systemName: "scope")
                        .font(.system(size: 80, weight: .thin))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 50)

                    Text(LocalizedString.onboardingTitle)
                        .font(.system(size: 32, weight: .bold))
                        .multilineTextAlignment(.center)

                    Text(LocalizedString.onboardingWelcome)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 60)
                }
                .padding(.bottom, 40)

                // Page indicator - larger and more visible
                HStack(spacing: 12) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(currentPage == index ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: currentPage == index ? 32 : 8, height: 8)
                            .animation(.spring(), value: currentPage)
                    }
                }
                .padding(.bottom, 40)

                // Content pages - with card background
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)

                    // Page 1: Toggle
                    if currentPage == 0 {
                        OnboardingPageView(
                            icon: "keyboard",
                            title: LocalizedString.onboardingStep1Title,
                            description: LocalizedString.onboardingStep1Description,
                            iconColor: .blue
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }

                    // Page 2: Menu Bar
                    if currentPage == 1 {
                        OnboardingPageView(
                            icon: "menubar.rectangle",
                            title: LocalizedString.onboardingStep2Title,
                            description: LocalizedString.onboardingStep2Description,
                            iconColor: .green
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }

                    // Page 3: Customize
                    if currentPage == 2 {
                        OnboardingPageView(
                            icon: "paintbrush.pointed",
                            title: LocalizedString.onboardingStep3Title,
                            description: LocalizedString.onboardingStep3Description,
                            iconColor: .orange
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }

                    // Page 4: Multi-Monitor
                    if currentPage == 3 {
                        OnboardingPageView(
                            icon: "display",
                            title: LocalizedString.onboardingStep4Title,
                            description: LocalizedString.onboardingStep4Description,
                            iconColor: .purple
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }

                    // Page 5: Permissions
                    if currentPage == 4 {
                        PermissionsPageView(
                            hasAccessibility: hasAccessibilityPermission,
                            onOpenAccessibility: openAccessibilitySettings,
                            onRefresh: checkAccessibilityPermission,
                            onRequestPermission: requestAccessibilityPermission
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }
                }
                .frame(height: 280)
                .padding(.horizontal, 60)

                Spacer()

                // Navigation buttons - much more prominent
                HStack(spacing: 12) {
                    if currentPage > 0 {
                        Button(action: previousPage) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Tilbage")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .font(.headline)
                    }

                    Button(action: {
                        if currentPage < totalPages - 1 {
                            nextPage()
                        } else {
                            completeOnboarding()
                        }
                    }) {
                        HStack {
                            Text(currentPage == totalPages - 1 ? LocalizedString.onboardingButtonGetStarted : "Næste")
                                .font(.headline)
                            Image(systemName: currentPage == totalPages - 1 ? "checkmark" : "chevron.right")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.blue)
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 50)
            }
        }
        .frame(width: 700, height: 750)
        .onAppear {
            checkAccessibilityPermission()
            // Start periodic permission checking
            permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                checkAccessibilityPermission()
            }
        }
        .onDisappear {
            // Clean up timer to prevent memory leak
            permissionCheckTimer?.invalidate()
            permissionCheckTimer = nil
        }
    }

    private func nextPage() {
        withAnimation {
            currentPage += 1
        }
    }

    private func previousPage() {
        withAnimation {
            currentPage -= 1
        }
    }

    private func completeOnboarding() {
        onComplete()
    }

    private func checkAccessibilityPermission() {
        // Check permission WITHOUT showing prompt (we have a button for that)
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false]
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options)
    }

    private func requestAccessibilityPermission() {
        // Request permission WITH showing system prompt
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)

        // Recheck after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            checkAccessibilityPermission()
        }
    }

    private func openAccessibilitySettings() {
        // Open System Settings to Accessibility WITHOUT showing permission dialog
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }

        // Recheck permission after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            checkAccessibilityPermission()
        }
    }
}

struct OnboardingPageView: View {
    let icon: String
    let title: String
    let description: String
    let iconColor: Color

    var body: some View {
        VStack(spacing: 24) {
            // Icon with circle background
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: icon)
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(iconColor)
            }
            .padding(.top, 20)

            VStack(spacing: 12) {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Permissions Page View

struct PermissionsPageView: View {
    let hasAccessibility: Bool
    let onOpenAccessibility: () -> Void
    let onRefresh: () -> Void
    let onRequestPermission: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(.blue)

                Text(LocalizedString.onboardingPermissionTitle)
                    .font(.title)
                    .fontWeight(.bold)

                Text(LocalizedString.onboardingPermissionDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 20)

            // Permission card
            VStack(spacing: 12) {
                // Accessibility Permission
                PermissionCard(
                    icon: "hand.raised.fill",
                    title: "Tilgængelighed",
                    description: "Påkrævet for globale tastaturgenveje",
                    isGranted: hasAccessibility,
                    action: onOpenAccessibility,
                    onRequestPermission: onRequestPermission
                )
            }

            // Refresh button
            if !hasAccessibility {
                Button(action: onRefresh) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Opdater status")
                    }
                    .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void
    var onRequestPermission: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isGranted ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(isGranted ? .green : .orange)
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status
                if isGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
            }

            // Buttons when not granted
            if !isGranted {
                HStack(spacing: 8) {
                    if let requestPermission = onRequestPermission {
                        Button(action: requestPermission) {
                            HStack {
                                Image(systemName: "lock.open.fill")
                                Text("Anmod om Tilladelse")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    Button(action: action) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text("Åbn Indstillinger")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isGranted ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onComplete: {})
    }
}
