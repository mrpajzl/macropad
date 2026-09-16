import Foundation

struct PowerStatus {
    enum Mode: String { case charging = "Nabíjí se", battery = "Na baterii", usb = "USB · nenabíjí se", unknown = "Stav nabíjení neznámý" }
    var percent: Int?
    var millivolts: Int?
    var mode: Mode = .unknown
    var profile: Int?
    var uptime: UInt32?
    var date = Date()

    static func decode(_ data: Data, at date: Date = Date()) -> PowerStatus? {
        let b = [UInt8](data)
        guard b.count == 12, b[0] == 1 else { return nil }
        let valid = b[1] & 1 != 0
        let mv = Int(b[4]) | Int(b[5]) << 8
        guard !valid || (b[2] <= 100 && (2000...5000).contains(mv)) else { return nil }
        let usb = b[1] & 8 != 0, known = b[1] & 2 != 0
        let mode: Mode = !usb ? .battery : !known ? .unknown : b[1] & 4 != 0 ? .charging : .usb
        let uptime = UInt32(b[6]) | UInt32(b[7]) << 8 | UInt32(b[8]) << 16 | UInt32(b[9]) << 24
        return PowerStatus(percent: valid ? Int(b[2]) : nil, millivolts: valid ? mv : nil,
                           mode: mode, profile: Int(b[3]), uptime: uptime, date: date)
    }
    func isFresh(at now: Date) -> Bool { now.timeIntervalSince(date) < 90 }
}

struct PowerHistory {
    private(set) var samples: [PowerStatus] = []
    mutating func append(_ sample: PowerStatus) {
        if let last = samples.last,
           sample.percent == nil || last.percent == nil || sample.mode != last.mode || sample.date.timeIntervalSince(last.date) > 90 ||
           sample.date <= last.date || (sample.uptime != nil && last.uptime != nil && sample.uptime! < last.uptime!) {
            samples.removeAll()
        }
        samples.append(sample)
        samples.removeAll { sample.date.timeIntervalSince($0.date) > 3600 }
    }
    /// Percentage points/hour from a continuous session, with enough time and signal.
    var rate: Double? {
        let points = samples.filter { $0.percent != nil }
        guard let first = points.first, let last = points.last,
              last.mode == .charging || last.mode == .battery,
              last.date.timeIntervalSince(first.date) >= 900,
              abs(last.percent! - first.percent!) >= 2 else { return nil }
        let hours = points.map { $0.date.timeIntervalSince(first.date) / 3600 }
        let meanX = hours.reduce(0,+) / Double(hours.count)
        let meanY = points.reduce(0.0) { $0 + Double($1.percent!) } / Double(points.count)
        let numerator = zip(hours, points).reduce(0.0) { $0 + ($1.0 - meanX) * (Double($1.1.percent!) - meanY) }
        let denominator = hours.reduce(0.0) { $0 + pow($1 - meanX, 2) }
        guard denominator > 0 else { return nil }
        let slope = numerator / denominator
        guard last.mode == .charging ? slope > 0 : slope < 0 else { return nil }
        return slope
    }
}
