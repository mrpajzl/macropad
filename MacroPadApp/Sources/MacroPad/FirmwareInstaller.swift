import Foundation
import CryptoKit

/// The app ships a tested universal UF2. Never writes settings-reset firmware.
enum FirmwareInstaller {
    struct ImageInfo: Decodable { let sha256: String; let sourceCommit: String; let version: String }
    static var imageURL: URL { Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/macropad-learn.uf2") }
    static var bundledVersion: String {
        (try? JSONDecoder().decode(ImageInfo.self, from: Data(contentsOf:
            imageURL.deletingLastPathComponent().appendingPathComponent("firmware.json"))).version) ?? "Nedostupný"
    }
    static func decodeDeviceVersion(_ data: Data) -> String? {
        guard data.first == 1, (2...64).contains(data.count),
              data.dropFirst().allSatisfy({ (0x21...0x7e).contains($0) }) else { return nil }
        return String(data: data.dropFirst(), encoding: .ascii)
    }
    static func validatedImage() throws -> Data {
        let data = try Data(contentsOf: imageURL)
        let infoURL = imageURL.deletingLastPathComponent().appendingPathComponent("firmware.json")
        let info = try JSONDecoder().decode(ImageInfo.self, from: Data(contentsOf: infoURL))
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard hash == info.sha256 else { throw BLEProtocol.Failure(message: "Kontrolní součet přibaleného firmwaru nesouhlasí.") }
        try validateUF2(data)
        return data
    }
    static func validateUF2(_ data: Data) throws {
        let bytes = [UInt8](data)
        func word(_ offset: Int) -> UInt32 {
            (0..<4).reduce(UInt32(0)) { $0 | UInt32(bytes[offset+$1]) << (8*$1) }
        }
        guard !bytes.isEmpty, bytes.count % 512 == 0 else { throw BLEProtocol.Failure(message: "Poškozený firmware UF2.") }
        let count = bytes.count / 512
        var blocks = Set<UInt32>()
        var addresses = Set<UInt32>()
        for offset in stride(from: 0, to: bytes.count, by: 512) {
            guard word(offset) == 0x0a324655, word(offset+4) == 0x9e5d5157,
                  word(offset+508) == 0x0ab16f30, word(offset+8) == 0x2000,
                  // Pinned XIAO code partition only; never touch settings or bootloader.
                  word(offset+12) >= 0x27000, word(offset+12) <= 0xec000 - 256,
                  word(offset+12) % 256 == 0, addresses.insert(word(offset+12)).inserted,
                  word(offset+28) == 0xada52840, word(offset+16) == 256,
                  word(offset+24) == UInt32(count), word(offset+20) < count,
                  blocks.insert(word(offset+20)).inserted else {
                throw BLEProtocol.Failure(message: "Firmware není platný obraz pro nRF52840.")
            }
        }
    }
    static func isXIAOBootloader(_ info: String) -> Bool {
        let boardIDs: Set<String> = ["Seeed_XIAO_nRF52840", "Seeed_XIAO_nRF52840_Sense",
                                     "nRF52840-SeeedXiao-v1", "nRF52840-SeeedXiaoSense-v1"]
        return info.components(separatedBy: .newlines).contains { line in
            guard line.hasPrefix("Board-ID:") else { return false }
            return boardIDs.contains(String(line.dropFirst("Board-ID:".count)).trimmingCharacters(in: .whitespaces))
        }
    }
    static func volumes() -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: "/Volumes"), includingPropertiesForKeys: nil)) ?? []).filter {
            guard let text = try? String(contentsOf: $0.appendingPathComponent("INFO_UF2.TXT")) else { return false }
            return isXIAOBootloader(text)
        }
    }
    static func install(on volume: URL) throws {
        guard volumes().contains(volume) else { throw BLEProtocol.Failure(message: "Disk XIAO není dostupný. Přepněte pad do nahrávacího režimu a vyberte disk znovu.") }
        let data = try validatedImage()
        let target = volume.appendingPathComponent("macropad.uf2")
        // Stream without metadata, temporary files, or rename (UF2 bootloaders are not ordinary disks).
        guard FileManager.default.createFile(atPath: target.path, contents: nil) else { throw BLEProtocol.Failure(message: "Nelze zapisovat na disk XIAO.") }
        let handle = try FileHandle(forWritingTo: target)
        defer { try? handle.close() }
        try handle.write(contentsOf: data)
        try handle.synchronize()
    }
}
