import SwiftUI
import UniformTypeIdentifiers

struct HardwareWorkspace: View {
    @ObservedObject var pad: LearningPad
    @State private var draft = HardwareProject()
    @State private var activity = HardwareActivity()
    @State private var dirty = false
    @State private var page = 0
    @State private var selected: Int?
    @State private var kind: ControlKind?
    @State private var captureStep = 0
    @State private var pushPin = 0
    @State private var clockwise: (Int, Int, Int)?
    @State private var learner = PinLearner()
    @State private var latest: UInt16?
    @State private var lost = false
    @State private var detail = ""
    @State private var flashing = false
    @State private var bootVolumes: [URL] = []
    @State private var chosenVolume: URL?
    @State private var showInstall = false
    @State private var showDiscard = false
    @State private var saving = false
    @State private var lastSampleAt: Date?
    @State private var removeID: Int?
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Váš vlastní MacroPad").font(.title2.bold())
                    Text(pad.message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                }
                Spacer()
                if pad.ready { Label("Rozpoznán", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
            }
            HStack {
                step("1  Firmware a připojení", number: 0)
                step("2  Poznat ovladače", number: 1)
                step("3  Rozložení a akce", number: 2)
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if page == 0 { installation }
                    else if page == 1 { discovery }
                    else { layout }
                    if !detail.isEmpty { Text(detail).foregroundStyle(.secondary).textSelection(.enabled) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(2)
            }
            Divider()
            HStack {
                if pad.learning || dirty {
                    Button("Zrušit úpravy", role: .destructive) { showDiscard = true }
                    Text(pad.learning ? "Učení: makra jsou dočasně vypnutá" : "Neuložené změny").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if page == 1 {
                    Button("Rozmístit v gridu →") { kind = nil; page = 2 }.disabled(draft.controls.isEmpty)
                }
                if page == 2 {
                    Button(pad.busy ? "Nahrávám…" : "Dokončit a nahrát do MacroPadu") {
                        saving = true; kind = nil; pad.save(draft)
                    }.buttonStyle(.borderedProminent)
                        .disabled(!pad.ready || pad.busy || draft.controls.isEmpty)
                    if !pad.ready { Text("Pro uložení připojte MacroPad.").font(.caption).foregroundStyle(.secondary) }
                    else if draft.controls.isEmpty { Text("Nejdřív přidejte alespoň jeden ovladač.").font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
        .padding(22).frame(minWidth: 820, minHeight: 620)
        .disabled(flashing)
        .onAppear {
            pad.onSample = { mask, gap in
                latest = mask
                activity.update(mask, controls: draft.controls, gap: gap, at: Date().timeIntervalSinceReferenceDate)
                lastSampleAt = Date()
                guard kind != nil else { return }
                if gap { lost = true; detail = "Přenos ztratil vzorek. Klikněte na Zkusit znovu a pohyb zopakujte pomaleji." }
                if !lost, learner.samples.count < 8192 { learner.append(mask) }
                else if learner.samples.count >= 8192 { lost = true; detail = "Pokus trval příliš dlouho. Zkuste ho znovu." }
            }
            pad.onLoaded = { project in
                if project.controls.contains(where: { $0.actions.contains(where: { $0.kind == .micMute }) }) {
                    MicController.shared.registerHotkey(Chord(mods: 0, code: 0x6d))
                }
                if saving || !dirty {
                    draft = project; dirty = false; saving = false
                    page = project.controls.isEmpty ? 1 : 2
                    selected = project.controls.first?.id
                } else { detail = "Rozpracované změny zůstaly v aplikaci. Zařízení je znovu připojené; pro pokračování zapněte úpravy." }
            }
            pad.start()
        }
        .onDisappear { pad.disconnect() }
        .onChange(of: pad.ready) { ready in
            if !ready { activity = HardwareActivity(); kind = nil; latest = nil; lastSampleAt = nil; saving = false }
        }
        .onReceive(timer) { _ in
            if kind != nil, let lastSampleAt, Date().timeIntervalSince(lastSampleAt) > 2 {
                lost = true; detail = "Měření bylo přerušeno. Po obnovení spojení pokus zopakujte."
            }
            if page == 0 {
                bootVolumes = FirmwareInstaller.volumes()
                if chosenVolume == nil || !bootVolumes.contains(chosenVolume!) { chosenVolume = bootVolumes.first }
            }
        }
        .alert("Nahrát univerzální firmware?", isPresented: $showInstall) {
            Button("Nahrát firmware") { install() }
            Button("Zrušit", role: .cancel) {}
        } message: {
            Text("Nahradí firmware na vybraném XIAO. Párování zůstane zachované. Původní pevné rozložení bude nahrazeno průvodcem pro naučení zapojení.")
        }
        .alert("Zahodit rozpracované změny?", isPresented: $showDiscard) {
            Button("Zahodit", role: .destructive) { draft = pad.project; dirty = false; kind = nil; pad.cancelLearning() }
            Button("Pokračovat v úpravách", role: .cancel) {}
        } message: { Text("Konfigurace uložená v MacroPadu se nezmění.") }
        .alert("Odstranit ovladač i jeho akce?", isPresented: Binding(get: { removeID != nil }, set: { if !$0 { removeID = nil } })) {
            Button("Odstranit", role: .destructive) {
                draft.controls.removeAll { $0.id == removeID }; selected = draft.controls.first?.id; removeID = nil; dirty = true
            }
            Button("Zrušit", role: .cancel) { removeID = nil }
        }
    }
    private func step(_ title: String, number: Int) -> some View {
        Button(title) { page = number }.buttonStyle(.bordered)
            .tint(page == number ? .accentColor : .gray)
            .disabled(number > 0 && !pad.ready || pad.busy || kind != nil)
    }
    private var installation: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Začněte deskou XIAO nRF52840").font(.headline)
            Text("Zapojte tlačítka a encoder přímo mezi D0–D10 a společnou GND. Encoder potřebuje dva piny pro otáčení a jeden pro stisk. Matice kláves a expandéry zatím podporované nejsou.")
            GroupBox("První nahrání firmwaru") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Připojte XIAO datovým USB kabelem.\n2. Dvakrát rychle stiskněte malé tlačítko RESET na desce.\n3. Jakmile se objeví disk XIAO, nahrajte přibalený firmware.")
                    if !bootVolumes.isEmpty {
                        Picker("Deska", selection: $chosenVolume) {
                            ForEach(bootVolumes, id: \.self) { Text($0.lastPathComponent).tag(Optional($0)) }
                        }
                    } else { Text("Čekám na disk XIAO…").foregroundStyle(.secondary) }
                    Button("Nahrát základní firmware") { showInstall = true }.disabled(chosenVolume == nil || flashing)
                    Text("Firmware je univerzální. Na konci průvodce do něj jedním kliknutím nahrajete zapojení, grid a akce; další kompilace není potřeba.").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }
            GroupBox("Připojit a automaticky načíst zařízení") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pokud už je firmware nahraný, tento krok stačí. Při prvním připojení spárujte MacroPad v nastavení Bluetooth macOS. Konfigurace se načte přímo z něj i na novém počítači.")
                    Button("Hledat MacroPad") { pad.start() }.disabled(pad.busy)
                    ForEach(pad.devices, id: \.identifier) { device in
                        HStack {
                            Text(device.name ?? "MacroPad")
                            Text(String(device.identifier.uuidString.prefix(8))).font(.caption.monospaced()).foregroundStyle(.secondary)
                            Spacer()
                            Button("Připojit a načíst") { pad.connect(device) }.disabled(pad.busy || dirty)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }
        }
    }
    private var discovery: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Přidejte ovladače jeden po druhém").font(.headline)
            if !pad.learning {
                Button("Zapnout poznávání zapojení") { pad.beginLearning() }.buttonStyle(.borderedProminent).disabled(!pad.ready || pad.busy)
            } else if !pad.receivingSamples {
                ProgressView("Čekám na data ze snímače…")
            } else if kind == nil {
                HStack {
                    Button { begin(.button) } label: { Label("Přidat tlačítko", systemImage: "square") }
                    Button { begin(.encoder) } label: { Label("Přidat encoder", systemImage: "dial.low") }
                }.disabled(pad.busy || draft.controls.flatMap(\.pins).count >= 11)
                Text("Při učení používejte jen právě přidávaný ovladač. Před každým krokem ho pusťte.").foregroundStyle(.secondary)
            }
            if let kind {
                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(captureStep == 0 ? "Stiskněte a pusťte \(kind == .button ? "tlačítko" : "kolečko")." : captureStep == 1 ? "Otočte kolečkem alespoň dva kroky doprava." : "Teď otočte alespoň dva kroky doleva.").font(.title3.bold())
                        Text("Zachyceno změn: \(max(0, learner.samples.count - 1))").monospacedDigit()
                        HStack {
                            Button(captureStep == 0 ? "Potvrdit stisk" : "Potvrdit otočení") { confirmCapture() }.disabled(lost || !pad.learning || pad.busy)
                            Button("Zkusit znovu") { resetCapture() }
                            Button("Zrušit prvek") { self.kind = nil; detail = "" }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                }
            }
            ForEach(draft.controls) { control in
                HStack {
                    Image(systemName: control.kind == .encoder ? "dial.low.fill" : "square.fill")
                    Text(control.title)
                    Text(control.pins.map { "D\($0)" }.joined(separator: " · ")).font(.caption.monospaced()).foregroundStyle(.secondary)
                    Spacer()
                    Button("Odstranit", role: .destructive) { removeID = control.id }.disabled(!pad.learning || pad.busy)
                }
            }
        }
    }
    private var layout: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Rozmístění a akce").font(.headline)
                    Text("Přetáhněte prvek do buňky. Obsazené buňky si vymění pozici.").foregroundStyle(.secondary)
                }
                Spacer()
                if !pad.learning { Button("Upravit konfiguraci") { pad.beginLearning() }.disabled(!pad.ready || pad.busy) }
                else { Button("Přidat ovladač") { page = 1 } }
            }
            TimelineView(.animation(minimumInterval: 0.05, paused: !pad.ready)) { context in
                let now = context.date.timeIntervalSinceReferenceDate
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 8), spacing: 7) {
                    ForEach(0..<64) { cell in
                        let control = draft.controls.first { $0.x == cell % 8 && $0.y == cell / 8 }
                        let active = control.map { activity.isActive($0.id, at: now) } ?? false
                        let direction = control.map { activity.direction($0.id, at: now) } ?? 0
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(active ? Color.green.opacity(0.28) : control?.id == selected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(control == nil ? 0.05 : 0.12))
                            if let control {
                                VStack(spacing: 4) {
                                    Image(systemName: direction > 0 ? "arrow.clockwise" : direction < 0 ? "arrow.counterclockwise" : control.kind == .encoder ? "dial.low.fill" : "square.fill").font(.title2)
                                        .foregroundStyle(active ? Color.green : Color.primary)
                                    Text(control.title).font(.caption)
                                }
                                .onDrag { NSItemProvider(object: String(control.id) as NSString) }
                            } else { Text("·").foregroundStyle(.quaternary) }
                        }.frame(height: 66).contentShape(Rectangle())
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(active ? Color.green : Color.clear, lineWidth: 2))
                            .accessibilityValue(active ? (direction > 0 ? "Otáčení doprava" : direction < 0 ? "Otáčení doleva" : "Stisknuto") : "V klidu")
                            .onTapGesture { selected = control?.id }
                            .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                                guard pad.learning, !pad.busy, let provider = providers.first else { return false }
                                _ = provider.loadObject(ofClass: String.self) { value, _ in
                                    guard let value, let id = Int(value) else { return }
                                    DispatchQueue.main.async { guard pad.learning, !pad.busy else { return }; draft.move(id, x: cell % 8, y: cell / 8); dirty = true }
                                }
                                return true
                            }
                    }
                }
            }
            Text("Stisk na MacroPadu rozsvítí prvek zeleně. U encoderu se zobrazí i směr otočení.").font(.caption).foregroundStyle(.secondary)
            if let index = draft.controls.firstIndex(where: { $0.id == selected }) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(draft.controls[index].title).font(.headline)
                    HStack {
                        Text("Piny: " + draft.controls[index].pins.map { "D\($0)" }.joined(separator: ", ")).font(.caption.monospaced())
                        Spacer()
                        Button("Odstranit prvek", role: .destructive) { removeID = selected }.disabled(!pad.learning || pad.busy)
                    }
                    HStack {
                        Picker("Sloupec", selection: Binding(get: { draft.controls[index].x }, set: { draft.move(draft.controls[index].id, x: $0, y: draft.controls[index].y); dirty = true })) {
                            ForEach(0..<8) { Text(String($0 + 1)).tag($0) }
                        }
                        Picker("Řádek", selection: Binding(get: { draft.controls[index].y }, set: { draft.move(draft.controls[index].id, x: draft.controls[index].x, y: $0); dirty = true })) {
                            ForEach(0..<8) { Text(String($0 + 1)).tag($0) }
                        }
                    }
                    ForEach(0..<(draft.controls[index].kind == .encoder ? 3 : 1), id: \.self) { action in
                        HardwareActionEditor(title: ["Stisk", "Doleva", "Doprava"][action], macro: Binding(
                            get: { draft.controls.first(where: { $0.id == selected })?.actions[action] ?? MacroDef() },
                            set: { value in
                                guard let current = draft.controls.firstIndex(where: { $0.id == selected }) else { return }
                                draft.controls[current].actions[action] = value; dirty = true
                            }))
                    }
                }.id(selected).disabled(!pad.learning || pad.busy)
            }
            Text("Po dokončení zůstanou zapojení, grid a akce uložené v MacroPadu. Jiný Mac si je načte bez tohoto počítače.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func begin(_ newKind: ControlKind) {
        let free = 11 - draft.controls.flatMap(\.pins).count
        guard free >= (newKind == .encoder ? 3 : 1) else { detail = "Pro encoder potřebujete tři volné piny."; return }
        kind = newKind; captureStep = 0; clockwise = nil; resetCapture()
    }
    private func resetCapture() {
        learner = PinLearner(excluded: Set(draft.controls.flatMap(\.pins)))
        if captureStep > 0 { learner.excluded.insert(pushPin) }
        if let latest { learner.append(latest) }
        lost = false; detail = ""
    }
    private func confirmCapture() {
        do {
            guard let kind else { return }
            if captureStep == 0 {
                pushPin = try learner.click()
                if kind == .encoder { captureStep = 1; resetCapture(); return }
            } else if captureStep == 1 {
                clockwise = try learner.rotation(); captureStep = 2; resetCapture(); return
            } else {
                let reverse = try learner.rotation()
                guard let clockwise, reverse.0 == clockwise.0, reverse.1 == clockwise.1, reverse.2 == -clockwise.2 else {
                    throw BLEProtocol.Failure(message: "Směr nebo piny nesouhlasí. Zopakujte pohyb doleva.")
                }
            }
            guard let id = (0..<11).first(where: { id in !draft.controls.contains { $0.id == id } }),
                  let cell = (0..<64).first(where: { cell in !draft.controls.contains { $0.x == cell % 8 && $0.y == cell / 8 } }) else { return }
            var control = HardwareControl(id: id, kind: kind, pin: pushPin, x: cell % 8, y: cell / 8)
            if let clockwise, kind == .encoder {
                control.a = clockwise.2 > 0 ? clockwise.0 : clockwise.1
                control.b = clockwise.2 > 0 ? clockwise.1 : clockwise.0
                control.actions = [MacroDef(kind: .media, media: 0xe2), MacroDef(kind: .media, media: 0xea), MacroDef(kind: .media, media: 0xe9)]
            }
            draft.controls.append(control); selected = id; dirty = true; self.kind = nil
            detail = "Rozpoznáno: \(control.title), piny \(control.pins.map { "D\($0)" }.joined(separator: ", "))."
        } catch { detail = error.localizedDescription }
    }
    private func install() {
        guard let chosenVolume else { return }
        flashing = true; pad.disconnect(); detail = "Nahrávám firmware. Neodpojujte kabel…"
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try FirmwareInstaller.install(on: chosenVolume) }
            DispatchQueue.main.async {
                flashing = false
                switch result {
                case .success: detail = "Firmware byl zapsán. Deska se restartuje. Spárujte ji v Bluetooth a klikněte na Hledat MacroPad."; pad.start()
                case .failure(let error): detail = "Nahrání se nepodařilo ověřit: \(error.localizedDescription)"
                }
            }
        }
    }
}

