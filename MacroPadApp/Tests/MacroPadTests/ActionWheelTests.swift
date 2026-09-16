import XCTest
@testable import MacroPad

final class ActionWheelTests: XCTestCase {
    func testHoldModesRoundTripWithoutChangingClick() throws {
        for mode in HoldMode.allCases {
            let click = MacroDef(chords: [Chord(mods: 8, code: 6)])
            let button = HardwareControl(id: 4, kind: .button, pin: 2,
                actions: [click, MacroDef(), MacroDef()], holdMode: mode)
            let project = HardwareProject(controls: [button])
            let data = try project.encode()
            XCTAssertEqual(data[8 + 4 * 8 + 6], mode.rawValue)
            let loaded = try HardwareProject.decode(data)
            XCTAssertEqual(loaded.controls[0].holdMode, mode)
            XCTAssertEqual(loaded.controls[0].actions[0], click)
            XCTAssertEqual(try loaded.encode(), data)
        }
    }
    func testLegacyJSONDefaultsToOrdinaryClick() throws {
        let data = Data(#"{"id":0,"kind":1,"pin":2}"#.utf8)
        let button = try JSONDecoder().decode(HardwareControl.self, from: data)
        XCTAssertEqual(button.holdMode, .disabled)
        XCTAssertEqual(button.actions.count, 3)
    }
    func testEncoderHoldRoundTripsAndPreservesAllThreeActions() throws {
        for mode in HoldMode.allCases {
            let actions = [MacroDef(kind: .media, media: 0xe2), MacroDef(kind: .media, media: 0xea), MacroDef(kind: .media, media: 0xe9)]
            let encoder = HardwareControl(id: 1, kind: .encoder, pin: 3, a: 4, b: 5, actions: actions, holdMode: mode)
            let remote = try HardwareProject.decode(HardwareProject(controls: [encoder]).encode())
            XCTAssertEqual(remote.controls[0], encoder)
        }
    }
    func testOldFirmwareOnlyOffersButtonWheels() {
        XCTAssertTrue(WheelCapabilities.supports(mode: .actions, kind: .button, version: 1))
        XCTAssertFalse(WheelCapabilities.supports(mode: .device, kind: .button, version: 1))
        XCTAssertFalse(WheelCapabilities.supports(mode: .actions, kind: .encoder, version: 1))
        XCTAssertTrue(WheelCapabilities.supports(mode: .disabled, kind: .encoder, version: 0))
        for mode in HoldMode.allCases {
            XCTAssertTrue(WheelCapabilities.supports(mode: mode, kind: .encoder, version: 2))
        }
    }
    func testReservedCommandsCannotBeReplayedAsActions() {
        XCTAssertTrue(ActionWheel.isReserved(Chord(mods: 0x0d, code: 58)))
        XCTAssertTrue(ActionWheel.isReserved(Chord(mods: 0xf0, code: 68)))
        XCTAssertTrue(ActionWheel.isReserved(Chord(mods: 0x0d, code: 104)))
        XCTAssertFalse(ActionWheel.isReserved(Chord(mods: 8, code: 6)))
        XCTAssertFalse(ActionWheel.isReserved(Chord(mods: 0, code: 58)))
    }
    func testSelectionWrapsBothWaysAndEmptyMenuIsSafe() {
        var selection = WheelSelection(count: 3)
        selection.rotate(-1); XCTAssertEqual(selection.index, 2)
        selection.rotate(1); XCTAssertEqual(selection.index, 0)
        selection.rotate(7); XCTAssertEqual(selection.index, 1)
        selection = WheelSelection(count: 0)
        selection.rotate(-1); XCTAssertEqual(selection.index, 0)
    }
    func testLocalActionRoundTripPreservesUnicodeAndShortcutArguments() throws {
        let action = WheelAction(title: "Práce", kind: .shortcut, shortcutName: "Moje zkratka '$(test)'", chords: [Chord(mods: 8, code: 6)])
        XCTAssertEqual(try JSONDecoder().decode(WheelAction.self, from: JSONEncoder().encode(action)), action)
    }
}
