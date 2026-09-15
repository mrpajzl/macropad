import Foundation
import CoreAudio
import Carbon
import AppKit

/// Ztišení mikrofonu: CoreAudio (mute property, jinak input volume 0) + globální hotkey.
final class MicController: ObservableObject {
    static let shared = MicController()
    @Published private(set) var muted = false
    @Published var lastError: String?
    private var savedVolume: Float32 = 0.75
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private init() { refresh() }

    // MARK: CoreAudio
    private var device: AudioDeviceID {
        var id = AudioDeviceID(0); var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        return id
    }
    var deviceName: String {
        var name: CFString = "" as CFString; var size = UInt32(MemoryLayout<CFString>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        let dev = device
        guard dev != 0 else { return "žádný vstup" }
        withUnsafeMutablePointer(to: &name) { p in _ = AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, p) }
        return name as String
    }
    private func addr(_ sel: AudioObjectPropertySelector, _ el: UInt32) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: sel, mScope: kAudioDevicePropertyScopeInput, mElement: el)
    }
    private func settable(_ sel: AudioObjectPropertySelector, _ el: UInt32) -> Bool {
        var a = addr(sel, el); var s: DarwinBoolean = false
        return AudioObjectHasProperty(device, &a) && AudioObjectIsPropertySettable(device, &a, &s) == noErr && s.boolValue
    }
    private var muteSupported: Bool { settable(kAudioDevicePropertyMute, kAudioObjectPropertyElementMain) }
    private var volumeElements: [UInt32] { [kAudioObjectPropertyElementMain, 1, 2].filter { settable(kAudioDevicePropertyVolumeScalar, $0) } }

    private func getVolume() -> Float32 {
        guard let el = volumeElements.first else { return 0 }
        var v: Float32 = 0; var size = UInt32(MemoryLayout<Float32>.size); var a = addr(kAudioDevicePropertyVolumeScalar, el)
        AudioObjectGetPropertyData(device, &a, 0, nil, &size, &v); return v
    }
    private func setVolume(_ v: Float32) {
        var v = v
        for el in volumeElements { var a = addr(kAudioDevicePropertyVolumeScalar, el); AudioObjectSetPropertyData(device, &a, 0, nil, UInt32(MemoryLayout<Float32>.size), &v) }
    }
    private func getMute() -> Bool {
        var m: UInt32 = 0; var size = UInt32(MemoryLayout<UInt32>.size); var a = addr(kAudioDevicePropertyMute, kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(device, &a, 0, nil, &size, &m); return m != 0
    }
    private func setMute(_ on: Bool) {
        var m: UInt32 = on ? 1 : 0; var a = addr(kAudioDevicePropertyMute, kAudioObjectPropertyElementMain)
        AudioObjectSetPropertyData(device, &a, 0, nil, UInt32(MemoryLayout<UInt32>.size), &m)
    }

    /// Načte aktuální stav ze systému.
    func refresh() {
        guard device != 0 else { muted = false; return }
        muted = muteSupported ? getMute() : getVolume() < 0.01
    }
    func toggle() { set(muted: !muted) }
    func set(muted on: Bool) {
        NSLog("MacroPad: set muted=\(on) muteSupported=\(muteSupported)")
        guard device != 0 else { lastError = "Není žádné vstupní zařízení"; return }
        if muteSupported {
            setMute(on)
        } else {
            if on { let v = getVolume(); if v > 0.01 { savedVolume = v }; setVolume(0) }
            else { setVolume(savedVolume > 0.01 ? savedVolume : 0.75) }
        }
        refresh()
        HUD.shared.show(muted: muted)
    }

    // MARK: Globální hotkey (Carbon) – nevyžaduje oprávnění Přístupnost
    func registerHotkey(_ chord: Chord) {
        unregisterHotkey()
        guard let keyCode = HID.keyMap.first(where: { $0.value.0 == chord.code })?.key else { lastError = "Hotkey nelze zaregistrovat (neznámá klávesa)"; return }
        var mods: UInt32 = 0
        if chord.mods & 0x11 != 0 { mods |= UInt32(controlKey) }
        if chord.mods & 0x22 != 0 { mods |= UInt32(shiftKey) }
        if chord.mods & 0x44 != 0 { mods |= UInt32(optionKey) }
        if chord.mods & 0x88 != 0 { mods |= UInt32(cmdKey) }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        if handlerRef == nil {
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                NSLog("MacroPad: hotkey pressed")
                DispatchQueue.main.async { MicController.shared.toggle() }
                return noErr
            }, 1, &spec, nil, &handlerRef)
        }
        let id = EventHotKeyID(signature: 0x4d50_4144, id: 1)
        let st = RegisterEventHotKey(UInt32(keyCode), mods, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        lastError = st == noErr ? nil : "RegisterEventHotKey: \(st)"
        NSLog("MacroPad: registerHotkey keyCode=\(keyCode) mods=\(mods) status=\(st)")
    }
    func unregisterHotkey() { if let r = hotKeyRef { UnregisterEventHotKey(r); hotKeyRef = nil } }
}

// MARK: - HUD overlay (jako systémová hlasitost)
final class HUD {
    static let shared = HUD()
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    func show(muted: Bool) {
        let size = NSSize(width: 200, height: 200)
        if panel == nil {
            let p = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.level = .statusBar; p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = false
            p.ignoresMouseEvents = true; p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            panel = p
        }
        guard let p = panel, let screen = NSScreen.main else { return }
        p.contentView = NSHostingView(rootView: HUDView(muted: muted))
        let f = screen.visibleFrame
        p.setFrameOrigin(NSPoint(x: f.midX - size.width / 2, y: f.minY + 140))
        p.alphaValue = 1; p.orderFrontRegardless()
        hideWork?.cancel()
        let w = DispatchWorkItem { [weak self] in
            NSAnimationContext.runAnimationGroup({ ctx in ctx.duration = 0.4; self?.panel?.animator().alphaValue = 0 }, completionHandler: { self?.panel?.orderOut(nil) })
        }
        hideWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: w)
    }
}

import SwiftUI
struct HUDView: View {
    let muted: Bool
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: muted ? "mic.slash.fill" : "mic.fill")
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(muted ? Color.red : Color.primary)
            Text(muted ? "Mikrofon vypnut" : "Mikrofon zapnut").font(.headline)
        }
        .frame(width: 200, height: 200)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
