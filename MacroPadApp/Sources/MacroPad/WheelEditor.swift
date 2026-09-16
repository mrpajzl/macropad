import SwiftUI
import UniformTypeIdentifiers

struct WheelEditor: View {
    let device: String
    let control: Int
    @Binding var mode: HoldMode
    let kind: ControlKind
    let firmwareVersion: UInt8
    private var supported: Bool { firmwareVersion >= (kind == .encoder ? 2 : 1) }
    @ObservedObject private var settings = WheelSettings.shared
    @State private var editing = false
    private var actions: Binding<[WheelAction]> {
        Binding(get: { settings.actions(device: device, control: control) }, set: { settings.set($0, device: device, control: control) })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Label(kind == .encoder ? "Podržení encoderu" : "Podržení tlačítka", systemImage: "circle.hexagongrid.fill").font(.headline)
            Picker("Funkce", selection: $mode) {
                ForEach(HoldMode.allCases) { option in
                    Text(option == .disabled && kind == .encoder ? "Bluetooth zkratky" : option.title).tag(option)
                        .disabled(!WheelCapabilities.supports(mode: option, kind: kind, version: firmwareVersion))
                }
            }.disabled(!supported)
            if !supported {
                Text("Nejdřív aktualizujte firmware v Nastavení zařízení. Tento firmware ještě neumí podržení.")
                    .font(.caption).foregroundStyle(.orange)
            }
            if mode != .disabled {
                Text("Podržte 350 ms, otočením vyberte, puštěním potvrďte. Krátký stisk zachová akci výše. MacroPad.app musí běžet.")
                    .font(.caption).foregroundStyle(.secondary)
                if mode == .device {
                    Text("Uložené počítače, USB, baterie, mikrofon a nastavení. Nabídka ukazuje aktuální cíl ovládání a stav MacroPadu.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if kind == .encoder {
                    Text("Otáčení při podržení ovládá menu. Bluetooth zkratky obnovíte volbou Bluetooth zkratky.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    if mode == .actions { Button("Upravit menu…") { editing = true } }
                    Button("Náhled") { ActionWheel.shared.show(mode: mode, control: control, preview: true, device: device) }
                }
            }
            if !settings.error.isEmpty { Text(settings.error).font(.caption).foregroundStyle(.orange) }
        }
        .sheet(isPresented: $editing) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Kruhové menu · ovladač \(control + 1)").font(.title2.bold())
                    Spacer(); Button("Hotovo") { editing = false }
                }
                Text("Položky se ukládají automaticky na tomto Macu. Zapnutí podržení potvrďte tlačítkem Uložit změny.")
                    .font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(actions) { $action in
                            WheelActionEditor(action: $action, remove: {
                                var value = actions.wrappedValue; value.removeAll { $0.id == action.id }; actions.wrappedValue = value
                            }, move: { delta in
                                var value = actions.wrappedValue
                                if let index = value.firstIndex(where: { $0.id == action.id }), value.indices.contains(index + delta) {
                                    value.swapAt(index, index + delta); actions.wrappedValue = value
                                }
                            })
                        }
                    }.padding(2)
                }
                HStack {
                    Button("Přidat akci") { actions.wrappedValue.append(WheelAction()) }.disabled(actions.wrappedValue.count >= 8)
                    Text("\(actions.wrappedValue.count) / 8 položek").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(24).frame(width: 600, height: 650).background(Studio.background)
                .preferredColorScheme(.dark).buttonStyle(StudioButton()).tint(Studio.accent)
        }
    }
}
private struct WheelActionEditor: View {
    @Binding var action: WheelAction
    let remove: () -> Void
    let move: (Int) -> Void
    @StateObject private var recorder = KeyRecorder()
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Název položky", text: $action.title)
                Button { move(-1) } label: { Image(systemName: "arrow.up") }
                Button { move(1) } label: { Image(systemName: "arrow.down") }
                Button(role: .destructive, action: remove) { Image(systemName: "trash") }
            }
            Picker("Typ", selection: $action.kind) {
                Text("Aplikace").tag(WheelAction.Kind.application)
                Text("Klávesová zkratka").tag(WheelAction.Kind.keyboard)
                Text("Zkratky macOS").tag(WheelAction.Kind.shortcut)
            }.pickerStyle(.segmented)
            switch action.kind {
            case .application:
                HStack {
                    Text(action.applicationPath.isEmpty ? "Žádná aplikace" : URL(fileURLWithPath: action.applicationPath).deletingPathExtension().lastPathComponent).lineLimit(1)
                    Spacer()
                    Button("Vybrat aplikaci…") {
                        let panel = NSOpenPanel(); panel.allowedContentTypes = [.applicationBundle]
                        panel.directoryURL = URL(fileURLWithPath: "/Applications"); panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            action.applicationPath = url.path
                            action.title = url.deletingPathExtension().lastPathComponent
                        }
                    }
                }
            case .shortcut:
                TextField("Přesný název v aplikaci Zkratky", text: $action.shortcutName)
            case .keyboard:
                HStack {
                    Text(action.chords.isEmpty ? "Nahrajte zkratku" : action.chords.map(\.label).joined(separator: " → "))
                    Spacer()
                    Button(recorder.recording == nil ? "Nahrát" : "Zastavit") {
                        if recorder.recording == nil { action.chords = []; recorder.start(slot: 0) } else { recorder.stop() }
                    }
                }
                Text("Až 5 stisků. Odesílání vyžaduje oprávnění Zpřístupnění.").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(16).background(Studio.surface, in: RoundedRectangle(cornerRadius: 12))
            .onAppear { recorder.onChord = { _, chord in if action.chords.count < 5 { action.chords.append(chord) } } }
            .onChange(of: action.kind) { _ in recorder.stop() }
            .onDisappear { recorder.stop() }
    }
}
