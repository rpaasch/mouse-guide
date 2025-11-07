import SwiftUI

/// SwiftUI view for the MenuBarExtra content with keyboard-accessible Toggle
struct MenuBarContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Toggle for showing/hiding crosshairs
            HStack {
                Text(LocalizedString.appName)
                    .allowsHitTesting(false)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { appState.isCrosshairsVisible },
                    set: { _ in appState.toggleCrosshairs() }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .focusable()
                .accessibilityLabel(LocalizedString.accessibilityMenubarToggleLabel)
                .accessibilityValue(appState.isCrosshairsVisible ? LocalizedString.accessibilityStateOn : LocalizedString.accessibilityStateOff)
                .accessibilityHint(LocalizedString.accessibilityMenubarToggleHelp)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Settings button
            Button(action: {
                appState.showSettings()
            }) {
                HStack {
                    Text(LocalizedString.menuSettings)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .keyboardShortcut(",", modifiers: .command)
            .buttonStyle(KeyboardAccessibleButtonStyle())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Quit button
            Button(action: {
                appState.quit()
            }) {
                HStack {
                    Text(LocalizedString.menuQuit)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .keyboardShortcut("q", modifiers: .command)
            .buttonStyle(KeyboardAccessibleButtonStyle())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 240)
    }
}

// Custom button style that makes buttons keyboard-focusable
struct KeyboardAccessibleButtonStyle: ButtonStyle {
    @FocusState private var isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(isFocused ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(4)
            .focusable(true)
            .focused($isFocused)
    }
}

#Preview {
    MenuBarContentView()
        .environmentObject(AppState())
}
