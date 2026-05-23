import Foundation

@MainActor
@Observable
final class ParkingViewModel {
    var carParks: [BackendCarPark] = []
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?
    var secondsUntilRefresh = 0
    var pinnedIDs: Set<String> = {
        let raw = UserDefaults.standard.string(forKey: "pinned_facility_ids") ?? ""
        return Set(raw.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }()

    func togglePin(_ carPark: BackendCarPark) {
        if pinnedIDs.contains(carPark.facility_id) {
            pinnedIDs.remove(carPark.facility_id)
        } else {
            pinnedIDs.insert(carPark.facility_id)
        }
        UserDefaults.standard.set(pinnedIDs.joined(separator: ","), forKey: "pinned_facility_ids")
    }

    func isPinned(_ carPark: BackendCarPark) -> Bool {
        pinnedIDs.contains(carPark.facility_id)
    }

    private var refreshTask: Task<Void, Never>?
    private let refreshInterval = 60

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
            carParks = try await BackendService.shared.fetchAllCarParks()
            lastUpdated = Date()
            secondsUntilRefresh = refreshInterval
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
