import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var config = PadConfig.load() { didSet { config.save() } }
    @Published var connected = false
    @Published var dirty: Set<UInt8> = []
    @Published var busy = false
    @Published var status = ""
    @Published var statusIsError = false
    @Published var log: [String] = []
    @Published var ledMode: UInt8 = 1
    let recorder = KeyRecorder()
    private var timer: AnyCancellable?

    init() {
        recorder.onChord = { [weak self] slot, chord in
            guard let self else { return }
            var m = self.config[slot]
            if m.chords.count >= 5 { self.setStatus("Max. 5 stisků na klávesu", error: true); return }
            m.chords.append(chord); self.config[slot] = m; self.dirty.insert(slot)
        }
        connected = USBPad.isConnected()
        timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self else { return }
            let c = USBPad.isConnected()
            if c != self.connected { self.connected = c; self.appendLog(c ? "Pad připojen" : "Pad odpojen") }
        }
        MicController.shared.registerHotkey(config.micHotkey)
    }

    func setStatus(_ s: String, error: Bool = false) { status = s; statusIsError = error }
    func appendLog(_ s: String) { log.append(s); if log.count > 200 { log.removeFirst() } }

    func update(_ slot: UInt8, _ f: (inout MacroDef) -> Void) {
        var m = config[slot]; f(&m); config[slot] = m; dirty.insert(slot)
    }

    func write(slots: [UInt8]) {
        guard !busy else { return }
        busy = true
        let cfg = config
        let packets = slots.flatMap { PadProtocol.packets(config: cfg, slot: $0) }
        Task.detached {
            let result: Result<Void, Error> = Result { try USBPad.write(packets) }
            await MainActor.run {
                packets.forEach { self.appendLog("→ " + PadProtocol.hex($0)) }
                switch result {
                case .success:
                    slots.forEach { self.dirty.remove($0) }
                    self.setStatus(slots.count == 1 ? "Zapsáno: \(Slot.all.first { $0.id == slots[0] }?.title ?? "")" : "Vše zapsáno ✔")
                case .failure(let e):
                    self.setStatus("Chyba: \(e.localizedDescription)", error: true); self.appendLog("!! \(e.localizedDescription)")
                }
                self.busy = false
            }
        }
    }
    func writeAll() { write(slots: Slot.all.map(\.id)) }

    func setLED() {
        let p = PadProtocol.ledPackets(mode: ledMode)
        Task.detached {
            let r: Result<Void, Error> = Result { try USBPad.write(p) }
            await MainActor.run {
                if case .failure(let e) = r { self.setStatus("Chyba LED: \(e.localizedDescription)", error: true) } else { self.setStatus("LED nastaveno") }
            }
        }
    }

    func exportJSON() {
        let p = NSSavePanel(); p.nameFieldStringValue = "macropad.json"; p.allowedContentTypes = [.json]
        if p.runModal() == .OK, let url = p.url { try? FileManager.default.removeItem(at: url); try? FileManager.default.copyItem(at: PadConfig.fileURL, to: url) }
    }
    func importJSON() {
        let p = NSOpenPanel(); p.allowedContentTypes = [.json]; p.allowsMultipleSelection = false
        if p.runModal() == .OK, let url = p.url, let d = try? Data(contentsOf: url), let c = try? JSONDecoder().decode(PadConfig.self, from: d) {
            config = c; dirty = Set(Slot.all.map(\.id)); MicController.shared.registerHotkey(c.micHotkey)
        }
    }
}
