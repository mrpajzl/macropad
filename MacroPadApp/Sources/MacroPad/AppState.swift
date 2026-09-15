import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    enum Target: String, CaseIterable, Identifiable {
        case xiao, ch552
        var id: String { rawValue }
        var title: String { self == .xiao ? "XIAO · Bluetooth" : "CH552 · USB" }
    }
    @Published var target: Target = .xiao
    @Published var config = PadConfig.load(from: PadConfig.xiaoFileURL) {
        didSet { config.save(to: configURL) }
    }
    var configURL: URL { target == .xiao ? PadConfig.xiaoFileURL : PadConfig.fileURL }
    let ble = BLEPad()
    private var bleSubscription: AnyCancellable?
    private var usbConnected = false
    var connectionLabel: String {
        target == .xiao ? ble.message : (connected ? "CH552 připojen přes USB" : "CH552 nepřipojen")
    }
    func selectTarget(_ next: Target) {
        guard !busy, next != target else { return }
        ble.disconnect()
        target = next
        config = PadConfig.load(from: configURL)
        dirty = []; status = ""
        connected = next == .ch552 && usbConnected
        MicController.shared.registerHotkey(config.micHotkey)
    }
    func readWireless() {
        guard !busy else { return }
        recorder.stop()
        ble.read()
    }
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
            guard let self, !self.busy, !self.ble.reading, !self.ble.connecting else { return }
            var m = self.config[slot]
            if m.chords.count >= 5 { self.setStatus("Max. 5 stisků na klávesu", error: true); return }
            m.chords.append(chord); self.config[slot] = m; self.dirty.insert(slot)
        }
        usbConnected = USBPad.isConnected()
        bleSubscription = ble.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.connected = self.target == .xiao ? self.ble.ready : self.usbConnected
                self.objectWillChange.send()
            }
        }
        ble.onRead = { [weak self] macros in
            guard let self, self.target == .xiao else { return }
            self.config.slots = macros
            self.config.layer = 0
            if let chord = BLEProtocol.slotIDs.compactMap({ macros[$0] }).first(where: { $0.kind == .micMute })?.chords.first {
                self.config.micHotkey = chord
                MicController.shared.registerHotkey(chord)
            }
            self.dirty = []
            self.appendLog("Nastavení načteno z XIAO.")
        }
        timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self else { return }
            let c = USBPad.isConnected()
            self.usbConnected = c
            if self.target == .ch552 && c != self.connected {
                self.connected = c; self.appendLog(c ? "CH552 připojen" : "CH552 odpojen")
            }
        }
        MicController.shared.registerHotkey(config.micHotkey)
    }

    func setStatus(_ s: String, error: Bool = false) { status = s; statusIsError = error }
    func appendLog(_ s: String) { log.append(s); if log.count > 200 { log.removeFirst() } }

    func update(_ slot: UInt8, _ f: (inout MacroDef) -> Void) {
        var m = config[slot]; f(&m); config[slot] = m; dirty.insert(slot)
    }

    func write(slots: [UInt8]) {
        guard !busy, connected else { return }
        if target == .xiao {
            recorder.stop()
            let snapshot = config
            do {
                let records = try slots.map { try BLEProtocol.encode(snapshot, slot: $0) }
                busy = true
                ble.write(records) { [weak self] result in
                    guard let self else { return }
                    self.busy = false
                    switch result {
                    case .success:
                        for slot in slots where self.config[slot] == snapshot[slot] && self.config.micHotkey == snapshot.micHotkey {
                            self.dirty.remove(slot)
                        }
                        self.setStatus("Uloženo a ověřeno přes Bluetooth ✔")
                        self.appendLog("XIAO: zápis a zpětné čtení \(slots.count) položek OK.")
                    case .failure(let error):
                        self.setStatus(error.localizedDescription, error: true)
                        self.appendLog("!! \(error.localizedDescription)")
                    }
                }
            } catch { setStatus(error.localizedDescription, error: true) }
            return
        }
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
        guard target == .ch552, connected, !busy else { return }
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
        if p.runModal() == .OK, let url = p.url { try? FileManager.default.removeItem(at: url); try? FileManager.default.copyItem(at: configURL, to: url) }
    }
    func importJSON() {
        let p = NSOpenPanel(); p.allowedContentTypes = [.json]; p.allowsMultipleSelection = false
        if p.runModal() == .OK, let url = p.url, let d = try? Data(contentsOf: url), let c = try? JSONDecoder().decode(PadConfig.self, from: d) {
            config = c; dirty = Set(Slot.all.map(\.id)); MicController.shared.registerHotkey(c.micHotkey)
        }
    }
}
