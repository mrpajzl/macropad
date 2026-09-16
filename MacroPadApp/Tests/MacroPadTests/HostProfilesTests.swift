import XCTest
@testable import MacroPad

final class HostProfilesTests: XCTestCase {
    func snapshot(active: UInt8 = 1) -> [UInt8] {
        var b: [UInt8] = [1,3,active,0,1,255,0,0,9,0,0,0]
        for slot in 0..<3 {
            // Slots 0 and 1 share an identity. Slot 2 belongs to a different Mac.
            b += [slot < 2 ? 7 : 1, 0, UInt8(slot < 2 ? 42 : 43), 2,3,4,5,6]
            b += Array(repeating: 0, count: 19)
        }
        return b
    }
    func testGroupsOnlyMatchingIdentitiesAndKeepsActiveDuplicate() throws {
        let p = try XCTUnwrap(HostProfiles.decode(Data(snapshot())))
        XCTAssertEqual(p.hosts.count, 2)
        XCTAssertEqual(p.used, 3)
        XCTAssertEqual(p.hosts[0].slots, [0,1])
        XCTAssertEqual(p.hosts[0].target, 1)
        XCTAssertTrue(p.hosts[0].thisMac)
        XCTAssertTrue(p.hosts[0].selected)
        XCTAssertFalse(p.hosts[1].thisMac)
        XCTAssertEqual(p.destination, "Tento Mac")
    }
    func testUSBIsDistinctFromSelectedBluetoothHostAndPendingPairing() throws {
        var b = snapshot(); b[4] = 0; b[5] = 2; b[6] = 120; b[9] = 1
        let p = try XCTUnwrap(HostProfiles.decode(Data(b)))
        XCTAssertEqual(p.destination, "USB")
        XCTAssertEqual(p.pairingSeconds, 120)
        XCTAssertEqual(p.pairingSlot, 2)
        XCTAssertTrue(p.pending)
    }
    func testRejectsMalformedSnapshotAndUnicodeNamesNeverSplit() {
        XCTAssertNil(HostProfiles.decode(Data(snapshot().dropLast())))
        XCTAssertNil(HostProfiles.decode(Data(snapshot(active: 3))))
        var b = snapshot(); b[0] = 2
        XCTAssertNil(HostProfiles.decode(Data(b)))
        XCTAssertNil(HostProfiles.renamePacket(slot: 0, name: "\n"))
        XCTAssertNil(HostProfiles.renamePacket(slot: 0, name: String(repeating: "ě", count: 10)))
        XCTAssertEqual(HostProfiles.renamePacket(slot: 1, name: " MacBook doma "), Data([2,1]) + Data("MacBook doma".utf8))
        XCTAssertEqual(HostProfiles.renamePacket(slot: 1, name: String(repeating: "ě", count: 9))?.count, 20)
    }
    func testMultiHostCapabilityIsBackwardCompatible() throws {
        var bytes = snapshot()
        XCTAssertFalse(try XCTUnwrap(HostProfiles.decode(Data(bytes))).supportsMultiHost)
        bytes[11] = 5
        let state = try XCTUnwrap(HostProfiles.decode(Data(bytes)))
        XCTAssertTrue(state.supportsMultiHost)
        XCTAssertTrue(state.canRepair)
        XCTAssertFalse(state.repairing)
    }
    func testRepairRequiresAnotherHostAndIncludesExpectedIdentity() throws {
        var b = snapshot(); b[11] = 3
        let profiles = try XCTUnwrap(HostProfiles.decode(Data(b)))
        XCTAssertTrue(profiles.canRepair)
        XCTAssertTrue(profiles.repairing)
        XCTAssertNil(HostProfiles.repairPacket(profiles.hosts[0]))
        XCTAssertEqual(HostProfiles.repairPacket(profiles.hosts[1]), Data([6,2,0xa5,0,43,2,3,4,5,6]))
        XCTAssertFalse(try XCTUnwrap(HostProfiles.decode(Data(snapshot()))).canRepair)
    }

}