private struct HardwareActionEditor: View {
    let title: String
    @Binding var macro: MacroDef
    @StateObject private var recorder = KeyRecorder()
    @Environment(\.isEnabled) private var isEnabled
    var body: some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Akce", selection: $macro.kind) { ForEach(MacroKind.allCases) { Text($0.title).tag($0) } }
                switch macro.kind {
                case .media:
                    Picker("Klávesa", selection: $macro.media) { ForEach(MediaKey.all) { Text($0.title).tag($0.code) } }
                case .mouse:
                    Picker("Pohyb", selection: $macro.mouse) { ForEach(MouseAction.allCases) { Text($0.title).tag($0) } }
                case .micMute:
                    Text("Pošle F18. Pro ztlumení mikrofonu musí na cílovém Macu běžet MacroPad.app.").font(.caption)
                case .keys:
                    HStack {
                        Text(macro.chords.isEmpty ? "Bez akce" : macro.chords.map(\.label).joined(separator: " → "))
                        Spacer()
                        Button("Vymazat") { macro.chords = [] }
                        Button(recorder.recording == nil ? "Nahrát zkratku" : "Zastavit (Esc)") {
                            if recorder.recording == nil { recorder.start(slot: 0) } else { recorder.stop() }
                        }
                    }
                    Text("Nejvýše pět stisků v jednom makru.").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(6)
        }
        .onAppear { recorder.onChord = { _, chord in if macro.chords.count < 5 { macro.chords.append(chord) } } }
        .onChange(of: macro.kind) { _ in recorder.stop() }
        .onChange(of: isEnabled) { enabled in if !enabled { recorder.stop() } }
        .onDisappear { recorder.stop() }
    }
}
