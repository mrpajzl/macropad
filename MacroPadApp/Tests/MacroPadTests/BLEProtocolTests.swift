import XCTest
@testable import MacroPad

final class BLEProtocolTests: XCTestCase {
    // Independently specified firmware defaults, including encoder slot ordering.
    let defaults: [[UInt8]] = [
        [1,1,2,1,0xcd,0,0,0,0,0,0,0,0,0,0,0],
        [1,2,1,1,8,6,0,0,0,0,0,0,0,0,0,0],
        [1,3,4,1,0,0x6d,0,0,0,0,0,0,0,0,0,0],
        [1,13,2,1,0xea,0,0,0,0,0,0,0,0,0,0,0],
        [1,14,2,1,0xe2,0,0,0,0,0,0,0,0,0,0,0],
        [1,15,2,1,0xe9,0,0,0,0,0,0,0,0,0,0,0],
    ]
    func testFirmwareDefaultsAndRoundTrip() throws {
        let macros = try BLEProtocol.decode(Data(defaults.flatMap { $0 }))
        XCTAssertEqual(macros[2]?.chords, [Chord(mods: 8, code: 6)])
        XCTAssertEqual(macros[3]?.kind, .micMute)
        XCTAssertEqual(macros[13]?.media, 0xea)
        var config = PadConfig(); config.slots = macros
        for (i, slot) in BLEProtocol.slotIDs.enumerated() {
            XCTAssertEqual(try BLEProtocol.encode(config, slot: slot), Data(defaults[i]))
        }
    }
    func testAllActionsAndFiveChords() throws {
        for kind in MacroKind.allCases {
            for mouse in MouseAction.allCases {
                var config = PadConfig()
                config.micHotkey = Chord(mods: 0x0d, code: 0x10)
                config[1] = MacroDef(kind: kind, chords: (4...8).map { Chord(mods: 0x80, code: $0) }, media: 0x223, mouse: mouse)
                var bytes = defaults
                bytes[0] = [UInt8](try BLEProtocol.encode(config, slot: 1))
                let decoded = try BLEProtocol.decode(Data(bytes.flatMap { $0 }))[1]!
                XCTAssertEqual(decoded.kind, kind)
                switch kind {
                case .keys: XCTAssertEqual(decoded.chords, config[1].chords)
                case .micMute: XCTAssertEqual(decoded.chords, [config.micHotkey])
                case .media: XCTAssertEqual(decoded.media, 0x223)
                case .mouse: XCTAssertEqual(decoded.mouse, mouse)
                }
            }
        }
    }
    func testRejectsMalformedAndUnsupportedRecords() {
        let original = defaults.flatMap { $0 }
        for size in [0, 15, 95, 97] { XCTAssertThrowsError(try BLEProtocol.decode(Data(repeating: 0, count: size))) }
        for (index, value): (Int, UInt8) in [(0,2),(1,2),(2,9),(3,6),(5,4),(7,1),(14,1),(15,1)] {
            var data = original; data[index] = value
            XCTAssertThrowsError(try BLEProtocol.decode(Data(data)), "index \(index)")
        }
        var config = PadConfig()
        config[1] = MacroDef(chords: Array(repeating: Chord(mods: 0, code: 4), count: 6))
        XCTAssertThrowsError(try BLEProtocol.encode(config, slot: 1))
        XCTAssertThrowsError(try BLEProtocol.encode(config, slot: 99))
        config[1] = MacroDef(chords: [Chord(mods: 0, code: 0)])
        XCTAssertThrowsError(try BLEProtocol.encode(config, slot: 1))
    }
    func testEmptyMacroAndSeparateConfigLocations() throws {
        var config = PadConfig(); config[1] = MacroDef()
        XCTAssertEqual([UInt8](try BLEProtocol.encode(config, slot: 1)), [1,1,1,0] + Array(repeating: 0, count: 12))
        XCTAssertNotEqual(PadConfig.fileURL, PadConfig.xiaoFileURL)
    }
}
