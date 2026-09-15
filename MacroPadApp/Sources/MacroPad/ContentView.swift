import SwiftUI
import ServiceManagement

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @ObservedObject var mic = MicController.shared
    @State private var confirmRead = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if state.target == .xiao { wirelessControls }
                    Text(state.target == .xiao
                         ? "Před zápisem stiskni současně všechny tři klávesy. Zápis se odemkne na 60 sekund. Podržení kolečka dál ovládá Bluetooth profily."
                         : "Původní CH552 konfigurátor přes USB.")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    padPreview
                    sectionTitle("Klávesy")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), alignment: .top)], alignment: .leading, spacing: 12) { ForEach(state.config.physicalKeys) { SlotCard(slot: $0, recorder: state.recorder) } }
                    sectionTitle("Otočný knob")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), alignment: .top)], alignment: .leading, spacing: 12) { ForEach(Slot.knob) { SlotCard(slot: $0, recorder: state.recorder) } }
                    micSection
                    logView
                }
                .padding(20)
                .disabled(state.busy || state.ble.reading || state.ble.connecting)
            }
        }
        .frame(minWidth: 860, minHeight: 640)
        .toolbar {
            ToolbarItemGroup {
                Picker("Zařízení", selection: Binding(get: { state.target }, set: { state.selectTarget($0) })) {
                    ForEach(AppState.Target.allCases) { Text($0.title).tag($0) }
                }.frame(width: 170).disabled(state.busy || state.ble.connecting || state.ble.reading)
                if state.target == .ch552 {
                Picker("Vrstva", selection: Binding(get: { state.config.layer }, set: { state.config.layer = $0; state.dirty = Set(Slot.all.map(\.id)) })) {
                    Text("Vrstva 1").tag(UInt8(0)); Text("Vrstva 2").tag(UInt8(1)); Text("Vrstva 3").tag(UInt8(2))
                }.frame(width: 110)
                Menu {
                    Picker("LED režim", selection: $state.ledMode) { ForEach(0..<6) { Text($0 == 0 ? "Vypnuto" : "Režim \($0)").tag(UInt8($0)) } }
                    Button("Nastavit LED") { state.setLED() }
                } label: { Label("LED", systemImage: "lightbulb") }
                }
                Menu {
                    Button("Export JSON…") { state.exportJSON() }
                    Button("Import JSON…") { state.importJSON() }
                    Divider()
                    Button("Zobrazit config.json ve Finderu") { NSWorkspace.shared.activateFileViewerSelecting([state.configURL]) }
                } label: { Label("Soubor", systemImage: "square.and.arrow.down") }
                .disabled(state.busy || state.ble.reading || state.ble.connecting)
                Button { state.writeAll() } label: { Label("Zapsat do padu", systemImage: "arrow.up.circle.fill") }
                    .disabled(!state.connected || state.busy || state.ble.reading)
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    var wirelessControls: some View {
        GroupBox("Bezdrátový MacroPad") {
            VStack(alignment: .leading, spacing: 10) {
                if state.connected {
                    HStack {
                        Button("Načíst z padu") {
                            if state.dirty.isEmpty { state.readWireless() } else { confirmRead = true }
                        }
                        Button("Odpojit") { state.ble.disconnect() }
                    }
                } else {
                    Button(state.ble.searching ? "Hledám…" : "Najít MacroPad") { state.ble.search() }
                        .disabled(state.ble.searching || state.ble.connecting)
                    ForEach(state.ble.devices, id: \.identifier) { device in
                        HStack {
                            Text(device.name ?? "MacroPad")
                            Text(String(device.identifier.uuidString.prefix(8))).font(.caption).foregroundStyle(.secondary)
                            Button("Připojit a načíst") { state.ble.connect(device) }.disabled(state.ble.connecting)
                        }
                    }
                    Text("Při prvním použití nahraj nový firmware přes USB. Potom pad spáruj s Macem v nastavení Bluetooth.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
        }
        .confirmationDialog("Nahradit rozepsané změny nastavením z padu?", isPresented: $confirmRead) {
            Button("Načíst z padu", role: .destructive) { state.readWireless() }
            Button("Zrušit", role: .cancel) {}
        }
    }

    var header: some View {
        HStack(spacing: 10) {
            Circle().fill(state.connected ? .green : .red).frame(width: 10, height: 10)
            Text(state.connectionLabel)
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
            if !state.status.isEmpty {
                Text(state.status).font(.callout).foregroundStyle(state.statusIsError ? .red : .green)
            }
            if state.busy { ProgressView().controlSize(.small) }
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
    }

    func sectionTitle(_ t: String) -> some View { Text(t).font(.headline).foregroundStyle(.secondary) }

    var knobPreview: some View {
        VStack(spacing: 3) {
            Circle().strokeBorder(.secondary, lineWidth: 3).frame(width: 54, height: 54)
                .overlay(Text(summary(14)).font(.caption2).multilineTextAlignment(.center).padding(4))
            Text("← \(summary(13))  |  \(summary(15)) →").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
    }
    func keyPreview(_ s: Slot) -> some View {
        VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 10).fill(.quaternary).frame(width: 90, height: 54)
                .overlay(Text(summary(s.id)).font(.caption).multilineTextAlignment(.center).padding(4))
            Text(s.title).font(.caption2).foregroundStyle(.secondary)
        }
    }
    var padPreview: some View {
        HStack(alignment: .top, spacing: 16) {
            if !state.config.knobOnRight { knobPreview }
            ForEach(state.config.physicalKeys) { keyPreview($0) }
            if state.config.knobOnRight { knobPreview }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("Rozložení").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $state.config.knobOnRight) { Text("Encoder vlevo").tag(false); Text("Encoder vpravo").tag(true) }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 220)
                Picker("", selection: $state.config.keysReversed) { Text("Klávesy 1‑2‑3").tag(false); Text("Klávesy 3‑2‑1").tag(true) }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 220)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(nsColor: .windowBackgroundColor)).shadow(radius: 1))
    }

    func summary(_ id: UInt8) -> String {
        let m = state.config[id]
        switch m.kind {
        case .keys: return m.chords.isEmpty ? "—" : m.chords.map(\.label).joined(separator: " ")
        case .media: return MediaKey.all.first { $0.code == m.media }?.title ?? "media"
        case .mouse: return m.mouse.title
        case .micMute: return "🎙 mute"
        }
    }

    var micSection: some View {
        GroupBox {
            HStack(spacing: 14) {
                Image(systemName: mic.muted ? "mic.slash.fill" : "mic.fill").font(.title).foregroundStyle(mic.muted ? .red : .green).frame(width: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ztišení mikrofonu").font(.headline)
                    Text("Vstup: \(mic.deviceName). Pad pošle klávesu **\(state.config.micHotkey.label)**, appka ji zachytí (musí běžet – stačí v liště) a přepne mikrofon.")
                        .font(.callout).foregroundStyle(.secondary)
                    if let e = mic.lastError { Text(e).font(.caption).foregroundStyle(.red) }
                }
                Spacer()
                Picker("Hotkey", selection: Binding(get: { state.config.micHotkey }, set: { state.config.micHotkey = $0; MicController.shared.registerHotkey($0); state.dirty.formUnion(Slot.all.filter { state.config[$0.id].kind == .micMute }.map(\.id)) })) {
                    Text("F18").tag(Chord(mods: 0, code: 0x6d))
                    Text("F19").tag(Chord(mods: 0, code: 0x6e))
                    Text("⌃⌥⌘M").tag(Chord(mods: 0x0d, code: 0x10))
                }.frame(width: 130)
                Button(mic.muted ? "Zapnout mikrofon" : "Vypnout mikrofon") { mic.toggle() }
            }
            .padding(6)
            Toggle("Spouštět MacroPad po přihlášení (běží v liště, aby mute fungoval)", isOn: Binding(
                get: { SMAppService.mainApp.status == .enabled },
                set: { on in try? (on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()) }))
                .toggleStyle(.checkbox).font(.callout).padding([.horizontal, .bottom], 6)
        }
    }

    var logView: some View {
        DisclosureGroup("Log komunikace") {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(state.log.enumerated()), id: \.offset) { Text($0.element).font(.system(.caption, design: .monospaced)).id($0.offset) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 140)
                .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .onChange(of: state.log.count) { _ in if let l = state.log.indices.last { proxy.scrollTo(l) } }
            }
        }
    }
}

