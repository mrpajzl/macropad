import XCTest
@testable import MacroPad

final class OTAFirmwareTests: XCTestCase {
    func testUSBDetectionRejectsOtherZMKDevices() {
        XCTAssertTrue(FirmwareConnection.isMacroPad(vendor: 0x1d50, product: 0x615e, name: "MacroPad"))
        XCTAssertFalse(FirmwareConnection.isMacroPad(vendor: 0x1d50, product: 0x615e, name: "Other Keyboard"))
        XCTAssertFalse(FirmwareConnection.isMacroPad(vendor: 0x2886, product: 0x0045, name: "MacroPad"))
        XCTAssertFalse(FirmwareConnection.isMacroPad(vendor: 0x1d50, product: 0, name: "MacroPad"))
    }
    func testXIAOBootloaderIdentities() {
        for board in ["Seeed_XIAO_nRF52840", "Seeed_XIAO_nRF52840_Sense",
                      "nRF52840-SeeedXiao-v1", "nRF52840-SeeedXiaoSense-v1"] {
            XCTAssertTrue(FirmwareInstaller.isXIAOBootloader("UF2 Bootloader\r\nBoard-ID: \(board)\r\nSoftDevice: S140 7.3.0\r\n"))
        }
        for info in ["", "Model: Seeed XIAO nRF52840", "Board-ID: Seeed_XIAO_nRF52840_other",
                     "Board-ID: nRF52840-Nano33BLE-v1", "Comment: Board-ID: nRF52840-SeeedXiaoSense-v1"] {
            XCTAssertFalse(FirmwareInstaller.isXIAOBootloader(info))
        }
    }
    private func block(index: UInt32, address: UInt32, byte: UInt8) -> Data {
        var data = Data(repeating: 0, count: 512)
        for (offset, value) in [(0, UInt32(0x0a324655)), (4, 0x9e5d5157), (8, 0x2000),
                                (12, address), (16, 256), (20, index), (24, 2), (28, 0xada52840), (508, 0x0ab16f30)] {
            for i in 0..<4 { data[offset+i] = UInt8(truncatingIfNeeded: value >> (8*i)) }
        }
        data.replaceSubrange(32..<288, with: repeatElement(byte, count: 256))
        return data
    }
    func testCRCAndLegacyInitPacket() throws {
        XCTAssertEqual(OTAFirmware.crc16(Data("123456789".utf8)), 0x29b1)
        let image = try OTAFirmware.image(uf2: block(index: 1, address: 0x27100, byte: 2) + block(index: 0, address: 0x27000, byte: 1), softDevice: 0x0123)
        XCTAssertEqual(image.binary, Data(repeating: 1, count: 256) + Data(repeating: 2, count: 256))
        XCTAssertEqual(image.initPacket.prefix(12), Data([0x52, 0, 0xff, 0xff, 0, 0, 0, 0, 1, 0, 0x23, 1]))
        let crc = OTAFirmware.crc16(image.binary)
        XCTAssertEqual(image.initPacket.suffix(2), Data([UInt8(truncatingIfNeeded: crc), UInt8(crc >> 8)]))
    }
    func testRejectsMissingBeginningHolesAndUnknownSoftDevice() {
        let first = block(index: 0, address: 0x27000, byte: 1)
        XCTAssertThrowsError(try OTAFirmware.image(uf2: first + block(index: 1, address: 0x27200, byte: 2), softDevice: 0x0123))
        XCTAssertThrowsError(try OTAFirmware.image(uf2: block(index: 0, address: 0x27100, byte: 1) + block(index: 1, address: 0x27200, byte: 2), softDevice: 0x0123))
        for id: UInt16 in [0, 0xffff] {
            XCTAssertThrowsError(try OTAFirmware.image(uf2: first + block(index: 1, address: 0x27100, byte: 2), softDevice: id))
        }
    }
    func testBundledImageCanBeConvertedWithoutChangingPayload() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let uf2 = try Data(contentsOf: root.appendingPathComponent("Firmware/macropad-learn.uf2"))
        let image = try OTAFirmware.image(uf2: uf2, softDevice: 0x0123)
        XCTAssertEqual(image.binary.count, uf2.count / 2)
        XCTAssertLessThanOrEqual(image.binary.count, 0xec000 - 0x27000)
    }
    func testRejectsOtherDfuHardware() {
        XCTAssertTrue(OTAPad.isXIAO(manufacturer: "Seeed", model: "XIAO nRF52840 Sense"))
        XCTAssertFalse(OTAPad.isXIAO(manufacturer: "Adafruit", model: "Feather nRF52840"))
        XCTAssertFalse(OTAPad.isXIAO(manufacturer: "Seeed", model: "XIAO ESP32"))
    }
}
