import Foundation
import CoreBluetooth

/// Owns the v2 connection. Only acknowledged, read-back-verified configurations are accepted.
final class LearningPad: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static func uuid(_ suffix: String) -> CBUUID { CBUUID(string: "9a7b\(suffix)-6e57-4b21-9c35-91ae24f3d801") }
    @Published var devices: [CBPeripheral] = []
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published var ready = false
    @Published var busy = false
    @Published var message = "Připojte MacroPad s univerzálním firmwarem."
    @Published var project = HardwareProject()
    @Published var learning = false
    @Published var receivingSamples = false
    @Published var hosts: HostProfiles?
    @Published var supportsWheel = false
    @Published var wheelVersion: UInt8 = 0
    @Published private(set) var firmwareVersion: String?
    @Published private(set) var otaSoftDevice: UInt16?
    var onOTABootloader: (() -> Void)?
    private var rebootForOTA = false
    @Published private(set) var supportsFirmwareUpdate = false
    @Published private(set) var firmwareMessage = ""
    private var firmwareCharacteristic: CBCharacteristic?
    private var firmwareRebootRequested = false
    private var firmwareTimeout: Timer?
    var wheelDeviceKey: String { peripheral?.identifier.uuidString ?? "" }
    @Published var supportsHosts = false
    @Published var hostBusy = false
    @Published var hostMessage = ""
    private var hostsRead: CBCharacteristic?, hostsWrite: CBCharacteristic?
    private var hostTimer: Timer?, hostTimeout: Timer?
    private var hostStartSequence: UInt8?
    private var hostAcknowledged = false
    @Published var power: PowerStatus?
    @Published var powerHistory = PowerHistory()
    @Published var signal: Int?
    @Published var supportsPower = false
    private var powerCharacteristic: CBCharacteristic?, batteryCharacteristic: CBCharacteristic?
    private var powerTimer: Timer?
    private var powerPending = false
    var onSample: ((UInt16, Bool) -> Void)?
    var onLoaded: ((HardwareProject) -> Void)?
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var connectionTarget: UUID?
    private var config: CBCharacteristic?, command: CBCharacteristic?, events: CBCharacteristic?
    private var packets: [Data] = []
    private var expected: Data?
    private var saveBase: Data?
    private var pendingSave: (project: HardwareProject, baseline: Data?)?
    private var validatingBase = false
    private var configReadPending = false
    private var lastLoadedData: Data?
    private var timeout: Timer?, heartbeat: Timer?, reconnect: Timer?
    private var sampleTimeout: Timer?
    private var sequence: UInt16?
    private var beginPending = false
    private var endingLearning = false
    private var writing = false
    private var scanning = false
    private var lastSampleAt: Date?
    override init() { super.init() }
    func start() {
        guard !ready, !busy else { return }
        reconnect?.invalidate()
        scanning = true
        if central == nil { central = CBCentralManager(delegate: self, queue: .main) }
        else { search() }
    }
    private func search() {
        guard central.state == .poweredOn, scanning, !ready else { return }
        // Reconnect the saved identity even when it is already connected to another
        // CoreBluetooth client or has not resumed advertising after a firmware reset.
        if peripheral == nil, !busy,
           let id = connectionTarget ?? UserDefaults.standard.string(forKey: "learnedPad").flatMap(UUID.init(uuidString:)),
           let known = central.retrievePeripherals(withIdentifiers: [id]).first {
            connect(known)
        }
        let connected = central.retrieveConnectedPeripherals(withServices: [CBUUID(string: "1812"), Self.uuid("1000")])
            .filter { $0.name?.localizedCaseInsensitiveContains("macropad") == true }
        for device in connected { found(device) }
        // A fresh Mac can identify an already paired HID device without any local config.
        if peripheral == nil, connected.count == 1, UserDefaults.standard.string(forKey: "learnedPad") == nil {
            connect(connected[0])
        }
        central.scanForPeripherals(withServices: nil)
        if !busy { message = "Hledám MacroPad…" }
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        if central.state == .poweredOn && scanning { search() }
        else if central.state != .poweredOn {
            peripheral = nil; devices = []; reconnect?.invalidate(); reset()
            switch central.state {
            case .poweredOff: message = "Bluetooth je vypnuté. Zapněte ho v nastavení Macu."
            case .unauthorized: message = "Povolte MacroPadu Bluetooth v Nastavení systému → Soukromí a zabezpečení → Bluetooth."
            case .unsupported: message = "Tento Mac nepodporuje požadované Bluetooth spojení."
            default: message = "Čekám na Bluetooth…"
            }
        }
    }
    private func found(_ device: CBPeripheral, advertisedName: String? = nil, services: [CBUUID] = []) {
        guard device.name?.localizedCaseInsensitiveContains("macropad") == true
            || advertisedName?.localizedCaseInsensitiveContains("macropad") == true
            || services.contains(Self.uuid("1000")) else { return }
        if !devices.contains(where: { $0.identifier == device.identifier }) { devices.append(device) }
        if peripheral == nil, UserDefaults.standard.string(forKey: "learnedPad") == device.identifier.uuidString { connect(device) }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        found(peripheral, advertisedName: advertisementData[CBAdvertisementDataLocalNameKey] as? String,
              services: advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? [])
    }
    func connect(_ device: CBPeripheral) {
        guard !busy, central?.state == .poweredOn else { return }
        scanning = true; reconnect?.invalidate(); connectionTarget = device.identifier
        if let old = peripheral, old != device { central.cancelPeripheralConnection(old) }
        reset(); firmwareMessage = ""; peripheral = device; device.delegate = self; busy = true
        message = "Připojuji a čtu konfiguraci…"; central.connect(device); armTimeout()
    }
    func disconnect() {
        scanning = false; reconnect?.invalidate(); central?.stopScan()
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
        peripheral = nil; reset()
    }
    private func reset() {
        firmwareCharacteristic = nil; firmwareVersion = nil; otaSoftDevice = nil; rebootForOTA = false; supportsFirmwareUpdate = false
        firmwareTimeout?.invalidate(); firmwareRebootRequested = false
        hostTimer?.invalidate(); hostTimeout?.invalidate(); hostTimer = nil
        hostsRead = nil; hostsWrite = nil; hosts = nil; supportsHosts = false; hostBusy = false; hostStartSequence = nil; hostMessage = ""
        powerTimer?.invalidate(); powerTimer = nil; powerPending = false
        powerCharacteristic = nil; batteryCharacteristic = nil; supportsPower = false
        power = nil; powerHistory = PowerHistory(); signal = nil
        ActionWheel.shared.cancel(); supportsWheel = false; wheelVersion = 0
        ready = false; busy = false; learning = false; beginPending = false; endingLearning = false; writing = false; packets = []; expected = nil
        pendingSave = nil; saveBase = nil; validatingBase = false; configReadPending = false; lastLoadedData = nil
        config = nil; command = nil; events = nil; sequence = nil
        timeout?.invalidate(); heartbeat?.invalidate(); sampleTimeout?.invalidate(); lastSampleAt = nil; receivingSamples = false
    }
    private func fail(_ text: String) {
        message = text
        // Clear ownership before cancelling: CoreBluetooth does not guarantee a
        // disconnect callback for a failed/pending connection.
        let failed = peripheral; peripheral = nil
        reset()
        if let failed { central.cancelPeripheralConnection(failed) }
        scheduleReconnect()
    }
    private func scheduleReconnect() {
        guard scanning else { return }
        reconnect?.invalidate()
        reconnect = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in self?.search() }
    }
    private func armTimeout() {
        timeout?.invalidate()
        timeout = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in self?.fail("MacroPad neodpovídá. Připojení zkusím znovu automaticky. Zapněte pad a ověřte, že není připojený k jinému Macu.") }
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral == self.peripheral else { return }
        peripheral.discoverServices([Self.uuid("1000"), CBUUID(string: "180F")])
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard peripheral == self.peripheral else { return }; fail(error?.localizedDescription ?? "Připojení se nezdařilo.")
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard peripheral == self.peripheral else { return }
        let wasBusy = busy
        let rebooting = firmwareRebootRequested
        let ota = rebootForOTA
        reset(); self.peripheral = nil
        if rebooting {
            if ota { message = "Hledám Bluetooth bootloader…"; firmwareMessage = message; onOTABootloader?(); return }
            message = "Čekám na disk XIAO. Potom klikněte na Nahrát firmware."
            firmwareMessage = message
            return
        }
        message = wasBusy ? "Spojení bylo přerušeno. Výsledek zápisu ověříme novým načtením." : "MacroPad je odpojený."
        scheduleReconnect()
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard peripheral == self.peripheral else { return }
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == Self.uuid("1000") }) else { fail("Zařízení nemá konfigurační službu. Otevřete Nastavení zařízení → Firmware."); return }
        peripheral.discoverCharacteristics(nil, for: service)
        if let battery = peripheral.services?.first(where: { $0.uuid == CBUUID(string: "180F") }) {
            peripheral.discoverCharacteristics([CBUUID(string: "2A19")], for: battery)
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard peripheral == self.peripheral else { return }
        if service.uuid == CBUUID(string: "180F") {
            guard error == nil else { return }
            batteryCharacteristic = service.characteristics?.first { $0.uuid == CBUUID(string: "2A19") }
            if ready { refreshPower() }
            return
        }
        guard service.uuid == Self.uuid("1000") else { return }
        hostsRead = service.characteristics?.first { $0.uuid == Self.uuid("1006") }
        hostsWrite = service.characteristics?.first { $0.uuid == Self.uuid("1007") }
        supportsHosts = hostsRead != nil && hostsWrite != nil
        firmwareCharacteristic = service.characteristics?.first { $0.uuid == Self.uuid("1009") }
        if let firmwareCharacteristic { peripheral.readValue(for: firmwareCharacteristic) }
        if let ota = service.characteristics?.first(where: { $0.uuid == Self.uuid("100a") }) { peripheral.readValue(for: ota) }
        supportsWheel = service.characteristics?.contains { $0.uuid == Self.uuid("1008") } == true
        if let wheel = service.characteristics?.first(where: { $0.uuid == Self.uuid("1008") }) { peripheral.readValue(for: wheel) }
        powerCharacteristic = service.characteristics?.first { $0.uuid == Self.uuid("1005") }
        supportsPower = powerCharacteristic != nil
        config = service.characteristics?.first { $0.uuid == Self.uuid("1002") }
        command = service.characteristics?.first { $0.uuid == Self.uuid("1003") }
        events = service.characteristics?.first { $0.uuid == Self.uuid("1004") }
        guard error == nil, let config, command != nil, events != nil else { fail("Tento firmware nepodporuje konfiguraci. Aktualizaci najdete v Nastavení zařízení → Firmware."); return }
        peripheral.readValue(for: config)
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral == self.peripheral else { return }
        if characteristic.uuid == Self.uuid("1008") {
            if error == nil, let data = characteristic.value, data.count == 1 { wheelVersion = data[0] }
            return
        }
        if characteristic.uuid == Self.uuid("100a") {
            if error == nil, let data = characteristic.value, data.count == 4, data[0] == 1, data[1] == 1 {
                let id = UInt16(data[2]) | UInt16(data[3]) << 8
                if id != 0 && id != 0xffff { otaSoftDevice = id }
            }
            return
        }
        if characteristic.uuid == Self.uuid("1009") {
            guard error == nil, let data = characteristic.value,
                  let version = FirmwareInstaller.decodeDeviceVersion(data) else { return }
            firmwareVersion = version
            supportsFirmwareUpdate = characteristic.properties.contains(.write)
            return
        }
        if characteristic.uuid == Self.uuid("1006") {
            guard error == nil, let data = characteristic.value, let snapshot = HostProfiles.decode(data) else {
                hostMessage = "Seznam zařízení se nepodařilo načíst. Zkuste obnovit spojení."; return
            }
            if let previous = hosts,
               previous.active != snapshot.active || previous.usbOutput != snapshot.usbOutput {
                ActionWheel.shared.cancel()
            }
            hosts = snapshot
            if hostBusy, hostAcknowledged, let sequence = hostStartSequence, snapshot.sequence != sequence, !snapshot.pending {
                hostBusy = false; hostTimeout?.invalidate(); hostStartSequence = nil
                hostMessage = snapshot.failed ? "Změna se nepodařila. Obnovte seznam a zkuste to znovu." : "Změna potvrzena MacroPadem."
            }
            return
        }
        if characteristic.uuid == Self.uuid("1005") || characteristic.uuid == CBUUID(string: "2A19") {
            powerPending = false
            guard error == nil, let data = characteristic.value else { return }
            let sample: PowerStatus?
            if characteristic.uuid == Self.uuid("1005") { sample = PowerStatus.decode(data) }
            else { sample = data.count == 1 && data[0] <= 100 ? PowerStatus(percent: Int(data[0])) : nil }
            if let sample { power = sample; powerHistory.append(sample) }
            return
        }
        if characteristic.uuid == Self.uuid("1002"), configReadPending {
            configReadPending = false
            if let pending = pendingSave {
                pendingSave = nil; busy = false
                guard error == nil else { fail("Aktuální konfiguraci se nepodařilo načíst. Návrh zůstal zachovaný."); return }
                save(pending.project, basedOn: pending.baseline); return
            }
            // A foreground operation may have started while this passive read was in flight.
            if busy || learning || hostBusy { return }
        }
        guard error == nil, let data = characteristic.value else { fail(error?.localizedDescription ?? "Čtení selhalo."); return }
        if characteristic.uuid == Self.uuid("1004") {
            let bytes = [UInt8](data); guard bytes.count == 4 else { fail("Neplatná odpověď snímače."); return }
            let next = UInt16(bytes[0]) | UInt16(bytes[1]) << 8
            let lost = (sequence.map { $0 &+ 1 != next } ?? false) || (lastSampleAt.map { Date().timeIntervalSince($0) > 2 } ?? false)
            sequence = next
            lastSampleAt = Date()
            receivingSamples = true; sampleTimeout?.invalidate()
            onSample?(UInt16(bytes[2]) | UInt16(bytes[3]) << 8, lost)
            return
        }
        guard characteristic.uuid == Self.uuid("1002") else { return }
        configReadPending = false
        if validatingBase {
            validatingBase = false
            guard data == saveBase else {
                fail("Konfiguraci mezitím změnilo jiné zařízení. Návrh zůstal zachovaný; po načtení zahoďte změny a upravte aktuální konfiguraci.")
                return
            }
            saveBase = nil; sendNext(); return
        }
        if !busy, expected == nil, data == lastLoadedData { return }
        do {
            let loaded = try HardwareProject.decode(data)
            if let expected, expected != data { throw BLEProtocol.Failure(message: "Ověření zápisu nesouhlasí; načtěte konfiguraci znovu.") }
            if let events, !events.isNotifying { peripheral.setNotifyValue(true, for: events) }
            ActionWheel.shared.configure(device: wheelDeviceKey, controls: loaded.controls, pad: self)
            lastLoadedData = data
            project = loaded; ready = true; busy = false; timeout?.invalidate()
            central.stopScan()
            message = expected == nil ? "MacroPad rozpoznán · \(loaded.controls.count) prvků načteno ze zařízení" : "Hotovo. Konfigurace je uložená a ověřená v MacroPadu."
            expected = nil
            UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: "learnedPad")
            onLoaded?(loaded)
            if hostTimer == nil {
                refreshHosts()
                hostTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.refreshHosts(); self?.refreshConfiguration() }
            }
            if powerTimer == nil {
                refreshPower()
                powerTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.refreshPower() }
            }
        } catch { fail(error.localizedDescription) }
    }
    func enterFirmwareBootloader(ota: Bool = false) {
        guard ready, !busy, !learning, !hostBusy, supportsFirmwareUpdate,
              let peripheral, let firmwareCharacteristic else { return }
        guard !ota || otaSoftDevice != nil else { return }
        rebootForOTA = ota
        ActionWheel.shared.cancel()
        firmwareRebootRequested = true; busy = true; scanning = false
        reconnect?.invalidate(); central.stopScan()
        firmwareMessage = "Přepínám MacroPad do nahrávacího režimu…"
        firmwareTimeout?.invalidate()
        firmwareTimeout = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.firmwareRebootRequested = false; self.busy = false
            self.scanning = true; self.rebootForOTA = false
            self.firmwareMessage = "Přepnutí se nepotvrdilo. Zkontrolujte USB kabel a připojení; firmware zatím nebyl nahrán."
        }
        peripheral.writeValue(Data([1, ota ? 0xa8 : 0x57]), for: firmwareCharacteristic, type: .withResponse)
    }
    private func refreshConfiguration() {
        guard ready, !busy, !learning, !hostBusy, !writing, !configReadPending,
              let peripheral, let config else { return }
        configReadPending = true
        peripheral.readValue(for: config)
    }
    func refreshHosts() {
        guard ready, !busy, !learning, (!hostBusy || hostAcknowledged), let peripheral, let hostsRead else { return }
        peripheral.readValue(for: hostsRead)
    }
    func manageHost(_ packet: Data) {
        guard ready, !busy, !learning, !hostBusy, let snapshot = hosts, snapshot.fresh, !snapshot.pending,
              let peripheral, let hostsWrite else { return }
        hostBusy = true; hostAcknowledged = false; hostStartSequence = snapshot.sequence
        hostMessage = "Čekám na potvrzení MacroPadu…"
        hostTimeout?.invalidate()
        hostTimeout = Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { [weak self] _ in
            self?.hostBusy = false; self?.hostStartSequence = nil
            self?.hostMessage = "Potvrzení nedorazilo. Ověřte aktuální výběr v seznamu zařízení."
            self?.refreshHosts()
        }
        peripheral.writeValue(packet, for: hostsWrite, type: .withResponse)
    }
    func refreshPower() {
        guard ready, !busy, !learning, !powerPending, let peripheral else { return }
        peripheral.readRSSI()
        if let characteristic = powerCharacteristic ?? batteryCharacteristic {
            powerPending = true
            peripheral.readValue(for: characteristic)
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard peripheral == self.peripheral, error == nil, RSSI.intValue != 127 else { return }
        signal = RSSI.intValue
    }
    func beginLearning() {
        ActionWheel.shared.cancel()
        guard ready, !busy, !hostBusy, let peripheral, let events else { return }
        busy = true; sequence = nil; lastSampleAt = nil; receivingSamples = false
        beginPending = true; armTimeout()
        sampleTimeout?.invalidate()
        sampleTimeout = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in
            self?.fail("Z MacroPadu nepřicházejí vzorky pinů. Ukončete další kopie MacroPad.app a znovu se připojte.")
        }
        if events.isNotifying {
            beginPending = false; packets = [Data([1])]; sendNext()
        } else { peripheral.setNotifyValue(true, for: events) }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral == self.peripheral, characteristic.uuid == Self.uuid("1004") else { return }
        guard error == nil, characteristic.isNotifying else { fail("Nepodařilo se zapnout měření pinů."); return }
        if beginPending { beginPending = false; packets = [Data([1])]; sendNext() }
    }
    private func sendNext() {
        guard !writing, let peripheral, let command, !packets.isEmpty else { return }
        writing = true
        armTimeout(); peripheral.writeValue(packets.removeFirst(), for: command, type: .withResponse)
    }
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral == self.peripheral else { return }
        if characteristic.uuid == Self.uuid("1009") {
            guard firmwareRebootRequested else { return }
            if let error {
                firmwareTimeout?.invalidate(); firmwareRebootRequested = false; busy = false
                scanning = true; rebootForOTA = false
                firmwareMessage = "Přepnutí selhalo. Připojte datový USB kabel a ukončete učení nebo párování. \(error.localizedDescription)"
            } else { firmwareMessage = rebootForOTA ? "Příkaz přijat. Čekám na Bluetooth bootloader…" : "Příkaz přijat. Čekám na disk XIAO…" }
            return
        }
        if characteristic.uuid == Self.uuid("1007") {
            if let error {
                hostBusy = false; hostTimeout?.invalidate(); hostStartSequence = nil; hostMessage = "Změna selhala: \(error.localizedDescription)"
            } else { hostAcknowledged = true; refreshHosts() }
            return
        }
        guard characteristic.uuid == Self.uuid("1003") else { return }
        writing = false
        guard error == nil else {
            let att = error! as NSError
            if att.domain == CBATTErrorDomain && att.code == CBATTError.insufficientAuthorization.rawValue {
                fail("Konfiguraci právě upravuje jiné zařízení. Po dokončení, odpojení nebo vypršení 15sekundového zámku zkuste uložení znovu.")
            } else { fail("Zápis selhal: \(error!.localizedDescription)") }
            return
        }
        timeout?.invalidate()
        if saveBase != nil, let config {
            validatingBase = true; armTimeout(); peripheral.readValue(for: config); return
        }
        if !packets.isEmpty { sendNext(); return }
        if endingLearning {
            endingLearning = false; learning = false; busy = false
            message = "MacroPad je připravený · běžné akce jsou zapnuté"
        } else if expected != nil {
            learning = false; heartbeat?.invalidate()
            if let config { armTimeout(); peripheral.readValue(for: config) }
        } else if busy {
            busy = false; learning = true; message = "Režim učení · běžné akce jsou vypnuté"
            heartbeat?.invalidate()
            heartbeat = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
                guard let self, self.learning, !self.busy else { return }
                self.packets = [Data([1])]; self.sendNext()
            }
        }
    }
    func endLearning() {
        guard ready, learning, !busy else { return }
        heartbeat?.invalidate(); sampleTimeout?.invalidate()
        endingLearning = true; busy = true; packets = [Data([2])]; sendNext()
    }
    func cancelLearning() {
        heartbeat?.invalidate(); sampleTimeout?.invalidate(); receivingSamples = false; learning = false
        // Disconnect also cancels the firmware lease immediately, without saving the draft.
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
    }
    static func uploadPackets(_ data: Data) -> [Data] {
        var packets = [Data([1]), Data([3])]
        for offset in stride(from: 0, to: data.count, by: 17) {
            packets.append(Data([4, UInt8(offset & 255), UInt8(offset >> 8)]) + data.subdata(in: offset..<min(offset+17,data.count)))
        }
        packets.append(Data([5]))
        return packets
    }
    func save(_ project: HardwareProject, basedOn baseline: Data? = nil) {
        if project.controls.contains(where: { !WheelCapabilities.supports(mode: $0.holdMode, kind: $0.kind, version: wheelVersion) }) {
            message = "Podržení vyžaduje nový firmware. Aktualizujte ho v nastavení zařízení."; return
        }
        ActionWheel.shared.cancel()
        guard ready, !busy, !hostBusy else { return }
        if configReadPending {
            pendingSave = (project, baseline); busy = true; armTimeout()
            message = "Dokončuji načtení a pak uložím změny…"; return
        }
        do {
            let data = try project.encode(); saveBase = baseline ?? lastLoadedData; expected = data; busy = true; heartbeat?.invalidate()
            // Acquire/renew the lease as part of this transaction, including after reconnect.
            packets = Self.uploadPackets(data)
            message = "Ukládám konfiguraci do MacroPadu…"; sendNext()
        } catch { message = error.localizedDescription }
    }
}
