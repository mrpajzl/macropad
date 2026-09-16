import SwiftUI
import UniformTypeIdentifiers

struct HardwareWorkspace: View {
    @ObservedObject var pad: LearningPad
    @State private var draft = HardwareProject()
    @State private var activity = HardwareActivity()
    @State private var dirty = false
    @State private var page = 0
    @State private var showSetup = false
    @State private var showPower = false
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
            HStack(spacing: 14) {
                Image(systemName: "square.grid.2x2.fill").font(.system(size: 20)).foregroundStyle(Studio.accent)
                    .frame(width: 44, height: 44).background(Studio.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 4) {
                    Text("MacroPad").font(.system(size: 23, weight: .semibold, design: .rounded))
                    Text("Malé zařízení. Vaše zkratky.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { showPower.toggle() } label: {
                    TimelineView(.periodic(from: .now, by: 10)) { context in
                        let fresh = pad.ready && pad.power?.isFresh(at: context.date) == true
                        Label(fresh ? pad.power?.percent.map { "\($0) %" } ?? "Baterie" : "Baterie",
                              systemImage: fresh && pad.power?.mode == .charging ? "battery.100.bolt" : "battery.100")
                    }
                }
                .popover(isPresented: $showPower) { PowerDetails(pad: pad) }
                StudioBadge(title: pad.ready ? "Připojeno" : "Odpojeno", color: pad.ready ? .green : .gray)
                Button { openSetup() } label: { Label("Nastavení zařízení", systemImage: "slider.horizontal.3") }
                    .disabled(pad.busy)
            }.padding(.bottom, 14)
            Rectangle().fill(Studio.border).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if draft.controls.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "keyboard").font(.system(size: 52, weight: .ultraLight)).foregroundStyle(Studio.accent)
                                .frame(width: 140, height: 110).background(Studio.surface, in: RoundedRectangle(cornerRadius: 24))
                            Text(pad.ready ? "Přidejte první tlačítka a encoder" : "Připojte svůj MacroPad").font(.title3.bold())
                            Text("Zapojení a rozložení nastavíte v nastavení zařízení. Tady pak budete upravovat zkratky.")
                                .foregroundStyle(.secondary).multilineTextAlignment(.center)
                            Button("Otevřít nastavení MacroPadu") { openSetup() }.buttonStyle(StudioButton(prominent: true))
                        }.frame(maxWidth: .infinity).padding(40)
                    } else { layout }
                    if !detail.isEmpty { Text(detail).foregroundStyle(.secondary).textSelection(.enabled) }
                }.padding(2)
            }
            Rectangle().fill(Studio.border).frame(height: 1)
            HStack(spacing: 12) {
                Image(systemName: dirty ? "circle.dotted" : "checkmark.circle").foregroundStyle(dirty ? Studio.accent : Color.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(pad.busy ? "Pracuji se zařízením…" : !pad.ready ? "Zařízení je odpojené" : dirty ? "Změny čekají na uložení" : "Vše je připravené").font(.system(size: 12, weight: .medium))
                    Text(pad.message).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled)
                }
                if dirty {
                    Button("Zahodit změny", role: .destructive) { showDiscard = true }
                }
                Spacer()
                Button(pad.busy ? "Ukládám…" : "Uložit změny") { saveDraft() }
                    .buttonStyle(StudioButton(prominent: true))
                    .disabled(!pad.ready || pad.busy || draft.controls.isEmpty || !dirty)
            }
        }
        .padding(28).padding(.top, 12).frame(minWidth: 900, minHeight: 600)
        .background(LinearGradient(colors: [Color(red: 0.09, green: 0.105, blue: 0.12), Studio.background], startPoint: .topLeading, endPoint: .bottomTrailing))
        .preferredColorScheme(.dark).tint(Studio.accent)
        .buttonStyle(StudioButton()).groupBoxStyle(StudioGroupBox())
        .disabled(flashing)
        .sheet(isPresented: $showSetup, onDismiss: {
            kind = nil
            pad.endLearning()
        }) { setupSheet }
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
                    let finished = saving
                    draft = project; dirty = false; saving = false
                    page = project.controls.isEmpty ? 1 : 2
                    if !project.controls.contains(where: { $0.id == selected }) { selected = project.controls.first?.id }
                    if finished { showSetup = false; detail = "Změny jsou uložené v MacroPadu." }
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
            if showSetup && page == 0 {
                bootVolumes = FirmwareInstaller.volumes()
                if chosenVolume == nil || !bootVolumes.contains(chosenVolume!) { chosenVolume = bootVolumes.first }
            }
        }
        .alert("Zahodit rozpracované změny?", isPresented: $showDiscard) {
            Button("Zahodit", role: .destructive) { draft = pad.project; dirty = false; kind = nil; pad.endLearning() }
            Button("Pokračovat v úpravách", role: .cancel) {}
        } message: { Text("Konfigurace uložená v MacroPadu se nezmění.") }

    }
    private func openSetup() {
        page = pad.ready ? (draft.controls.isEmpty ? 1 : 2) : 0
        detail = ""; showSetup = true
    }
    private func saveDraft() {
        saving = true; kind = nil; pad.save(draft)
    }
    private var setupSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nastavení MacroPadu").font(.title2.bold())
                    Text(pad.message).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Zavřít") { showSetup = false }.disabled(pad.busy || flashing)
            }
            HStack {
                step("Připojení a firmware", number: 0)
                step("Zapojení prvků", number: 1)
                step("Rozložení", number: 2)
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if page == 0 { installation }
                    else if page == 1 { discovery }
                    else { layout }
                    if !detail.isEmpty { Text(detail).foregroundStyle(.secondary).textSelection(.enabled) }
                }.padding(2)
            }
            Divider()
            HStack {
                Text(pad.learning ? "Poznávání je zapnuté · makra jsou dočasně vypnutá" : "Změny se uloží až potvrzením.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if page == 1 {
                    Button("Pokračovat na rozložení") { kind = nil; page = 2 }.disabled(kind != nil || draft.controls.isEmpty || pad.busy)
                }
                if page == 2 {
                    Button(pad.busy ? "Ukládám…" : "Uložit a přejít na zkratky") { saveDraft() }
                        .buttonStyle(StudioButton(prominent: true))
                        .disabled(!pad.ready || pad.busy || draft.controls.isEmpty)
                }
            }
        }
        .padding(28).frame(width: 860, height: 720)
        .background(Studio.background).preferredColorScheme(.dark).tint(Studio.accent)
        .buttonStyle(StudioButton()).groupBoxStyle(StudioGroupBox())
        .interactiveDismissDisabled(pad.busy || flashing)
        .alert("Nahrát univerzální firmware?", isPresented: $showInstall) {
            Button("Nahrát firmware") { install() }
            Button("Zrušit", role: .cancel) {}
        } message: {
            Text("Nahradí firmware na vybraném XIAO. Párování zůstane zachované. Původní pevné rozložení bude nahrazeno průvodcem pro naučení zapojení.")
        }
        .alert("Odstranit ovladač i jeho akce?", isPresented: Binding(get: { removeID != nil }, set: { if !$0 { removeID = nil } })) {
            Button("Odstranit", role: .destructive) {
                draft.controls.removeAll { $0.id == removeID }; selected = draft.controls.first?.id; removeID = nil; dirty = true
            }
            Button("Zrušit", role: .cancel) { removeID = nil }
        }
    }
    private func step(_ title: String, number: Int) -> some View {
        Button { page = number } label: {
            HStack(spacing: 9) {
                Text(String(format: "%02d", number + 1)).font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(page == number ? Studio.accent : Color.secondary)
                Text(title).font(.system(size: 12, weight: .medium))
            }.frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(page == number ? Studio.surface : .clear, in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(page == number ? Studio.accent.opacity(0.3) : Studio.border))
        }.buttonStyle(.plain)
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
                Button("Zapnout poznávání zapojení") { pad.beginLearning() }.buttonStyle(StudioButton(prominent: true)).disabled(!pad.ready || pad.busy)
            } else if !pad.receivingSamples {
                ProgressView("Čekám na data ze snímače…")
            } else if kind == nil {
                HStack {
                    StudioChoice(title: "Tlačítko", subtitle: "Jeden stisk. Vaše akce.", symbol: "square") { begin(.button) }
                    StudioChoice(title: "Encoder", subtitle: "Otáčení a stisk kolečka.", symbol: "dial.low") { begin(.encoder) }
                }.disabled(pad.busy || draft.controls.flatMap(\.pins).count >= 11)
                Text("Při učení používejte jen právě přidávaný ovladač. Před každým krokem ho pusťte.").foregroundStyle(.secondary)
            }
            if let kind {
                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(captureStep == 0 ? "Stiskněte a pusťte \(kind == .button ? "tlačítko" : "kolečko")." : captureStep == 1 ? "Otočte kolečkem alespoň dva kroky doprava." : "Teď otočte alespoň dva kroky doleva.").font(.title3.bold())
                        HStack {
                            StudioBadge(title: lost ? "Přenos přerušen" : "Snímám pohyb", color: lost ? .orange : Studio.accent)
                            Text("\(max(0, learner.samples.count - 1)) změn").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
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
                    Button("Odstranit", role: .destructive) { removeID = control.id }.disabled(!pad.ready || pad.busy)
                }
            }
        }
    }
    private var layout: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showSetup {
            HStack {
                VStack(alignment: .leading) {
                    Text(showSetup ? "Rozložení prvků" : "Vyberte tlačítko nebo encoder").font(.headline)
                    Text(showSetup ? "Přetáhněte prvek do buňky. Obsazené buňky si vymění pozici." : "Kliknutím na prvek upravíte jeho zkratky a akce.").foregroundStyle(.secondary)
                }
                Spacer()
                if showSetup { Button("Přidat ovladač") { page = 1 }.disabled(pad.busy) }
            }
            }
            if showSetup {
                activityGrid
                controlInspector
            } else {
                HStack(alignment: .top, spacing: 20) {
                    DevicePreview(controls: draft.controls, activity: activity, connected: pad.ready, selected: $selected)
                        .frame(maxWidth: .infinity)
                    controlInspector.frame(width: 310)
                        .padding(20).background(Studio.surface, in: RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Studio.border))
                }
            }
            if showSetup { Text("Rozložení se uloží přímo do MacroPadu.").font(.caption).foregroundStyle(.secondary) }
        }
    }
    private var activityGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            TimelineView(.animation(minimumInterval: 0.05, paused: !pad.ready)) { context in
                let now = context.date.timeIntervalSinceReferenceDate
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 8), spacing: 7) {
                    ForEach(0..<64) { cell in
                        let control = draft.controls.first { $0.x == cell % 8 && $0.y == cell / 8 }
                        let active = control.map { activity.isActive($0.id, at: now) } ?? false
                        let direction = control.map { activity.direction($0.id, at: now) } ?? 0
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(active ? Color.green.opacity(0.28) : control?.id == selected ? Studio.accent.opacity(0.2) : Color.secondary.opacity(control == nil ? 0.05 : 0.12))
                            if let control {
                                VStack(spacing: 4) {
                                    Image(systemName: direction > 0 ? "arrow.clockwise" : direction < 0 ? "arrow.counterclockwise" : control.kind == .encoder ? "dial.low.fill" : "square.fill").font(.title2)
                                        .foregroundStyle(active ? Color.green : Color.primary)
                                    Text(control.title).font(.caption)
                                }
                                .onDrag { NSItemProvider(object: String(control.id) as NSString) }
                            } else { Text("·").foregroundStyle(.quaternary) }
                        }.frame(height: showSetup ? 66 : 50).contentShape(Rectangle())
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(active ? Color.green : Color.clear, lineWidth: 2))
                            .accessibilityValue(active ? (direction > 0 ? "Otáčení doprava" : direction < 0 ? "Otáčení doleva" : "Stisknuto") : "V klidu")
                            .onTapGesture { selected = control?.id }
                            .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                                guard showSetup, pad.ready, !pad.busy, let provider = providers.first else { return false }
                                _ = provider.loadObject(ofClass: String.self) { value, _ in
                                    guard let value, let id = Int(value) else { return }
                                    DispatchQueue.main.async { guard showSetup, pad.ready, !pad.busy else { return }; draft.move(id, x: cell % 8, y: cell / 8); dirty = true }
                                }
                                return true
                            }
                    }
                }
            }
            Text("Stisk na MacroPadu rozsvítí prvek zeleně. U encoderu se zobrazí i směr otočení.").font(.caption).foregroundStyle(.secondary)
        }
    }
    @ViewBuilder private var controlInspector: some View {
            if let index = draft.controls.firstIndex(where: { $0.id == selected }) {
                VStack(alignment: .leading, spacing: 12) {
                    StudioSection(title: showSetup ? "Pozice prvku" : "Nastavení akce")
                    HStack(spacing: 12) {
                        Image(systemName: draft.controls[index].kind == .encoder ? "dial.low" : "square")
                            .font(.system(size: 21)).foregroundStyle(Studio.accent)
                            .frame(width: 42, height: 42).background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(draft.controls[index].title).font(.system(size: 18, weight: .semibold, design: .rounded))
                            Text(draft.controls[index].kind == .encoder ? "Stisk a oba směry otáčení" : "Akce při stisku klávesy").font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.bottom, 8)
                    if showSetup {
                    HStack {
                        Text("Piny: " + draft.controls[index].pins.map { "D\($0)" }.joined(separator: ", ")).font(.caption.monospaced())
                        Spacer()
                        Button("Odstranit prvek", role: .destructive) { removeID = selected }.disabled(!pad.ready || pad.busy)
                    }
                    HStack {
                        Picker("Sloupec", selection: Binding(get: { draft.controls[index].x }, set: { draft.move(draft.controls[index].id, x: $0, y: draft.controls[index].y); dirty = true })) {
                            ForEach(0..<8) { Text(String($0 + 1)).tag($0) }
                        }
                        Picker("Řádek", selection: Binding(get: { draft.controls[index].y }, set: { draft.move(draft.controls[index].id, x: draft.controls[index].x, y: $0); dirty = true })) {
                            ForEach(0..<8) { Text(String($0 + 1)).tag($0) }
                        }
                    }
                    }
                    if !showSetup {
                        ControlActionsEditor(kind: draft.controls[index].kind, actions: Binding(
                            get: { draft.controls.first(where: { $0.id == selected })?.actions ?? [MacroDef(), MacroDef(), MacroDef()] },
                            set: { actions in
                                guard let current = draft.controls.firstIndex(where: { $0.id == selected }) else { return }
                                draft.controls[current].actions = actions; dirty = true
                            }))

                    }
                }.id(selected).disabled(!pad.ready || pad.busy)
            }
            else if !showSetup {
                Text("Vyberte prvek v gridu.").foregroundStyle(.secondary).padding()
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

struct ControlActionsEditor: View {
    let kind: ControlKind
    @Binding var actions: [MacroDef]
    @State private var editing: Int?
    private let titles = ["Stisk", "Doleva", "Doprava"]
    private let symbols = ["hand.tap", "arrow.counterclockwise", "arrow.clockwise"]

    var body: some View {
        if kind == .button {
            HardwareActionEditor(title: "Stisk", macro: $actions[0])
        } else {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(0..<3, id: \.self) { index in
                    Button { editing = editing == index ? nil : index } label: {
                        HStack(spacing: 12) {
                            Image(systemName: symbols[index]).font(.system(size: 17))
                                .foregroundStyle(Studio.accent).frame(width: 22)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(titles[index]).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                                Text(actions[index].previewTitle).font(.system(size: 13, weight: .medium))
                                    .lineLimit(2).multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: editing == index ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                        }.padding(13).frame(maxWidth: .infinity, alignment: .leading)
                            .background(editing == index ? Studio.accent.opacity(0.07) : .white.opacity(0.025), in: RoundedRectangle(cornerRadius: 11))
                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(editing == index ? Studio.accent.opacity(0.3) : Studio.border))
                    }.buttonStyle(.plain)
                        .accessibilityLabel("\(titles[index]): \(actions[index].previewTitle). Upravit akci")
                        .accessibilityAddTraits(editing == index ? .isSelected : [])
                }
                if let editing {
                    HardwareActionEditor(title: "Upravit · " + titles[editing], macro: $actions[editing])
                        .id(editing)
                } else {
                    Text("Vyberte pohyb, jehož akci chcete změnit.")
                        .font(.caption).foregroundStyle(.secondary).padding(.top, 8)
                }
            }
        }
    }
}

