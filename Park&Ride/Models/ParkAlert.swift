import Foundation

struct ParkAlert: Codable {
    var isEnabled: Bool = true
    var startHour: Int = 7
    var startMinute: Int = 0
    var endHour: Int = 9
    var endMinute: Int = 0
    var threshold: Int = 20    // fire when available % drops below this
}