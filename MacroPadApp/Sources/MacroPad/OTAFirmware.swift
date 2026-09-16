import Foundation

/// Application-only Nordic Legacy DFU payload; preserves the XIAO settings partition.
enum OTAFirmware {
    struct Image { let binary: Data; let initPacket: Data }
    static func crc16(_ data: Data) -> UInt16 {
        var crc: UInt16 = 0xffff
        for byte in data {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 { crc = crc & 0x8000 != 0 ? (crc &<< 1) ^ 0x1021 : crc &<< 1 }
        }
        return crc
    }
    static func image(uf2: Data, softDevice: UInt16) throws -> Image {
        try FirmwareInstaller.validateUF2(uf2)
        guard softDevice != 0, softDevice != 0xffff else {
            throw BLEProtocol.Failure(message: "Neznámý SoftDevice; bezdrátové nahrání nelze připravit.")
        }
        let bytes = [UInt8](uf2)
        func word(_ offset: Int) -> UInt32 {
            (0..<4).reduce(0) { $0 | UInt32(bytes[offset+$1]) << (8*$1) }
        }
        let offsets = Array(stride(from: 0, to: bytes.count, by: 512))
        // The DFU bootloader writes a contiguous binary at the end of S140.
        // Require all blocks, starting at exactly the application's linked address.
        let addresses = offsets.map { Int(word($0 + 12)) }.sorted()
        guard addresses.first == 0x27000,
              addresses.enumerated().allSatisfy({ $0.element == 0x27000 + $0.offset * 256 }) else {
            throw BLEProtocol.Failure(message: "Obraz nemá souvislou oblast aplikace pro Bluetooth DFU.")
        }
        var binary = Data(repeating: 0, count: addresses.count * 256)
        for offset in offsets {
            let address = Int(word(offset+12)) - 0x27000
            binary.replaceSubrange(address..<(address+256), with: bytes[(offset+32)..<(offset+288)])
        }
        var packet = Data()
        func append16(_ value: UInt16) { packet.append(UInt8(truncatingIfNeeded: value)); packet.append(UInt8(value >> 8)) }
        append16(0x0052) // Adafruit application image device type; not the bootloader unlock revision.
        append16(0xffff)
        packet.append(contentsOf: [0, 0, 0, 0]) // Application version is verified by our app after reboot.
        append16(1); append16(softDevice); append16(crc16(binary))
        return Image(binary: binary, initPacket: packet)
    }
}
