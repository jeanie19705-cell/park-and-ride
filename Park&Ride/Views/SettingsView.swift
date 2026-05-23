import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app_color_scheme") private var colorScheme = "light"

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Toggle("🌗 Dark Mode", isOn: Binding(
                        get: { colorScheme == "dark" },
                        set: { isDark in
                            let newValue = isDark ? "dark" : "light"
                            applyColorScheme(newValue)
                            colorScheme = newValue
                        }
                    ))
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Data", value: "Transport for NSW")
                    Link(destination: URL(string: "https://buymeacoffee.com/jezi_")!) {
                        HStack {
                            Text("☕ Enjoy the app? Buy me a coffee :)")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .tint(.primary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
