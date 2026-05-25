import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app_color_scheme") private var colorScheme = "system"

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: Binding(
                        get: { colorScheme },
                        set: { newValue in
                            applyColorScheme(newValue)
                            colorScheme = newValue
                        }
                    )) {
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                        Text("System").tag("system")
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    Link(destination: URL(string: "https://data.nsw.gov.au/data/dataset/2-car-park-api")!) {
                        LabeledContent("Data", value: "Transport for NSW")
                    }
                    .tint(.primary)
                } header: {
                    Text("About")
                } footer: {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "info.circle")
                        Text("Space availability is sourced from TfNSW Open Data and may be approximate due to sensor limitations.")
                    }
                    .font(.caption2)
                }

                Section("Get In Touch") {
                    Link(destination: URL(string: "mailto:jeanie19705@gmail.com?subject=Park%20%26%20Ride%20Feedback")!) {
                        HStack {
                            Text("💬 Send feedback")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .tint(.primary)
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
            .scrollContentBackground(.hidden)
            .background(Color("AppBackground"))
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
