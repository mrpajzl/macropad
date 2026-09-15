import AppKit

/// Nahrává stisky kláves (globálně v okně appky) a převádí je na HID chordy.
final class KeyRecorder: ObservableObject {
    @Published var recording: UInt8? = nil       // ID slotu, do kterého nahráváme
    private var monitor: Any?
    var onChord: ((UInt8, Chord) -> Void)?

    func start(slot: UInt8) {
        stop()
        recording = slot
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] ev in
            guard let self, let slot = self.recording else { return ev }
            if ev.keyCode == 53 && ev.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty { self.stop(); return nil } // Esc = konec
            guard let (usage, _) = HID.keyMap[ev.keyCode] else { NSSound.beep(); return nil }
            let f = ev.modifierFlags
            var mods: UInt8 = 0
            if f.contains(.control) { mods |= 0x01 }
            if f.contains(.shift)   { mods |= 0x02 }
            if f.contains(.option)  { mods |= 0x04 }
            if f.contains(.command) { mods |= 0x08 }
            self.onChord?(slot, Chord(mods: mods, code: usage))
            return nil
        }
    }
    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        recording = nil
    }
}
