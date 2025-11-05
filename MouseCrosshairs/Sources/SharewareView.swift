import SwiftUI

struct SharewareView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settings = CrosshairsSettings.shared

    let purchaseURL = "https://gumroad.com/l/mouseguide" // Opdater med din faktiske URL

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            // Title
            Text(LocalizedStringKey("payment.title"))
                .font(.title)
                .fontWeight(.bold)

            // Description
            VStack(spacing: 12) {
                Text(LocalizedStringKey("payment.ifUseful"))
                    .font(.headline)

                Text(LocalizedStringKey("payment.wouldAppreciate"))
                    .font(.headline)

                Text(LocalizedStringKey("payment.price"))
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.vertical, 8)

                Text(LocalizedStringKey("payment.worksRegardless"))
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)

            Divider()
                .padding(.vertical, 8)

            // Buttons
            VStack(spacing: 12) {
                Button(action: {
                    if let url = URL(string: purchaseURL) {
                        NSWorkspace.shared.open(url)
                    }
                    settings.hasSeenSharewareReminder = true
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "heart.fill")
                        Text(LocalizedStringKey("payment.buyButton"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Button(action: {
                    settings.isPurchased = true
                    settings.hasSeenSharewareReminder = true
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text(LocalizedStringKey("payment.purchasedButton"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Button(action: {
                    settings.hasSeenSharewareReminder = true
                    dismiss()
                }) {
                    Text(LocalizedStringKey("payment.continueButton"))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: {
                    dismiss()
                }) {
                    Text(LocalizedStringKey("payment.remindButton"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
        }
        .padding(30)
        .frame(width: 500)
    }
}

// About view for menu bar
struct AboutSharewareView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settings = CrosshairsSettings.shared

    let purchaseURL = "https://gumroad.com/l/mouseguide" // Opdater med din faktiske URL

    var body: some View {
        VStack(spacing: 20) {
            // App Icon (placeholder)
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.yellow)

            VStack(spacing: 4) {
                Text("Mouse Guide")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Version 1.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()

            VStack(spacing: 12) {
                Text(LocalizedStringKey("payment.subtitle"))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 4)

                Text(LocalizedStringKey("payment.description1"))
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Text(LocalizedStringKey("payment.description2"))
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Divider()
                    .padding(.vertical, 4)

                Text(LocalizedStringKey("payment.price"))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.vertical, 4)

                Text(LocalizedStringKey("payment.wouldAppreciate"))
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)

            // Buttons
            VStack(spacing: 10) {
                if settings.isPurchased {
                    // Already purchased - show thank you
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(LocalizedStringKey("payment.thankYou"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(8)
                } else {
                    // Not purchased - show buy button
                    Button(action: {
                        if let url = URL(string: purchaseURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "cart.fill")
                            Text(LocalizedStringKey("payment.aboutBuyButton"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        settings.isPurchased = true
                    }) {
                        Text(LocalizedStringKey("payment.purchasedButton"))
                    }
                    .buttonStyle(.plain)
                }

                Button(LocalizedStringKey("payment.aboutClose")) {
                    dismiss()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(30)
        .frame(width: 400)
    }
}

#Preview {
    SharewareView()
}

#Preview("About") {
    AboutSharewareView()
}
