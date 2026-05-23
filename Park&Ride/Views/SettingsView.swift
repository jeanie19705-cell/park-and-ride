import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Data") {
                    LabeledContent("Source", value: "Park & Ride Backend")
                    LabeledContent("Refresh interval", value: "60 seconds")
                }

                Section("About") {
                    LabeledContent("App", value: "Park & Ride")
                    LabeledContent("Data", value: "Transport for NSW")
                    Link(destination: URL(string: "https://buymeacoffee.com/jezi_")!) {
                        Text("☕ Enjoy the app? Buy me a coffee :)")
                    }
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
