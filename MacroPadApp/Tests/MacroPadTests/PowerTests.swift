import XCTest
@testable import MacroPad

final class PowerTests: XCTestCase {
    func testTelemetryAndUnknownBattery() throws {
        let p = try XCTUnwrap(PowerStatus.decode(Data([1,15,80,1,0xA0,0x0F,0x10,0x0E,0,0,0,0])))
        XCTAssertEqual(p.mode, .charging)
        XCTAssertEqual(p.millivolts, 4000)
        XCTAssertEqual(p.uptime, 3600)
        XCTAssertEqual(p.profile, 1)
        let usb = try XCTUnwrap(PowerStatus.decode(Data([1,10,255,0,0,0,0,0,0,0,0,0])))
        XCTAssertEqual(usb.mode, .usb)
        XCTAssertNil(usb.percent)
        XCTAssertNil(PowerStatus.decode(Data([1,1,101,0,0,0,0,0,0,0,0,0])))
        XCTAssertNil(PowerStatus.decode(Data([2,0,0,0,0,0,0,0,0,0,0,0])))
        XCTAssertNil(PowerStatus.decode(Data([1])))
    }
    func testTrendRequiresTimeAndResetsAcrossPowerChangesGapsAndReboot() throws {
        let start = Date(timeIntervalSince1970: 1000)
        var h = PowerHistory()
        for i in 0...30 {
            h.append(PowerStatus(percent: 80-i/10, mode: .battery, uptime: UInt32(1000+i*30), date: start.addingTimeInterval(Double(i*30))))
            if i < 30 { XCTAssertNil(h.rate) }
        }
        XCTAssertLessThan(try XCTUnwrap(h.rate), 0)
        h.append(PowerStatus(percent: 77, mode: .charging, uptime: 2000, date: start.addingTimeInterval(930)))
        XCTAssertEqual(h.samples.count, 1)
        h.append(PowerStatus(percent: 78, mode: .charging, uptime: 1, date: start.addingTimeInterval(960)))
        XCTAssertEqual(h.samples.count, 1)
        h.append(PowerStatus(percent: 80, mode: .charging, uptime: 200, date: start.addingTimeInterval(1100)))
        XCTAssertEqual(h.samples.count, 1)
        XCTAssertNil(h.rate)
        XCTAssertFalse(h.samples[0].isFresh(at: start.addingTimeInterval(1200)))
    }
    func testFlatAndUnknownReadingsNeverInventRate() {
        var h = PowerHistory()
        for i in 0...40 { h.append(PowerStatus(percent: 100, mode: .charging, date: Date(timeIntervalSince1970: Double(i*30)))) }
        XCTAssertNil(h.rate)
        h.append(PowerStatus(percent: 99, date: Date(timeIntervalSince1970: 1230)))
        XCTAssertNil(h.rate)
    }
}
