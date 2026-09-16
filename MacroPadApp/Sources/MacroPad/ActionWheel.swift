import SwiftUI
import Carbon
import ApplicationServices

// Values are stored in the device's control record, byte 6.
enum HoldMode: UInt8, Codable, CaseIterable, Identifiable {
    case disabled = 0, actions = 1, applications = 2, device = 3
    var id: UInt8 { rawValue }
    var title: String {
        switch self {
        case .disabled: return "Vypnuto"
        case .actions: return "Kruhové menu"
        case .applications: return "Přepínání aplikací"
        case .device: return "Zařízení a baterie"
        }
    }
}
enum WheelCapabilities {
    static func supports(mode: HoldMode, kind: ControlKind, version: UInt8) -> Bool {
        mode == .disabled || (version >= 2) || (version == 1 && kind == .button && mode != .device)
    }
}

struct WheelAction: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable { case application, keyboard, shortcut }
    var id = UUID()
    var title = "Nová akce"
    var kind: Kind = .application
    var applicationPath = ""
    var shortcutName = ""
    var chords: [Chord] = []
    var symbol: String { kind == .application ? "app.fill" : kind == .keyboard ? "command" : "bolt.fill" }
}
struct WheelSelection {
    var count = 0
    var index = 0
    mutating func rotate(_ delta: Int) {
        guard count > 0 else { index = 0; return }
        index = ((index + delta) % count + count) % count
    }
}
final class WheelSettings: ObservableObject {
    static let shared = WheelSettings()
    @Published private var menus: [String: [String: [WheelAction]]] = [:]
    @Published var error = ""
    private let url = PadConfig.fileURL.deletingLastPathComponent().appendingPathComponent("action-wheels.json")
    private init() {
        if let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode([String: [String: [WheelAction]]].self, from: data) { menus = value }
    }
    func actions(device: String, control: Int) -> [WheelAction] { menus[device]?[String(control)] ?? [] }
    func set(_ actions: [WheelAction], device: String, control: Int) {
        menus[device, default: [:]][String(control)] = actions
        do { try JSONEncoder().encode(menus).write(to: url, options: .atomic); error = "" }
        catch { self.error = "Menu se nepodařilo uložit: \(error.localizedDescription)" }
    }
}

/// Dedicated HID commands arrive only at the selected USB/Bluetooth host.
/// Carbon hotkeys consume them without requiring global keyboard monitoring.
final class ActionWheel: ObservableObject {
    static let shared = ActionWheel()
    struct Item: Identifiable {
        let id = UUID()
        let title: String
        let symbol: String
        var icon: NSImage?
        var subtitle = ""
        var enabled = true
        let perform: () -> Void
    }
    @Published private(set) var items: [Item] = []
    @Published private(set) var selection = WheelSelection()
    @Published private(set) var title = ""
    @Published var error = ""
    private var device = ""
    private(set) weak var pad: LearningPad?
    var openSettings: (() -> Void)?
    @Published private(set) var showingDeviceMenu = false
    private var detailPanel: NSPanel?
    private var controls: [HardwareControl] = []
    private var active: Int?
    private var isPreview = false
    private var panel: NSPanel?
    private var refs: [EventHotKeyRef] = []
    private var escapeRef: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var timeout: DispatchWorkItem?
    private var recent: [pid_t] = []
    private var activationObserver: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?
    private var started = false

