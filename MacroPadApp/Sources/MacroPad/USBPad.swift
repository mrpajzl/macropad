import Foundation
import IOKit
import IOKit.usb

/// Zápis do konfiguračního rozhraní padu (interface 1, interrupt OUT 0x02) přes IOKit.
final class USBPad {
    static let vid: Int = 0x1189
    static let pid: Int = 0x8890
    static let interfaceNumber: Int = 1

    struct PadError: LocalizedError {
        let msg: String
        var errorDescription: String? { msg }
    }

    // UUID konstanty z IOUSBLib.h (Swift makra neimportuje)
    private static let kIOUSBInterfaceUserClientTypeID = CFUUIDGetConstantUUIDWithBytes(nil, 0x2d,0x97,0x86,0xc6,0x9e,0xf3,0x11,0xd4,0xad,0x51,0x00,0x0a,0x27,0x05,0x28,0x61)
    private static let kIOUSBInterfaceInterfaceID      = CFUUIDGetConstantUUIDWithBytes(nil, 0x73,0xc9,0x7a,0xe8,0x9e,0xf3,0x11,0xd4,0xb1,0xd0,0x00,0x0a,0x27,0x05,0x28,0x61)
    private static let kIOCFPlugInInterfaceID          = CFUUIDGetConstantUUIDWithBytes(nil, 0xC2,0x44,0xE8,0x58,0x10,0x9C,0x11,0xD4,0x91,0xD4,0x00,0x50,0xE4,0xC6,0x42,0x6F)

    private static func matchingDict() -> CFMutableDictionary {
        let dict = IOServiceMatching("IOUSBHostInterface")! as NSMutableDictionary
        dict[kIOPropertyMatchKey] = ["idVendor": vid, "idProduct": pid, "bInterfaceNumber": interfaceNumber] as NSDictionary
        return dict as CFMutableDictionary
    }

    /// Je pad připojený?
    static func isConnected() -> Bool {
        let svc = IOServiceGetMatchingService(kIOMainPortDefault, matchingDict())
        guard svc != 0 else { return false }
        IOObjectRelease(svc)
        return true
    }

    /// Pošle sekvenci 64B paketů (s inicializačním nulovým paketem).
    static func write(_ packets: [[UInt8]], delayMs: UInt32 = 15) throws {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matchingDict())
        guard service != 0 else { throw PadError(msg: "Pad nenalezen (1189:8890). Použij datový kabel, ne jen nabíjecí.") }
        defer { IOObjectRelease(service) }

        var plugin: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
        var score: Int32 = 0
        var kr = IOCreatePlugInInterfaceForService(service, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID, &plugin, &score)
        guard kr == kIOReturnSuccess, let plug = plugin, let plugI = plug.pointee else { throw PadError(msg: String(format: "IOCreatePlugInInterfaceForService: 0x%08x", kr)) }
        defer { _ = plugI.pointee.Release(plug) }

        var raw: LPVOID?
        let hr = plugI.pointee.QueryInterface(plug, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID), &raw)
        guard hr == S_OK, let rawI = raw else { throw PadError(msg: "QueryInterface selhalo") }
        let iface = rawI.assumingMemoryBound(to: UnsafeMutablePointer<IOUSBInterfaceInterface>?.self)
        guard let ifI = iface.pointee else { throw PadError(msg: "USB interface nedostupné") }
        defer { _ = ifI.pointee.Release(iface) }

        kr = ifI.pointee.USBInterfaceOpen(iface)
        guard kr == kIOReturnSuccess else { throw PadError(msg: String(format: "USBInterfaceOpen: 0x%08x (drží ho jiná aplikace?)", kr)) }
        defer { _ = ifI.pointee.USBInterfaceClose(iface) }

        var numEndpoints: UInt8 = 0
        _ = ifI.pointee.GetNumEndpoints(iface, &numEndpoints)
        var outPipe: UInt8 = 0
        for pipe in 1...max(1, numEndpoints) {
            var dir: UInt8 = 0, num: UInt8 = 0, type: UInt8 = 0, maxPkt: UInt16 = 0, interval: UInt8 = 0
            if ifI.pointee.GetPipeProperties(iface, pipe, &dir, &num, &type, &maxPkt, &interval) == kIOReturnSuccess, dir == UInt8(kUSBOut) {
                outPipe = pipe; break
            }
        }
        guard outPipe != 0 else { throw PadError(msg: "Nenalezen výstupní endpoint") }

        func send(_ p: [UInt8]) throws {
            var buf = [UInt8](repeating: 0, count: 64)
            for (i, b) in p.prefix(64).enumerated() { buf[i] = b }
            let r = buf.withUnsafeMutableBytes { ifI.pointee.WritePipe(iface, outPipe, $0.baseAddress, 64) }
            guard r == kIOReturnSuccess else { throw PadError(msg: String(format: "WritePipe: 0x%08x", r)) }
            usleep(delayMs * 1000)
        }
        try send([])                    // inicializace
        for p in packets { try send(p) }
    }
}
