import SwiftUI

/// Stable snapshot for one gesture: background BLE refresh must not move the selection.
enum DeviceWheelCommand: Equatable {
    case dismiss, host(identity: String, slot: Int), usb, battery, microphone, settings, hosts
}
struct DeviceWheelEntry: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let command: DeviceWheelCommand
    var enabled = true
}
enum DeviceWheelMenu {
    static func entries(hosts: HostProfiles?, power: PowerStatus?, ready: Bool, busy: Bool,
                        muted: Bool, now: Date = Date()) -> [DeviceWheelEntry] {
        var result = [DeviceWheelEntry(id: "dismiss", title: "Zavřít", subtitle: "Beze změny", symbol: "xmark", command: .dismiss)]
        let available = ready && !busy && hosts?.fresh == true && hosts?.pending == false && hosts?.pairingSlot == nil
        if let hosts, hosts.fresh, ready {
            for host in hosts.hosts {
                let current = host.selected && !hosts.usbOutput
                result.append(DeviceWheelEntry(id: "host-" + host.id, title: host.title,
                    subtitle: current ? "Právě ovládáno" : host.connected ? "Přepnout ovládání" : "Uloženo · odpojeno",
                    symbol: current ? "laptopcomputer.and.arrow.down" : "laptopcomputer",
                    command: .host(identity: host.id, slot: host.target), enabled: available))
            }
        } else {
            result.append(DeviceWheelEntry(id: "hosts", title: "Zařízení", subtitle: ready ? "Načíst seznam" : "Pad odpojen", symbol: "laptopcomputer", command: .hosts, enabled: ready))
        }
        let usb = ready && power?.isFresh(at: now) == true && (power?.mode == .usb || power?.mode == .charging)
        result.append(DeviceWheelEntry(id: "usb", title: "Výstup USB", subtitle: hosts?.usbOutput == true && ready && hosts?.fresh == true ? "Právě ovládáno" : usb ? "Přepnout na kabel" : "Připojte datový kabel", symbol: "cable.connector", command: .usb, enabled: available && usb))
        result.append(DeviceWheelEntry(id: "battery", title: "Baterie padu", subtitle: batterySummary(power, ready: ready, now: now), symbol: power?.mode == .charging ? "battery.100.bolt" : "battery.100", command: .battery))
        result.append(DeviceWheelEntry(id: "mic", title: muted ? "Zapnout mikrofon" : "Ztišit mikrofon", subtitle: "Na tomto Macu", symbol: muted ? "mic.fill" : "mic.slash.fill", command: .microphone))
        result.append(DeviceWheelEntry(id: "settings", title: "Nastavení", subtitle: "Otevřít MacroPad", symbol: "slider.horizontal.3", command: .settings))
        return result
    }
    static func batterySummary(_ power: PowerStatus?, ready: Bool, now: Date = Date()) -> String {
        guard ready, let power, power.isFresh(at: now) else { return ready ? "Čekám na měření" : "Pad odpojen" }
        let percent = power.percent.map { "\($0) %" } ?? "—"
        return "\(percent) · \(power.mode.rawValue)"
    }
    /// Revalidate the identity immediately before writing; slots can be repaired/reused.
    static func hostPacket(for command: DeviceWheelCommand, hosts: HostProfiles?, power: PowerStatus?,
                           ready: Bool, busy: Bool, now: Date = Date()) -> Data? {
        guard ready, !busy, let hosts, hosts.fresh, !hosts.pending, hosts.pairingSlot == nil else { return nil }
        switch command {
        case .host(let identity, let slot):
            guard (0..<hosts.capacity).contains(slot), hosts.hosts.contains(where: { $0.id == identity && $0.target == slot }) else { return nil }
            return Data([1, UInt8(slot)])
        case .usb:
            guard let power, power.isFresh(at: now), power.mode == .usb || power.mode == .charging else { return nil }
            return Data([5])
        default: return nil
        }
    }
}

struct DeviceWheelStatus: View {
    @ObservedObject var pad: LearningPad
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 5) {
                Text(pad.ready && pad.hosts?.fresh == true ? "Ovládání: \(pad.hosts!.destination)" : "Čekám na stav zařízení")
                    .lineLimit(2)
                Text(DeviceWheelMenu.batterySummary(pad.power, ready: pad.ready, now: context.date))
                    .foregroundStyle(pad.power?.mode == .charging ? Color.green : Color.secondary)
                    .lineLimit(2)
            }.font(.system(size: 10)).multilineTextAlignment(.center)
        }
    }
}

struct WheelDetailPanel<Content: View>: View {
    let close: () -> Void
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(spacing: 0) {
            content()
            Button("Zavřít", action: close).keyboardShortcut(.cancelAction).padding(14)
        }.background(Studio.background).preferredColorScheme(.dark).buttonStyle(StudioButton())
    }
}