    func start() {
        guard !started else { return }; started = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var key = EventHotKeyID()
            guard let event, GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &key) == noErr,
                  key.signature == 0x4d50_5748 else { return OSStatus(eventNotHandledErr) }
            DispatchQueue.main.async { ActionWheel.shared.receive(Int(key.id)) }
            return noErr
        }, 1, &spec, nil, &handler)
        guard result == noErr else { error = "Nelze zapnout ovládání menu (\(result))."; return }
        let mods = UInt32(controlKey | optionKey | cmdKey)
        for id in 0..<11 {
            register(usage: UInt8(58 + id), mods: mods, id: id)
            register(usage: UInt8(58 + id), mods: mods | UInt32(shiftKey), id: 20 + id)
        }
        register(usage: 69, mods: mods, id: 40) // F12, previous
        register(usage: 104, mods: mods, id: 41) // F13, next
        register(usage: 105, mods: mods, id: 42) // F14, cancel
        let center = NSWorkspace.shared.notificationCenter
        activationObserver = center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self.recent.removeAll { $0 == app.processIdentifier }
            self.recent.insert(app.processIdentifier, at: 0)
            self.recent = Array(self.recent.prefix(100))
        }
        sleepObserver = center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.cancel() }
    }
    private func register(usage: UInt8, mods: UInt32, id: Int) {
        guard let code = HID.keyMap.first(where: { $0.value.0 == usage })?.key else { return }
        var ref: EventHotKeyRef?
        let result = RegisterEventHotKey(UInt32(code), mods, EventHotKeyID(signature: 0x4d50_5748, id: UInt32(id)), GetApplicationEventTarget(), 0, &ref)
        if result == noErr, let ref { refs.append(ref) }
        else { error = "Ovládání menu koliduje s jinou zkratkou (\(result))." }
    }
    func configure(device: String, controls: [HardwareControl], pad: LearningPad? = nil) {
        cancel(); self.device = device; self.controls = controls; self.pad = pad
    }
    func receive(_ command: Int) {
        if isPreview { if command == 42 || command == 99 { cancel() }; return }
        if command < 11 {
            guard active == nil, let control = controls.first(where: { $0.id == command }), control.holdMode != .disabled else { return }
            show(mode: control.holdMode, control: command)
        } else if (20..<31).contains(command) {
            guard active == command - 20 else { return }
            let action = items.indices.contains(selection.index) ? items[selection.index].perform : nil
            let enabled = items.indices.contains(selection.index) && items[selection.index].enabled
            cancel()
            if enabled { action?() }
        } else if command == 42 || command == 99 { cancel() }
        else if active != nil, command == 40 || command == 41 {
            selection.rotate(command == 40 ? -1 : 1)
        }
    }
    func show(mode: HoldMode, control: Int, preview: Bool = false, device previewDevice: String? = nil) {
        cancel(); active = control; isPreview = preview; showingDeviceMenu = mode == .device
        if mode == .device {
            title = "Zařízení a baterie"
            pad?.refreshHosts(); pad?.refreshPower()
            items = DeviceWheelMenu.entries(hosts: pad?.hosts, power: pad?.power, ready: pad?.ready == true,
                busy: deviceBusy, muted: MicController.shared.muted).map { entry in
                Item(title: entry.title, symbol: entry.symbol, subtitle: entry.subtitle, enabled: entry.enabled) { [weak self] in self?.executeDevice(entry.command) }
            }
            selection = WheelSelection(count: items.count)
        } else if mode == .applications {
            title = "Přepnout aplikaci"
            let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
            let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && !$0.isTerminated }
                .sorted {
                    let a = recent.firstIndex(of: $0.processIdentifier) ?? 100
                    let b = recent.firstIndex(of: $1.processIdentifier) ?? 100
                    return a == b ? ($0.localizedName ?? "") < ($1.localizedName ?? "") : a < b
                }
            items = apps.map { app in Item(title: app.localizedName ?? "Aplikace", symbol: "app.fill", icon: app.icon) { [weak self] in
                if !app.activate(options: [.activateIgnoringOtherApps]) { self?.error = "Aplikaci už nelze aktivovat." }
            } }
            selection = WheelSelection(count: items.count, index: apps.firstIndex(where: { $0.processIdentifier != front }) ?? 0)
        } else {
            title = "Kruhové menu"
            items = WheelSettings.shared.actions(device: previewDevice ?? device, control: control).map { action in
                Item(title: action.title, symbol: action.symbol,
                     icon: action.kind == .application && !action.applicationPath.isEmpty ? NSWorkspace.shared.icon(forFile: action.applicationPath) : nil) { [weak self] in self?.execute(action) }
            }
            selection = WheelSelection(count: items.count)
        }
        if panel == nil {
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 580, height: 580), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.level = .statusBar; p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = false
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]; panel = p
        }
        panel?.contentView = NSHostingView(rootView: ActionWheelOverlay(wheel: self, preview: preview))
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame { panel?.setFrameOrigin(NSPoint(x: frame.midX - 290, y: frame.midY - 290)) }
        panel?.orderFrontRegardless()
        RegisterEventHotKey(53, 0, EventHotKeyID(signature: 0x4d50_5748, id: 99), GetApplicationEventTarget(), 0, &escapeRef)
        let work = DispatchWorkItem { [weak self] in self?.cancel() }
        timeout = work; DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: work)
    }
    func cancel() {
        active = nil; isPreview = false; panel?.orderOut(nil); timeout?.cancel(); timeout = nil
        if let escapeRef { UnregisterEventHotKey(escapeRef) }; escapeRef = nil
    }
    private var deviceBusy: Bool { pad == nil || pad!.busy || pad!.hostBusy || pad!.learning }
    private func executeDevice(_ command: DeviceWheelCommand) {
        switch command {
        case .dismiss: break
        case .microphone: MicController.shared.toggle()
        case .settings: openSettings?()
        case .battery:
            guard let pad else { error = "Připojte MacroPad v konfigurátoru."; return }
            pad.refreshPower()
            showDetail(title: "Baterie MacroPadu") { PowerDetails(pad: pad) }
        case .hosts:
            guard let pad else { return }
            showDetail(title: "Zařízení") { [weak self] in HostManagerView(pad: pad, onClose: { self?.detailPanel?.close() }) }
        case .host, .usb:
            guard let pad, let packet = DeviceWheelMenu.hostPacket(for: command, hosts: pad.hosts, power: pad.power,
                ready: pad.ready, busy: deviceBusy) else {
                error = "Stav zařízení se změnil nebo není aktuální. Otevřete nabídku znovu."; pad?.refreshHosts(); return
            }
            pad.manageHost(packet)
        }
    }
    private func showDetail<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) {
        detailPanel?.close()
        let panel = NSPanel(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = title; panel.isReleasedWhenClosed = false; panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: WheelDetailPanel(close: { [weak panel] in panel?.close() }, content: content))
        panel.center(); panel.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        detailPanel = panel
    }
    func previewRotate(_ delta: Int) { selection.rotate(delta) }
    static func isReserved(_ chord: Chord) -> Bool {
        let mods = (chord.mods & 0x0f) | (chord.mods >> 4)
        return ((58...68).contains(chord.code) && (mods == 0x0d || mods == 0x0f)) ||
            ([UInt8(69), 104, 105].contains(chord.code) && mods == 0x0d)
    }
    private func execute(_ action: WheelAction) {
        switch action.kind {
        case .application:
            guard !action.applicationPath.isEmpty else { error = "Nejdřív vyberte aplikaci v nastavení menu."; return }
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: action.applicationPath), configuration: .init()) { [weak self] _, failure in
                if let failure { DispatchQueue.main.async { self?.error = failure.localizedDescription } }
            }
        case .shortcut:
            guard !action.shortcutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { error = "Vyplňte název zkratky z aplikace Zkratky."; return }
            let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", action.shortcutName]
            process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
            process.terminationHandler = { [weak self] process in
                if process.terminationStatus != 0 { DispatchQueue.main.async { self?.error = "Zkratku se nepodařilo spustit. Ověřte její název a oprávnění v aplikaci Zkratky." } }
            }
            do { try process.run() } catch { self.error = error.localizedDescription }
        case .keyboard:
            guard !action.chords.isEmpty else { error = "Nejdřív nahrajte klávesovou zkratku."; return }
            guard !action.chords.contains(where: Self.isReserved) else {
                error = "Tato kombinace je rezervovaná pro ovládání menu. Nahrajte jinou zkratku."; return
            }
            guard AXIsProcessTrusted() else {
                error = "Pro odesílání zkratek povolte MacroPad v Nastavení systému → Soukromí a zabezpečení → Zpřístupnění."
                _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
                return
            }
            // Firmware's command chord must have been released before posting the action.
            for (index, chord) in action.chords.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08 + Double(index) * 0.08) {
                    guard let code = HID.keyMap.first(where: { $0.value.0 == chord.code })?.key else { return }
                    var flags: CGEventFlags = []
                    if chord.mods & 0x11 != 0 { flags.insert(.maskControl) }
                    if chord.mods & 0x22 != 0 { flags.insert(.maskShift) }
                    if chord.mods & 0x44 != 0 { flags.insert(.maskAlternate) }
                    if chord.mods & 0x88 != 0 { flags.insert(.maskCommand) }
                    for down in [true, false] {
                        let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)
                        event?.flags = flags; event?.post(tap: .cghidEventTap)
                    }
                }
            }
        }
    }
}