struct HardwareActionEditor: View {
    let title: String
    @Binding var macro: MacroDef
    @StateObject private var recorder = KeyRecorder()
    @State private var showActionMenu = false
    @Environment(\.isEnabled) private var isEnabled
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: title.hasSuffix("Doleva") ? "arrow.counterclockwise" : title.hasSuffix("Doprava") ? "arrow.clockwise" : "hand.tap")
                    .foregroundStyle(Studio.accent)
                Text(title).font(.system(size: 12, weight: .semibold))
            }
            HStack(spacing: 4) {
                ForEach(MacroKind.allCases) { kind in
                    Button { macro.kind = kind } label: {
                        VStack(spacing: 6) {
                            Image(systemName: kind.studioSymbol).font(.system(size: 15))
                            Text(kind.studioTitle).font(.system(size: 9, weight: .medium))
                        }.frame(maxWidth: .infinity).padding(.vertical, 11)
                            .foregroundStyle(macro.kind == kind ? Studio.accent : Color.secondary)
                            .background(macro.kind == kind ? Studio.accent.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(macro.kind == kind ? Studio.accent.opacity(0.25) : .clear))
                    }.buttonStyle(.plain).accessibilityAddTraits(macro.kind == kind ? .isSelected : [])
                }
            }.padding(4).background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
            switch macro.kind {
            case .media:
                actionMenu(title: MediaKey.all.first { $0.code == macro.media }?.title ?? "Vyberte akci") {
                    ForEach(MediaKey.all) { key in choiceRow(key.title, selected: macro.media == key.code) { macro.media = key.code } }
                }
            case .mouse:
                actionMenu(title: macro.mouse.title) {
                    ForEach(MouseAction.allCases) { action in choiceRow(action.title, selected: macro.mouse == action) { macro.mouse = action } }
                }
            case .micMute:
                Label("Přepnout mikrofon", systemImage: "mic.slash").font(.system(size: 13, weight: .medium))
                Text("Ztlumí mikrofon na připojeném Macu. MacroPad.app musí běžet.").font(.caption).foregroundStyle(.secondary)
            case .keys:
                VStack(alignment: .leading, spacing: 12) {
                    if macro.chords.isEmpty {
                        Text(recorder.recording == nil ? "Zatím bez zkratky" : "Stiskněte klávesovou zkratku…")
                            .font(.system(size: 12)).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 36)
                    } else {
                        ViewThatFits(in: .horizontal) {
                            chordSequence
                            ScrollView(.horizontal) { chordSequence }
                        }
                    }
                    HStack {
                        Button {
                            if recorder.recording == nil { recorder.start(slot: 0) } else { recorder.stop() }
                        } label: { Label(recorder.recording == nil ? "Nahrát zkratku" : "Zastavit", systemImage: recorder.recording == nil ? "record.circle" : "stop.circle") }
                            .buttonStyle(StudioButton(prominent: recorder.recording != nil))
                        Spacer(minLength: 0)
                        if !macro.chords.isEmpty { Button { macro.chords = [] } label: { Image(systemName: "trash") }.help("Vymazat zkratku") }
                    }
                    Text(recorder.recording == nil ? "Až 5 stisků za sebou." : "Esc ukončí nahrávání.").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 16)
        .overlay(alignment: .top) { Rectangle().fill(Studio.border).frame(height: 1) }
        .onAppear { recorder.onChord = { _, chord in if macro.chords.count < 5 { macro.chords.append(chord) } } }
        .onChange(of: macro.kind) { _ in recorder.stop() }
        .onChange(of: isEnabled) { enabled in if !enabled { recorder.stop() } }
        .onDisappear { recorder.stop() }
    }
    private var chordSequence: some View {
        HStack(spacing: 5) {
            ForEach(Array(macro.chords.enumerated()), id: \.offset) { _, chord in
                Text(chord.label).font(.system(size: 15, weight: .medium, design: .rounded))
                    .padding(.horizontal, 10).padding(.vertical, 9)
                    .background(LinearGradient(colors: [.white.opacity(0.09), .white.opacity(0.03)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Studio.border))
            }
        }
    }
    private func actionMenu<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        Button { showActionMenu = true } label: {
            HStack {
                Text(title).font(.system(size: 13, weight: .medium))
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10)).foregroundStyle(.secondary)
            }.padding(13).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Studio.border))
        }.buttonStyle(.plain)
        .popover(isPresented: $showActionMenu, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                StudioSection(title: "Vyberte akci")
                ScrollView { VStack(spacing: 4) { content() } }.frame(maxHeight: 340)
            }.padding(16).frame(width: 270).background(Studio.surface).preferredColorScheme(.dark)
        }
    }
    private func choiceRow(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { action(); showActionMenu = false } label: {
            HStack {
                Text(title).font(.system(size: 12, weight: .medium))
                Spacer()
                if selected { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
            }.padding(11).foregroundStyle(selected ? Studio.accent : Color.primary)
                .background(selected ? Studio.accent.opacity(0.08) : Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }
}
