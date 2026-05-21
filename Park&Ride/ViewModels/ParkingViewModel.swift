import Foundation

@MainActor
@Observable
final class ParkingViewModel {
    var carParks: [CarPark] = []
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?
    var secondsUntilRefresh = 0
    var pinnedIDs: Set<String> = {
        let raw = UserDefaults.standard.string(forKey: "pinned_facility_ids") ?? ""
        return Set(raw.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }()

    func togglePin(_ carPark: CarPark) {
        guard let id = carPark.facility_id else { return }
        if pinnedIDs.contains(id) { pinnedIDs.remove(id) } else { pinnedIDs.insert(id) }
        UserDefaults.standard.set(pinnedIDs.joined(separator: ","), forKey: "pinned_facility_ids")
    }

    func isPinned(_ carPark: CarPark) -> Bool {
        carPark.facility_id.map { pinnedIDs.contains($0) } ?? false
    }

    private func checkAlerts() {
        let calendar = Calendar.current
        let now = Date()
        let currentMinutes = calendar.component(.hour, from: now) * 60
                           + calendar.component(.minute, from: now)
        let alerts = AlertStore.all()

        for park in carParks {
            guard let id = park.facility_id,
                  let alert = alerts[id], alert.isEnabled else { continue }

            let start = alert.startHour * 60 + alert.startMinute
            let end   = alert.endHour   * 60 + alert.endMinute
            guard currentMinutes >= start && currentMinutes <= end else { continue }

            guard let available = park.availableSpots,
                  let total = park.totalSpots, total > 0 else { continue }

            let pct = Int(Double(available) / Double(total) * 100)
            guard pct < alert.threshold else { continue }

            // Throttle to once per 30 minutes per facility
            if let last = lastNotified[id], now.timeIntervalSince(last) < 1800 { continue }
            lastNotified[id] = now

            NotificationService.fire(
                facilityId: id,
                title: park.facility_name ?? "Park & Ride",
                body: "Only \(pct)% available — \(available) of \(total) spaces left."
            )
        }
    }

    private var refreshTask: Task<Void, Never>?
    private let refreshInterval = 60
    private var lastNotified: [String: Date] = [:]

    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            await refresh()
            while !Task.isCancelled {
                for remaining in stride(from: refreshInterval - 1, through: 0, by: -1) {
                    guard !Task.isCancelled else { return }
                    secondsUntilRefresh = remaining
                    try? await Task.sleep(for: .seconds(1))
                }
                await refresh()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            carParks = try await ParkingService.shared.fetchAllCarParks()
            lastUpdated = Date()
            secondsUntilRefresh = refreshInterval
            checkAlerts()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}