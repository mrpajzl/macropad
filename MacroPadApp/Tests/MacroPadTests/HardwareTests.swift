import XCTest
import CryptoKit
@testable import MacroPad

final class HardwareTests: XCTestCase {
    func testDeviceRoundTripAndStableIDsAfterMove() throws {
        var project = HardwareProject(controls: [
            HardwareControl(id: 7, kind: .encoder, pin: 3, a: 4, b: 5, x: 1, y: 0,
                actions: [MacroDef(kind: .micMute), MacroDef(kind: .media, media: 0xea), MacroDef(kind: .media, media: 0xe9)]),
            HardwareControl(id: 2, kind: .button, pin: 0, actions: [MacroDef(chords: [Chord(mods: 8, code: 6)]), MacroDef(), MacroDef()])
        ])
        project.controls.sort { $0.id < $1.id }
        let data = try project.encode()
        XCTAssertEqual(data.count, 496)
        let remote = try HardwareProject.decode(data)
        XCTAssertEqual(try remote.encode(), data) // Another host needs no local state.
        project.move(7, x: 0, y: 0)
        XCTAssertEqual(project.controls[0].id, 2)
        XCTAssertEqual(project.controls[0].x, 1)
        XCTAssertEqual(project.controls[1].pin, 3)
        XCTAssertEqual(project.controls[1].actions[1].media, 0xea)
        XCTAssertEqual(try HardwareProject.decode(project.encode()).encode(), try project.encode())
    }
    func testRejectConflictingPinsCellsAndCorruption() throws {
        let button = HardwareControl(id: 0, kind: .button, pin: 0)
        var project = HardwareProject(controls: [button, HardwareControl(id: 1, kind: .button, pin: 0, x: 1)])
        XCTAssertThrowsError(try project.encode())
        project.controls[1].pin = 1; project.controls[1].x = 0
        XCTAssertThrowsError(try project.encode())
        project.controls[1].x = 1
        var data = try project.encode(); data[100] ^= 1
        XCTAssertThrowsError(try HardwareProject.decode(data))
        XCTAssertThrowsError(try HardwareProject.decode(Data(data.prefix(100))))
        project.controls[1].a = 999
        XCTAssertThrowsError(try project.encode()) // No UInt8 conversion trap.
    }
    func testClickBounceAmbiguityAndUsedPins() throws {
        var learner = PinLearner(samples: [0,4,0,4,0])
        XCTAssertEqual(try learner.click(), 2)
        learner.excluded = [2]; XCTAssertThrowsError(try learner.click())
        learner = PinLearner(samples: [0,4,12,8,0]); XCTAssertThrowsError(try learner.click())
        learner = PinLearner(samples: [0,4]); XCTAssertThrowsError(try learner.click())
        learner = PinLearner(samples: [4,0,4]); XCTAssertThrowsError(try learner.click())
    }
    func testQuadratureDirectionBounceAndMissingEdges() throws {
        let forward: [UInt16] = [0,16,48,32,0,16,48,32,0]
        var learner = PinLearner(samples: forward)
        let cw = try learner.rotation()
        XCTAssertEqual(cw.0, 4); XCTAssertEqual(cw.1, 5); XCTAssertEqual(cw.2, 1)
        learner.samples = Array(forward.reversed())
        XCTAssertEqual(try learner.rotation().2, -1)
        learner.samples = [0,16,0,16,48,32,0,16,48,32,0]
        XCTAssertEqual(try learner.rotation().2, 1)
        learner.samples = [0,48,32,0,16,48,32,0]
        XCTAssertThrowsError(try learner.rotation())
        learner.samples = forward; learner.excluded = [4]
        XCTAssertThrowsError(try learner.rotation())
    }
    func testCRCStandardVectorAndUF2RejectsWrongFamily() throws {
        XCTAssertEqual(HardwareProject.crc(Array("123456789".utf8)), 0xcbf43926)
        XCTAssertThrowsError(try FirmwareInstaller.validateUF2(Data()))
        XCTAssertThrowsError(try FirmwareInstaller.validateUF2(Data(repeating: 0, count: 512)))
    }
    func testBundledFirmwareMatchesManifestAndBoardFamily() throws {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Firmware")
        let data = try Data(contentsOf: folder.appendingPathComponent("macropad-learn.uf2"))
        let info = try JSONDecoder().decode(FirmwareInstaller.ImageInfo.self, from: Data(contentsOf: folder.appendingPathComponent("firmware.json")))
        XCTAssertEqual(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), info.sha256)
        try FirmwareInstaller.validateUF2(data)
        var badFamily = data
        badFamily[28] ^= 1
        XCTAssertThrowsError(try FirmwareInstaller.validateUF2(badFamily))
    }
}
