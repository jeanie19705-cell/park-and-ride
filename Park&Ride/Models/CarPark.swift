import Foundation

// API returns a flat array: [CarPark]
struct CarPark: Codable, Identifiable {
    var id: String { facility_id ?? tfnsw_facility_id ?? "unknown" }

    let tsn: String?
    let spots: FlexibleInt?          // total capacity
    let occupancy: Occupancy?
    let zones: [ParkingZone]?
    let location: ParkLocation?
    let facility_id: String?
    let facility_name: String?
    let tfnsw_facility_id: String?
    let MessageDate: String?

    // Top-level: prefer `total`, fall back to `loop`
    var occupiedCount: Int? {
        occupancy?.total?.value ?? occupancy?.loop?.value
    }

    var totalSpots: Int? { spots?.value }

    var availableSpots: Int? {
        guard let total = totalSpots, let occupied = occupiedCount else { return nil }
        return max(0, total - max(0, occupied))   // clamp negative sensor readings
    }

    var occupancyFraction: Double? {
        guard let total = totalSpots, total > 0, let occupied = occupiedCount else { return nil }
        return Double(max(0, min(total, occupied))) / Double(total)
    }
}

struct Occupancy: Codable {
    let total: FlexibleInt?
    let loop: FlexibleInt?
    let transients: FlexibleInt?
    let monthlies: FlexibleInt?
    let open_gate: FlexibleInt?
}

struct ParkingZone: Codable, Identifiable {
    var id: String { zone_id ?? zone_name ?? UUID().uuidString }
    let zone_id: String?
    let zone_name: String?
    let spots: FlexibleInt?
    let occupancy: Occupancy?
    let parent_zone_id: String?

    // Zones with zone_id "0" and no name are API placeholders
    var isPlaceholder: Bool {
        zone_id == "0" || (zone_name?.isEmpty != false && (spots?.value ?? 0) == 0)
    }

    // Zone level: prefer loop (newer parks store it there)
    var occupiedCount: Int? {
        occupancy?.loop?.value ?? occupancy?.total?.value
    }

    var availableSpots: Int? {
        guard let total = spots?.value, let occupied = occupiedCount else { return nil }
        return max(0, total - max(0, occupied))
    }
}

struct ParkLocation: Codable {
    let suburb: String?
    let address: String?
    let latitude: String?
    let longitude: String?
}

// Decodes both integer 500 and string "500" (or "-2") from JSON
struct FlexibleInt: Codable {
    let value: Int

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) {
            value = i
        } else if let s = try? c.decode(String.self), let i = Int(s) {
            value = i
        } else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Expected Int or numeric String")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(value)
    }
}