import SwiftUI

struct HostManagerView: View {
    @ObservedObject var pad: LearningPad
    @Environment(\.dismiss) private var dismiss
    @State private var renaming: SavedHost?
    @State private var name = ""
    @State private var namingPending = false
    @State private var repairingHost: SavedHost?
    @State private var confirmRepair = false
    var body: some View {
        TimelineView(.periodic(from: .now, by: 3)) { _ in content }
    }
    private var content: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    StudioSection(title: "Bluetooth a výstup")
                    Text("Vaše zařízení").font(.system(size: 26, weight: .semibold, design: .rounded))
                }
                Spacer()
                Button("Hotovo") { dismiss() }
            }
            if !pad.ready {
                Text("MacroPad je odpojený. Po obnovení spojení se seznam načte přímo ze zařízení.").foregroundStyle(.secondary)
            } else if !pad.supportsHosts {
                Label("Nejdřív nahrajte aktuální firmware v nastavení zařízení.", systemImage: "arrow.down.circle").foregroundStyle(Studio.accent)
            } else if let snapshot = pad.hosts {
                HStack(spacing: 14) {
                    Image(systemName: snapshot.usbOutput ? "cable.connector" : "laptopcomputer")
                        .font(.system(size: 26)).foregroundStyle(Studio.accent)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(snapshot.fresh ? "Výstup: \(snapshot.destination)" : "Čekám na aktuální stav…").font(.system(size: 16, weight: .semibold))
                        Text("Připojení appky a cíl kláves jsou dvě různé věci.").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }.padding(18).background(Studio.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(snapshot.hosts) { host in
                            HStack(spacing: 14) {
                                Image(systemName: "laptopcomputer").font(.system(size: 25, weight: .light)).foregroundStyle(host.thisMac ? Studio.accent : .secondary)
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(host.title).font(.system(size: 15, weight: .semibold))
                                        if host.thisMac && host.title != "Tento Mac" { Text("Tento Mac").font(.caption).foregroundStyle(Studio.accent) }
                                    }
                                    Text(host.selected ? (snapshot.usbOutput ? "Vybráno pro Bluetooth · výstup nyní USB" : host.connected ? "Ovládáno přes Bluetooth" : "Vybráno · čekám na spojení") : host.connected ? "Připojeno · neovládá se" : "Uloženo · mimo dosah nebo odpojeno")
                                        .font(.system(size: 11)).foregroundStyle(host.selected && !snapshot.usbOutput ? Studio.accent : .secondary)
                                    if host.slots.count > 1 {
                                        Text("Stejná identita ve slotech \(host.slots.map { String($0+1) }.joined(separator: ", ")). Zobrazeno jako jedno zařízení.")
                                            .font(.system(size: 10)).foregroundStyle(.orange)
                                    }
                                }
                                Spacer()
                                if snapshot.canRepair && !host.thisMac && snapshot.pairingSlot == nil {
                                    Button { repairingHost = host; confirmRepair = true } label: { Image(systemName: "arrow.triangle.2.circlepath") }
                                        .help("Obnovit párování, pokud počítač MacroPad zapomněl")
                                        .accessibilityLabel("Obnovit párování: \(host.title)")
                                }
                                Button { renaming = host; name = host.name; namingPending = false } label: { Image(systemName: "pencil") }.help("Pojmenovat zařízení")
                                Button(host.selected && !snapshot.usbOutput ? "Vybráno" : "Ovládat") { pad.manageHost(Data([1, UInt8(host.target)])) }
                                    .buttonStyle(StudioButton(prominent: !(host.selected && !snapshot.usbOutput)))
                                    .disabled(host.selected && !snapshot.usbOutput)
                            }.padding(16).background(Studio.surface, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }.frame(maxHeight: 310)
                .disabled(!snapshot.fresh || pad.hostBusy || pad.busy || pad.learning)
                if snapshot.pairingSlot != nil {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("\(snapshot.repairing ? "Obnova párování" : "Párování nového zařízení") · \(snapshot.pairingSeconds) s", systemImage: "antenna.radiowaves.left.and.right")
                                .foregroundStyle(Studio.accent)
                            Text(snapshot.repairing ? "Na opravovaném počítači zapomeňte starý záznam MacroPadu, pokud tam ještě je, a znovu jej připojte. Starý klíč byl odstraněn; po vypršení se vrátí výběr tohoto Macu." : "Na novém počítači otevřete Bluetooth a připojte MacroPad. Po vypršení se vrátí původní výběr.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Zrušit") { pad.manageHost(Data([4])) }.disabled(pad.hostBusy || !snapshot.fresh)
                    }.padding(16).background(Studio.surface, in: RoundedRectangle(cornerRadius: 14))
                } else {
                    HStack {
                        Button { pad.manageHost(Data([3])) } label: { Label("Přidat nové zařízení", systemImage: "plus") }
                            .disabled(snapshot.used >= snapshot.capacity || pad.hostBusy || pad.busy || pad.learning || !snapshot.fresh)
                        Text("\(snapshot.capacity-snapshot.used) volných slotů").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Použít USB") { pad.manageHost(Data([5])) }
                            .disabled(pad.power?.mode == .battery || pad.hostBusy || pad.busy || pad.learning || !snapshot.fresh)
                    }
                }
                Text("Uložený počítač znovu nepárujte — vyberte Ovládat. Názvy se ukládají do MacroPadu a uvidíte je i na druhém Macu. Přepnutí nemaže párování; appka může zůstat připojená.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if snapshot.usbOutput && !snapshot.hosts.contains(where: { $0.selected && $0.connected }) {
                    Text("Pokud zvolené Bluetooth zařízení není dostupné, firmware může dočasně posílat klávesy přes USB.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else { ProgressView("Načítám uložená zařízení…") }
            if !pad.hostMessage.isEmpty { Text(pad.hostMessage).font(.caption).foregroundStyle(.secondary) }
        }
        .padding(28).frame(width: 690).background(Studio.background).preferredColorScheme(.dark)
        .buttonStyle(StudioButton()).tint(Studio.accent)
        .onAppear { pad.refreshHosts() }
        .alert("Obnovit párování zařízení \(repairingHost?.title ?? "")?", isPresented: $confirmRepair) {
            Button("Zrušit", role: .cancel) { repairingHost = nil }
            Button("Odstranit starý klíč a spárovat", role: .destructive) {
                if let host = repairingHost, let packet = HostProfiles.repairPacket(host) { pad.manageHost(packet) }
                repairingHost = nil
            }
        } message: {
            Text("MacroPad odstraní starý párovací klíč pouze tohoto počítače. Potom jej musíte na tomto počítači znovu spárovat. Zrušení následného párování starý klíč nevrátí. Ostatní počítače a konfigurace tlačítek zůstanou zachované.")
        }
        .sheet(item: $renaming) { host in
            VStack(alignment: .leading, spacing: 18) {
                Text("Pojmenovat zařízení").font(.title2.bold())
                TextField("Např. MacBook doma", text: $name).textFieldStyle(.roundedBorder)
                Text("Krátký název se uloží do MacroPadu a bude viditelný na obou počítačích.")
                    .font(.caption).foregroundStyle(.secondary)
                if !name.isEmpty && HostProfiles.renamePacket(slot: host.target, name: name) == nil {
                    Text("Název je příliš dlouhý nebo obsahuje nepodporované znaky.").font(.caption).foregroundStyle(.orange)
                }
                HStack {
                    Button("Zrušit") { renaming = nil }.disabled(pad.hostBusy)
                    Spacer()
                    Button("Uložit název") {
                        if let packet = HostProfiles.renamePacket(slot: host.target, name: name) {
                            namingPending = true; pad.manageHost(packet)
                        }
                    }.buttonStyle(StudioButton(prominent: true))
                        .disabled(!pad.ready || pad.busy || pad.learning || pad.hostBusy || HostProfiles.renamePacket(slot: host.target, name: name) == nil || pad.hosts?.fresh != true)
                }
                if namingPending { Text(pad.hostMessage).font(.caption).foregroundStyle(.secondary) }
            }.padding(26).frame(width: 410).background(Studio.surface)
            .onChange(of: pad.hostBusy) { busy in
                if !busy, namingPending, pad.hosts?.hosts.first(where: { $0.id == host.id })?.name == name.trimmingCharacters(in: .whitespacesAndNewlines) { renaming = nil }
            }
        }
    }
}
