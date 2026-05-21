import SwiftUI
import MapKit

struct CarParkDetailView: View {
    let carPark: CarPark
    @State private var refreshed: CarPark?
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    // Notification config state
    @State private var alertEnabled = false
    @State private var startTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: .now)!
    @State private var endTime   = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
    @State private var threshold = 20
    @State private var showPermissionDenied = false

    private var displayed: CarPark { refreshed ?? carPark }

    var body: some View {
        List {
            if let error = errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.callout)
                }
            }

            Section("Live Occupancy") {
                if let available = displayed.availableSpots, let total = displayed.totalSpots {
                    let fraction = displayed.occupancyFraction ?? 0
                    let color = occupancyColor(fraction)

                    LabeledContent("Free spaces") {
                        Text("\(available)").foregroundStyle(color).fontWeight(.semibold)
                    }
                    LabeledContent("Total capacity", value: "\(total)")
                    ProgressView(value: fraction).tint(color).padding(.vertical, 4)
                } else {
                    Text("No occupancy data available").foregroundStyle(.secondary)
                }
            }

            if let loc = displayed.location {
                Section("Location") {
                    if let address = loc.address { LabeledContent("Address", value: address) }
                    if let suburb = loc.suburb   { LabeledContent("Suburb",  value: suburb)  }

                    if let mapItem = mapItem(for: loc) {
                        Button {
                            mapItem.openInMaps(launchOptions: [
                                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                            ])
                        } label: {
                            Label("Get Directions", systemImage: "map")
                        }
                    }
                }
            }

            Section {
                Toggle("Notify me", isOn: $alertEnabled)
                    .onChange(of: alertEnabled) { _, enabled in
                        Task { await handleToggle(enabled) }
                    }

                if alertEnabled {
                    DatePicker("From", selection: $startTime, displayedComponents: .hourAndMinute)
                        .onChange(of: startTime) { _, _ in saveAlert() }
                    DatePicker("To", selection: $endTime, displayedComponents: .hourAndMinute)
                        .onChange(of: endTime) { _, _ in saveAlert() }
                    Stepper("Below \(threshold)% available", value: $threshold, in: 5...100, step: 5)
                        .onChange(of: threshold) { _, _ in saveAlert() }
                }
            } header: {
                Text("Notifications")
            } footer: {
                if alertEnabled {
                    Text("You'll be notified when availability drops below \(threshold)% between the selected times, checked every 60 seconds.")
                }
            }

            Section {
                if let updated = displayed.MessageDate {
                    LabeledContent("Data timestamp", value: updated).font(.callout)
                }
                if isRefreshing {
                    HStack {
                        ProgressView()
                        Text("Refreshing…").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(displayed.facility_name ?? "Car Park")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await fetchLatest() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isRefreshing)
            }
        }
        .task { await fetchLatest() }
        .onAppear { loadAlert() }
        .alert("Notifications Disabled", isPresented: $showPermissionDenied) {
            Button("Open Settings") {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow notifications for Park & Ride in Settings to use this feature.")
        }
    }

    // MARK: – Alert config

    private func loadAlert() {
        guard let id = carPark.facility_id,
              let alert = AlertStore.load(for: id) else { return }
        alertEnabled  = alert.isEnabled
        startTime     = timeToDate(hour: alert.startHour, minute: alert.startMinute)
        endTime       = timeToDate(hour: alert.endHour,   minute: alert.endMinute)
        threshold     = alert.threshold
    }

    private func handleToggle(_ enabled: Bool) async {
        if enabled {
            let granted = await NotificationService.requestPermission()
            if !granted {
                alertEnabled = false
                showPermissionDenied = true
                return
            }
        }
        saveAlert()
    }

    private func saveAlert() {
        guard let id = carPark.facility_id else { return }
        if alertEnabled {
            let (sh, sm) = dateToTime(startTime)
            let (eh, em) = dateToTime(endTime)
            AlertStore.save(ParkAlert(
                isEnabled: true,
                startHour: sh, startMinute: sm,
                endHour: eh,   endMinute: em,
                threshold: threshold
            ), for: id)
        } else {
            AlertStore.remove(for: id)
        }
    }

    private func timeToDate(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
    }

    private func dateToTime(_ date: Date) -> (Int, Int) {
        let cal = Calendar.current
        return (cal.component(.hour, from: date), cal.component(.minute, from: date))
    }

    // MARK: – Maps / fetch

    private func mapItem(for loc: ParkLocation) -> MKMapItem? {
        guard let latStr = loc.latitude, let lonStr = loc.longitude,
              let lat = Double(latStr), let lon = Double(lonStr) else { return nil }
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        let item = MKMapItem(placemark: placemark)
        item.name = displayed.facility_name
        return item
    }

    private func fetchLatest() async {
        guard let id = carPark.facility_id else { return }
        isRefreshing = true
        errorMessage = nil
        do {
            refreshed = try await ParkingService.shared.fetchCarPark(facilityId: id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isRefreshing = false
    }

    private func occupancyColor(_ fraction: Double) -> Color {
        if fraction < 0.60 { return .green }
        if fraction < 0.85 { return .orange }
        return .red
    }
}