struct ActionWheelOverlay: View {
    @ObservedObject var wheel: ActionWheel
    var preview = false
    var body: some View {
        ZStack {
            Circle().fill(.ultraThinMaterial).overlay(Circle().stroke(.white.opacity(0.12))).padding(18)
            Circle().stroke(Studio.accent.opacity(0.12), lineWidth: 104).frame(width: 370, height: 370)
            ForEach(visibleIndices, id: \.self) { index in
                wheelItem(index)
            }
            VStack(spacing: 10) {
                Image(systemName: "dial.high.fill").font(.system(size: 26)).foregroundStyle(Studio.accent)
                Text(wheel.items.count > 8 ? "\(wheel.title) · \(wheel.selection.index + 1)/\(wheel.items.count)" : wheel.title).font(.system(size: 12)).foregroundStyle(.secondary)
                Text(wheel.items.isEmpty ? "Přidejte akce\nv nastavení menu" : wheel.items[wheel.selection.index].title)
                    .font(.system(size: 19, weight: .semibold)).multilineTextAlignment(.center).lineLimit(3)
                if wheel.showingDeviceMenu, let pad = wheel.pad { DeviceWheelStatus(pad: pad) }
                Text(preview ? "Náhled · akce se nespouští" : "Otočením vyberte\nPuštěním potvrďte · Esc zruší")
                    .font(.system(size: 10)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                if preview {
                    HStack {
                        Button("←") { wheel.previewRotate(-1) }
                        Button("→") { wheel.previewRotate(1) }
                    }
                }
                Button("Zavřít") { wheel.cancel() }.font(.caption)
            }.frame(width: 185)
        }.frame(width: 580, height: 580).preferredColorScheme(.dark)
    }
    private var visibleIndices: [Int] {
        let start = wheel.selection.index / 8 * 8
        return Array(start..<min(start + 8, wheel.items.count))
    }
    private func wheelItem(_ index: Int) -> some View {
        let item = wheel.items[index]
        let angle = Double(index % 8) / Double(max(1, visibleIndices.count)) * 2 * Double.pi - Double.pi / 2
        let selected = wheel.selection.index == index
        return VStack(spacing: 6) {
            if let icon = item.icon { Image(nsImage: icon).resizable().frame(width: 34, height: 34) }
            else { Image(systemName: item.symbol).font(.system(size: 27)).frame(height: 34) }
            Text(item.title).font(.system(size: 11, weight: .medium)).lineLimit(2).multilineTextAlignment(.center)
            if !item.subtitle.isEmpty { Text(item.subtitle).font(.system(size: 8)).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.center) }
        }.frame(width: 100, height: item.subtitle.isEmpty ? 76 : 92)
            .opacity(item.enabled ? 1 : 0.4)
            .background(selected ? Studio.accent.opacity(0.3) : Color.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Studio.accent : Color.clear, lineWidth: 2))
            .scaleEffect(selected ? 1.08 : 1)
            .offset(x: cos(angle) * 190, y: sin(angle) * 190)
    }

}
