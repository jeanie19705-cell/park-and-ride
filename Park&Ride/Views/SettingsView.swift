import SwiftUI

struct SettingsView: View {
    @AppStorage("tfnsw_api_key") private var apiKey = ""
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Paste your API key here", text: $draft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                } header: {
                    Text("TfNSW Open Data API Key")
                } footer: {
                    Text("Required to fetch live carpark data. Your key is stored only on this device.")
                }

                Section {
                    Link(destination: URL(string: "https://opendata.transport.nsw.gov.au/user/register")!) {
                        Label("Register for a free API key", systemImage: "globe")
                    }
                }

                Section("About") {
                    LabeledContent("Endpoint", value: "api.transport.nsw.gov.au")
                    LabeledContent("Refresh interval", value: "60 seconds")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        apiKey = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { draft = apiKey }
        }
    }
}