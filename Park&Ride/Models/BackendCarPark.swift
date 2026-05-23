import Foundation

struct OccupancyReading: Decodable, Identifiable {
    let timestamp: Date
    let available: Int
    let total: Int
    let occupancy_fraction: Double?

    var id: Date { timestamp }
    var fraction: Double { occupancy_fraction ?? 0 }
}

struct ParkLocation {
    let suburb: String?
    let address: String?
    let latitude: String?
    let longitude: String?
}

struct BackendCarPark: Codable, Identifiable {
    let facility_id: String
    let facility_name: String?
    let available_spots: Int?
    let total_spots: Int?
    let suburb: String?
    let address: String?
    let latitude: String?
    let longitude: String?
    let updated_at: String?

    var id: String { facility_id }
    var availableSpots: Int? { available_spots }
    var totalSpots: Int? { total_spots }

    var occupancyFraction: Double? {
        guard let total = total_spots, total > 0,
              let available = available_spots else { return nil }
        let occupied = total - available
        return Double(max(0, min(total, occupied))) / Double(total)
    }

    var location: ParkLocation? {
        guard suburb != nil || address != nil || latitude != nil else { return nil }
        return ParkLocation(suburb: suburb, address: address, latitude: latitude, longitude: longitude)
    }

    var MessageDate: String? { updated_at }
}
