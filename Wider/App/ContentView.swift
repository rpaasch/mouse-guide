import SwiftUI

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @State private var reportURL = ""

    // Same address as REPORT_ADDRESS in the extension's popup.js.
    private let reportAddress = "support@getwider.app"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        Image("Logo")
                            .resizable()
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        Text("Wider")
                            .font(.largeTitle.bold())
                        Text("intro")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section("setup.title") {
                    Step(number: 1, text: "setup.step1")
                    Step(number: 2, text: "setup.step2")
                    Step(number: 3, text: "setup.step3")
                    Step(number: 4, text: "setup.step4")
                }

                Section {
                    Label("use.toggle", systemImage: "arrow.left.and.right.circle.fill")
                    Label("use.perSite", systemImage: "globe")
                    Label("use.limits", systemImage: "exclamationmark.triangle")
                } header: {
                    Text("use.title")
                }

                Section {
                    TextField("report.placeholder", text: $reportURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("report.send", action: report)
                        .disabled(trimmedReportURL.isEmpty)
                } header: {
                    Text("report.title")
                } footer: {
                    Text("report.footer")
                }

                Section {
                    Text("privacy")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var trimmedReportURL: String {
        reportURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Only the URL goes in the mail, and the person sends it themselves.
    private func report() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = reportAddress
        components.queryItems = [
            URLQueryItem(name: "subject", value: String(localized: "report.subject")),
            URLQueryItem(name: "body", value: trimmedReportURL),
        ]
        if let url = components.url { openURL(url) }
    }
}

private struct Step: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.tint)
            Text(text)
        }
    }
}

#Preview {
    ContentView()
}
