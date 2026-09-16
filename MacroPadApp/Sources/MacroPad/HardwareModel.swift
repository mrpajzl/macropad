import Foundation

enum ControlKind: UInt8, Codable, CaseIterable { case button = 1, encoder = 2 }
struct HardwareControl: Codable, Identifiable, Equatable {
    var id: Int
    var kind: ControlKind
    var pin: Int
    var a: Int = 255
    var b: Int = 255
    var x: Int = 0
    var y: Int = 0
    var actions: [MacroDef] = [MacroDef(), MacroDef(), MacroDef()]
    var title: String { "\(kind == .button ? "Tlačítko" : "Encoder") \(id + 1)" }
    var pins: [Int] { kind == .button ? [pin] : [pin, a, b] }
}

struct HardwareProject: Codable, Equatable {
    var controls: [HardwareControl] = []
    static let size = 496
    static func crc(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in bytes {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xedb88320 : 0) }
        }
        return ~crc
    }
    func encode() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: Self.size)
        bytes.replaceSubrange(0..<8, with: [77,80,68,50,2,11,0,0])
        var ids = Set<Int>(), pins = Set<Int>(), cells = Set<Int>()
        for i in 0..<33 { bytes[96 + i * 12] = 1 }
        for control in controls {
            guard (0..<11).contains(control.id), ids.insert(control.id).inserted,
                  (0..<8).contains(control.x), (0..<8).contains(control.y),
                  cells.insert(control.y * 8 + control.x).inserted, control.actions.count == 3 else {
                throw BLEProtocol.Failure(message: "Neplatné nebo překrývající se prvky.")
            }
            for pin in control.pins {
                guard (0..<11).contains(pin), pins.insert(pin).inserted else {
                    throw BLEProtocol.Failure(message: "Pin D\(pin) je neplatný nebo již použitý.")
                }
            }
            guard control.kind == .encoder || (control.a == 255 && control.b == 255) else {
                throw BLEProtocol.Failure(message: "Tlačítko nesmí mít piny encoderu.")
            }
            let offset = 8 + control.id * 8
            bytes.replaceSubrange(offset..<offset+8, with: [control.kind.rawValue, UInt8(control.pin), UInt8(control.a), UInt8(control.b), UInt8(control.x), UInt8(control.y), 0, 0])
            for (action, macro) in control.actions.enumerated() {
                var legacy = PadConfig(); legacy[1] = macro
                let record = [UInt8](try BLEProtocol.encode(legacy, slot: 1))
                let start = 96 + (control.id * 3 + action) * 12
                bytes.replaceSubrange(start..<start+12, with: record[2..<14])
            }
        }
        let checksum = Self.crc(Array(bytes.prefix(492)))
        for i in 0..<4 { bytes[492+i] = UInt8(truncatingIfNeeded: checksum >> (8*i)) }
        return Data(bytes)
    }
    static func decode(_ data: Data) throws -> Self {
        let bytes = [UInt8](data)
        guard bytes.count == size, Array(bytes.prefix(8)) == [77,80,68,50,2,11,0,0] else {
            throw BLEProtocol.Failure(message: "Tento firmware nepodporuje naučené rozložení.")
        }
        let crc = (0..<4).reduce(UInt32(0)) { $0 | UInt32(bytes[492+$1]) << (8*$1) }
        guard crc == Self.crc(Array(bytes.prefix(492))) else { throw BLEProtocol.Failure(message: "Poškozená konfigurace (CRC).") }
        var project = Self()
        for id in 0..<11 {
            let start = 8 + id * 8
            if bytes[start] == 0 { continue }
            guard let kind = ControlKind(rawValue: bytes[start]), bytes[start+6] == 0, bytes[start+7] == 0 else { throw BLEProtocol.Failure(message: "Neznámý ovladač.") }
            var control = HardwareControl(id: id, kind: kind, pin: Int(bytes[start+1]), a: Int(bytes[start+2]), b: Int(bytes[start+3]), x: Int(bytes[start+4]), y: Int(bytes[start+5]))
            for action in 0..<3 {
                let offset = 96 + (id * 3 + action) * 12
                var legacy = Data()
                for slot in BLEProtocol.slotIDs { legacy.append(contentsOf: [1,slot] + Array(bytes[offset..<offset+12]) + [0,0]) }
                control.actions[action] = try BLEProtocol.decode(legacy)[1]!
            }
            project.controls.append(control)
        }
        // Canonical encoding also checks pin and cell uniqueness and unused bytes.
        guard try project.encode() == data else { throw BLEProtocol.Failure(message: "Neplatná konfigurace zapojení.") }
        return project
    }
    mutating func move(_ id: Int, x: Int, y: Int) {
        guard let index = controls.firstIndex(where: { $0.id == id }) else { return }
        if let other = controls.firstIndex(where: { $0.x == x && $0.y == y && $0.id != id }) {
            controls[other].x = controls[index].x; controls[other].y = controls[index].y
        }
        controls[index].x = x; controls[index].y = y
    }
}

/// Consumes loss-detected snapshots; bounce cancels out in the quadrature sum.
struct PinLearner {
    static let quadrature = [0,-1,1,0,1,0,0,-1,-1,0,0,1,0,1,-1,0]
    var samples: [UInt16] = []
    var excluded: Set<Int> = []
    mutating func append(_ mask: UInt16) { if samples.last != mask { samples.append(mask) } }
    func click() throws -> Int {
        guard let initial = samples.first, samples.count >= 3, samples.last == initial else { throw BLEProtocol.Failure(message: "Stiskněte a pusťte jeden ovladač.") }
        let changed = samples.reduce(UInt16(0)) { $0 | ($1 ^ initial) }
        let pins = (0..<11).filter { changed & (1 << $0) != 0 }
        guard pins.count == 1, !excluded.contains(pins[0]), initial & (1 << pins[0]) == 0 else { throw BLEProtocol.Failure(message: "Dotkněte se pouze nového tlačítka; tento pokus byl nejednoznačný.") }
        return pins[0]
    }
    func rotation() throws -> (Int, Int, Int) {
        guard let initial = samples.first else { throw BLEProtocol.Failure(message: "Otočte kolečkem několik kroků.") }
        let changed = samples.reduce(UInt16(0)) { $0 | ($1 ^ initial) }
        let pins = (0..<11).filter { changed & (1 << $0) != 0 }
        guard pins.count == 2, pins.allSatisfy({ !excluded.contains($0) }) else { throw BLEProtocol.Failure(message: "Otáčejte pouze novým encoderem, bez stisku.") }
        var total = 0, valid = 0
        func state(_ mask: UInt16) -> Int { Int((mask >> pins[0]) & 1) * 2 + Int((mask >> pins[1]) & 1) }
        for (previous, next) in zip(samples, samples.dropFirst()) {
            let a = state(previous), b = state(next)
            guard a ^ b != 3 else { throw BLEProtocol.Failure(message: "Otáčejte pomaleji; chybí mezikrok encoderu.") }
            let delta = Self.quadrature[a * 4 + b]; total += delta; valid += abs(delta)
        }
        guard abs(total) >= 8, abs(total) * 2 >= valid else { throw BLEProtocol.Failure(message: "Otočte alespoň dva kroky jedním směrem.") }
        return (pins[0], pins[1], total > 0 ? 1 : -1)
    }
}
