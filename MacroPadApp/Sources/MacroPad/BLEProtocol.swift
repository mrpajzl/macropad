import Foundation

/// Wire format shared with the firmware (docs/ble-protocol.md).
enum BLEProtocol {
    static let slotIDs: [UInt8] = [1, 2, 3, 13, 14, 15]
    static let recordSize = 16
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    static func encode(_ config: PadConfig, slot: UInt8) throws -> Data {
        guard slotIDs.contains(slot) else { throw Failure(message: "Neznámá klávesa.") }
        let macro = config[slot]
        var bytes = [UInt8](repeating: 0, count: recordSize)
        bytes[0] = 1; bytes[1] = slot
        switch macro.kind {
        case .keys, .micMute:
            let chords = macro.kind == .micMute ? [config.micHotkey] : macro.chords
            guard chords.count <= 5, chords.allSatisfy({ (4...0xa4).contains($0.code) }) else {
                throw Failure(message: "Makro může mít nejvýše 5 platných stisků.")
            }
            bytes[2] = macro.kind == .micMute ? 4 : 1
            bytes[3] = UInt8(chords.count)
            for (index, chord) in chords.enumerated() {
                bytes[4 + index * 2] = chord.mods; bytes[5 + index * 2] = chord.code
            }
        case .media:
            guard macro.media > 0, macro.media <= 0x3ff else { throw Failure(message: "Neplatná mediální klávesa.") }
            bytes[2] = 2; bytes[3] = 1
            bytes[4] = UInt8(macro.media & 0xff); bytes[5] = UInt8(macro.media >> 8)
        case .mouse:
            bytes[2] = 3; bytes[3] = 1
            bytes[4] = UInt8(MouseAction.allCases.firstIndex(of: macro.mouse)!)
        }
        return Data(bytes)
    }
    static func decode(_ data: Data) throws -> [UInt8: MacroDef] {
        guard data.count == slotIDs.count * recordSize else {
            throw Failure(message: "Nekompatibilní firmware: chybná délka konfigurace.")
        }
        let all = [UInt8](data)
        var result: [UInt8: MacroDef] = [:]
        for (index, slot) in slotIDs.enumerated() {
            let r = Array(all[(index * recordSize)..<((index + 1) * recordSize)])
            guard r[0] == 1, r[1] == slot, r[14] == 0, r[15] == 0 else {
                throw Failure(message: "Nekompatibilní verze konfigurace.")
            }
            var macro = MacroDef()
            var used = 0
            switch r[2] {
            case 1, 4:
                guard r[3] <= 5, r[2] != 4 || r[3] == 1 else { throw Failure(message: "Poškozené makro.") }
                macro.kind = r[2] == 4 ? .micMute : .keys
                used = Int(r[3]) * 2
                for i in 0..<Int(r[3]) {
                    guard (4...0xa4).contains(r[5 + 2*i]) else { throw Failure(message: "Neplatná klávesa v makru.") }
                    macro.chords.append(Chord(mods: r[4 + 2*i], code: r[5 + 2*i]))
                }
            case 2:
                guard r[3] == 1, r[5] <= 3, r[4] != 0 || r[5] != 0 else { throw Failure(message: "Neplatná mediální klávesa.") }
                macro.kind = .media; macro.media = UInt16(r[4]) | UInt16(r[5]) << 8; used = 2
            case 3:
                guard r[3] == 1, Int(r[4]) < MouseAction.allCases.count else { throw Failure(message: "Neplatná akce myši.") }
                macro.kind = .mouse; macro.mouse = MouseAction.allCases[Int(r[4])]; used = 1
            default: throw Failure(message: "Neznámý typ makra.")
            }
            guard r[(4 + used)...].allSatisfy({ $0 == 0 }) else { throw Failure(message: "Neplatná rezervovaná data.") }
            result[slot] = macro
        }
        return result
    }
}
