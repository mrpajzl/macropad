import XCTest
@testable import MacroPad

final class DeviceWheelTests: XCTestCase {
    private func snapshot(date: Date = Date(), pending: Bool = false) -> HostProfiles {
        HostProfiles(active: 1, usbOutput: false, pairingSlot: nil, pairingSeconds: 0, sequence: 0,
            pending: pending, failed: false, canRepair: true, repairing: false, supportsMultiHost: true, capacity: 5, used: 1,
            hosts: [SavedHost(id: "identity", slots: [1], name: "Pracovní Mac", connected: true, thisMac: false, selected: true, target: 1)], date: date)
    }
    func testMenuStartsWithCancelAndShowsCurrentHostAndBattery() {
        let power = PowerStatus(percent: 76, mode: .charging)
        let entries = DeviceWheelMenu.entries(hosts: snapshot(), power: power, ready: true, busy: false, muted: false)
        XCTAssertEqual(entries.first?.command, .dismiss)
        XCTAssertEqual(entries.first { $0.id == "host-identity" }?.subtitle, "Právě ovládáno")
        XCTAssertEqual(entries.first { $0.id == "battery" }?.subtitle, "76 % · Nabíjí se")
        XCTAssertTrue(entries.first { $0.id == "usb" }!.enabled)
        XCTAssertEqual(Set(entries.map(\.id)).count, entries.count)
    }
    func testStalePowerNeverOffersUSBSwitchOrInventsBattery() {
        let stale = PowerStatus(percent: 76, mode: .usb, date: Date().addingTimeInterval(-120))
        let entries = DeviceWheelMenu.entries(hosts: snapshot(), power: stale, ready: true, busy: false, muted: false)
        XCTAssertFalse(entries.first { $0.id == "usb" }!.enabled)
        XCTAssertEqual(entries.first { $0.id == "battery" }?.subtitle, "Čekám na měření")
        XCTAssertNil(DeviceWheelMenu.hostPacket(for: .usb, hosts: snapshot(), power: stale, ready: true, busy: false))
    }
    func testHostIdentityAndConnectionAreRevalidatedOnRelease() {
        let command = DeviceWheelCommand.host(identity: "identity", slot: 1)
        XCTAssertEqual(DeviceWheelMenu.hostPacket(for: command, hosts: snapshot(), power: nil, ready: true, busy: false), Data([1,1]))
        XCTAssertNil(DeviceWheelMenu.hostPacket(for: .host(identity: "replaced", slot: 1), hosts: snapshot(), power: nil, ready: true, busy: false))
        XCTAssertNil(DeviceWheelMenu.hostPacket(for: command, hosts: snapshot(date: .distantPast), power: nil, ready: true, busy: false))
        XCTAssertNil(DeviceWheelMenu.hostPacket(for: command, hosts: snapshot(pending: true), power: nil, ready: true, busy: false))
        XCTAssertNil(DeviceWheelMenu.hostPacket(for: command, hosts: snapshot(), power: nil, ready: false, busy: false))
        XCTAssertNil(DeviceWheelMenu.hostPacket(for: command, hosts: snapshot(), power: nil, ready: true, busy: true))
    }
    func testBusyDeviceDisablesRoutingButLeavesLocalActions() {
        let entries = DeviceWheelMenu.entries(hosts: snapshot(), power: PowerStatus(percent: 50, mode: .usb), ready: true, busy: true, muted: true)
        XCTAssertFalse(entries.first { $0.id == "host-identity" }!.enabled)
        XCTAssertFalse(entries.first { $0.id == "usb" }!.enabled)
        XCTAssertTrue(entries.first { $0.id == "mic" }!.enabled)
        XCTAssertEqual(entries.first { $0.id == "mic" }?.title, "Zapnout mikrofon")
    }
}
