import Foundation

struct SavedHost: Identifiable {
    let id: String
    var slots: [Int]
    var name: String
    var connected: Bool
    var thisMac: Bool
    var selected: Bool
    var target: Int
    var title: String { name.isEmpty ? (thisMac ? "Tento Mac" : "Zařízení \(slots[0] + 1)") : name }
}
struct HostProfiles {
    let active: Int
    let usbOutput: Bool
    let pairingSlot: Int?
    let pairingSeconds: Int
    let sequence: UInt8
    let pending: Bool
    let failed: Bool
    let capacity: Int
    let used: Int
    let hosts: [SavedHost]
    let date: Date
    var fresh: Bool { Date().timeIntervalSince(date) < 15 }
    var destination: String {
        if usbOutput { return "USB" }
        if pairingSlot != nil { return "Párování nového zařízení" }
        guard let host = hosts.first(where: { $0.selected }) else { return "Žádné vybrané zařízení" }
        return host.connected ? host.title : "Čekám na \(host.title)"
    }
    static func decode(_ data: Data) -> HostProfiles? {
        let b = [UInt8](data)
        guard b.count >= 12, b[0] == 1, (1...10).contains(Int(b[1])),
              b.count == 12 + Int(b[1])*27, b[2] < b[1], b[4] <= 1,
              b[3] == 255 || b[3] < b[1], b[5] == 255 || b[5] < b[1] else { return nil }
        var hosts: [SavedHost] = [], used = 0
        for slot in 0..<Int(b[1]) {
            let row = Array(b[(12+slot*27)..<(12+(slot+1)*27)])
            guard row[0] & 1 != 0 else { continue }
            used += 1
            let identity = row[1...7].map { String(format: "%02x", $0) }.joined()
            guard let name = String(bytes: row[8...26].prefix(while: { $0 != 0 }), encoding: .utf8) else { return nil }
            let selected = slot == Int(b[2])
            if let index = hosts.firstIndex(where: { $0.id == identity }) {
                hosts[index].slots.append(slot)
                hosts[index].connected = hosts[index].connected || row[0] & 2 != 0
                hosts[index].thisMac = hosts[index].thisMac || row[0] & 4 != 0
                if selected { hosts[index].selected = true; hosts[index].target = slot }
                if hosts[index].name.isEmpty { hosts[index].name = name }
            } else {
                hosts.append(SavedHost(id: identity, slots: [slot], name: name, connected: row[0] & 2 != 0,
                                       thisMac: row[0] & 4 != 0, selected: selected, target: slot))
            }
        }
        return HostProfiles(active: Int(b[2]), usbOutput: b[4] == 0,
                            pairingSlot: b[5] == 255 ? nil : Int(b[5]), pairingSeconds: Int(b[6]) | Int(b[7]) << 8,
                            sequence: b[8], pending: b[9] != 0, failed: b[10] != 0, capacity: Int(b[1]), used: used,
                            hosts: hosts, date: Date())
    }
    static func renamePacket(slot: Int, name: String) -> Data? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (0..<10).contains(slot), !clean.isEmpty, clean.utf8.count <= 18,
              !clean.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return nil }
        return Data([2, UInt8(slot)]) + Data(clean.utf8)
    }
}