struct SlotCard: View {
    let slot: Slot
    @EnvironmentObject var state: AppState
    @ObservedObject var recorder: KeyRecorder

    init(slot: Slot, recorder: KeyRecorder) { self.slot = slot; self.recorder = recorder }

    var macro: MacroDef { state.config[slot.id] }
    var isRecording: Bool { state.recorder.recording == slot.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(slot.title, systemImage: slot.symbol).font(.headline)
                Spacer()
                if state.dirty.contains(slot.id) { Text("nezapsáno").font(.caption2).foregroundStyle(.orange) }
                Button { state.write(slots: [slot.id]) } label: { Image(systemName: "arrow.up.circle") }
                    .buttonStyle(.borderless).help("Zapsat jen tuto klávesu").disabled(!state.connected || state.busy || state.ble.reading)
            }
            Picker("", selection: Binding(get: { macro.kind }, set: { k in state.update(slot.id) { $0.kind = k } })) {
                ForEach(MacroKind.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented).labelsHidden()

            switch macro.kind {
            case .keys: keysEditor
            case .media:
                Picker("", selection: Binding(get: { macro.media }, set: { v in state.update(slot.id) { $0.media = v } })) {
                    ForEach(MediaKey.all) { Text($0.title).tag($0.code) }
                }.labelsHidden()
            case .mouse:
                Picker("", selection: Binding(get: { macro.mouse }, set: { v in state.update(slot.id) { $0.mouse = v } })) {
                    ForEach(MouseAction.allCases) { Text($0.title).tag($0) }
                }.labelsHidden()
            case .micMute:
                Text("Přepne mikrofon Macu (přes tuto appku).").font(.callout).foregroundStyle(.secondary).frame(minHeight: 44)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)).shadow(color: .black.opacity(0.08), radius: 2, y: 1))
    }

    var keysEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if macro.chords.isEmpty && !isRecording { Text("žádná zkratka").foregroundStyle(.tertiary).font(.callout) }
                ForEach(Array(macro.chords.enumerated()), id: \.offset) { i, c in
                    HStack(spacing: 4) {
                        Text(c.label).font(.system(.body, design: .rounded)).fontWeight(.medium)
                        Button { state.update(slot.id) { $0.chords.remove(at: i) } } label: { Image(systemName: "xmark.circle.fill").font(.caption) }.buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 30)
            Button {
                if isRecording { state.recorder.stop() } else { state.recorder.start(slot: slot.id) }
            } label: {
                Label(isRecording ? "Nahrávám… stiskni zkratku (Esc = konec)" : "Nahrát zkratku", systemImage: isRecording ? "record.circle.fill" : "keyboard")
                    .frame(maxWidth: .infinity)
            }
            .tint(isRecording ? .red : nil)
            .buttonStyle(.bordered)
        }
    }
}
