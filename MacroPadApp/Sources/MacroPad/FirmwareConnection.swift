import Foundation
import IOKit

/// Detect a data connection to this Mac, not merely USB power from a charger.
enum FirmwareConnection {
    static func isMacroPad(vendor: Int, product: Int, name: String) -> Bool {
        vendor == 0x1d50 && product == 0x615e && name == "MacroPad"
    }

    static func hasUSBDevice() -> Bool {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOUSBHostDevice"), &iterator) == KERN_SUCCESS else { return false }
        defer { IOObjectRelease(iterator) }
        while case let device = IOIteratorNext(iterator), device != 0 {
            defer { IOObjectRelease(device) }
            func property(_ key: String) -> Any? {
                IORegistryEntryCreateCFProperty(device, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
            }
            if isMacroPad(vendor: (property("idVendor") as? NSNumber)?.intValue ?? 0,
                          product: (property("idProduct") as? NSNumber)?.intValue ?? 0,
                          name: property("USB Product Name") as? String ?? "") { return true }
        }
        return false
    }
}
