import Foundation
import CoreBluetooth

/// Owns the v2 connection. Only acknowledged, read-back-verified configurations are accepted.
final class LearningPad: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static func uuid(_ suffix: String) -> CBUUID { CBUUID(string: "9a7b\(suffix)-6e57-4b21-9c35-91ae24f3d801") }
    @Published var devices: [CBPeripheral] = []
    @Published var ready = false
    @Published var busy = false
    @Published var message = "Připojte MacroPad s univerzálním firmwarem."
    @Published var project = HardwareProject()
    @Published var learning = false
    @Published var receivingSamples = false
    @Published var hosts: HostProfiles?
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
    private var config: CBCharacteristic?, command: CBCharacteristic?, events: CBCharacteristic?
    private var packets: [Data] = []
    private var expected: Data?
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
        scanning = true
        if central == nil { central = CBCentralManager(delegate: self, queue: .main) }
        else { search() }
    }
    private func search() {
        guard central.state == .poweredOn else { return }
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
        if central.state == .poweredOn && scanning { search() }
        else if central.state != .poweredOn { message = "Zapněte Bluetooth a povolte aplikaci přístup v Nastavení systému."; reset() }
    }
    private func found(_ device: CBPeripheral) {
        guard device.name?.localizedCaseInsensitiveContains("macropad") == true else { return }
        if !devices.contains(where: { $0.identifier == device.identifier }) { devices.append(device) }
        if peripheral == nil, UserDefaults.standard.string(forKey: "learnedPad") == device.identifier.uuidString { connect(device) }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) { found(peripheral) }
    func connect(_ device: CBPeripheral) {
        guard !busy else { return }
        if let old = peripheral, old != device { central.cancelPeripheralConnection(old) }
        reset(); peripheral = device; device.delegate = self; busy = true
        message = "Připojuji a čtu konfiguraci…"; central.connect(device); armTimeout()
    }
    func disconnect() {
        scanning = false; reconnect?.invalidate(); central?.stopScan()
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
        peripheral = nil; reset()
    }
    private func reset() {
        hostTimer?.invalidate(); hostTimeout?.invalidate(); hostTimer = nil
        hostsRead = nil; hostsWrite = nil; hosts = nil; supportsHosts = false; hostBusy = false; hostStartSequence = nil; hostMessage = ""
        powerTimer?.invalidate(); powerTimer = nil; powerPending = false
        powerCharacteristic = nil; batteryCharacteristic = nil; supportsPower = false
        power = nil; powerHistory = PowerHistory(); signal = nil
        ready = false; busy = false; learning = false; beginPending = false; endingLearning = false; writing = false; packets = []; expected = nil
        config = nil; command = nil; events = nil; sequence = nil
        timeout?.invalidate(); heartbeat?.invalidate(); sampleTimeout?.invalidate(); lastSampleAt = nil; receivingSamples = false
    }
    private func fail(_ text: String) {
        message = text
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
        reset()
    }
    private func armTimeout() {
        timeout?.invalidate()
        timeout = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in self?.fail("Zařízení neodpovědělo. Znovu se připojte; nedokončené změny se neuložily.") }
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
        reset(); self.peripheral = nil
        message = wasBusy ? "Spojení bylo přerušeno. Výsledek zápisu ověříme novým načtením." : "MacroPad je odpojený."
        if scanning {
            reconnect?.invalidate()
            reconnect = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in self?.search() }
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard peripheral == self.peripheral else { return }
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == Self.uuid("1000") }) else { fail("Nahrajte univerzální firmware v prvním kroku průvodce."); return }
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
        powerCharacteristic = service.characteristics?.first { $0.uuid == Self.uuid("1005") }
        supportsPower = powerCharacteristic != nil
        config = service.characteristics?.first { $0.uuid == Self.uuid("1002") }
        command = service.characteristics?.first { $0.uuid == Self.uuid("1003") }
        events = service.characteristics?.first { $0.uuid == Self.uuid("1004") }
        guard error == nil, let config, command != nil, events != nil else { fail("Tento firmware nemá průvodce učením. Nejdřív nahrajte univerzální firmware."); return }
        peripheral.readValue(for: config)
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral == self.peripheral else { return }
        if characteristic.uuid == Self.uuid("1006") {
            guard error == nil, let data = characteristic.value, let snapshot = HostProfiles.decode(data) else {
                hostMessage = "Seznam zařízení se nepodařilo načíst. Zkuste obnovit spojení."; return
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
        do {
            let loaded = try HardwareProject.decode(data)
            if let expected, expected != data { throw BLEProtocol.Failure(message: "Ověření zápisu nesouhlasí; načtěte konfiguraci znovu.") }
            if let events, !events.isNotifying { peripheral.setNotifyValue(true, for: events) }
            project = loaded; ready = true; busy = false; timeout?.invalidate()
            central.stopScan()
            message = expected == nil ? "MacroPad rozpoznán · \(loaded.controls.count) prvků načteno ze zařízení" : "Hotovo. Konfigurace je uložená a ověřená v MacroPadu."
            expected = nil
            UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: "learnedPad")
            onLoaded?(loaded)
            if hostTimer == nil {
                refreshHosts()
                hostTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.refreshHosts() }
            }
            if powerTimer == nil {
                refreshPower()
                powerTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.refreshPower() }
            }
        } catch { fail(error.localizedDescription) }
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
        if characteristic.uuid == Self.uuid("1007") {
            if let error {
                hostBusy = false; hostTimeout?.invalidate(); hostStartSequence = nil; hostMessage = "Změna selhala: \(error.localizedDescription)"
            } else { hostAcknowledged = true; refreshHosts() }
            return
        }
        writing = false
        guard error == nil else { fail("Zápis selhal: \(error!.localizedDescription)"); return }
        timeout?.invalidate()
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
    func save(_ project: HardwareProject) {
        guard ready, !busy, !hostBusy else { return }
        do {
            let data = try project.encode(); expected = data; busy = true; heartbeat?.invalidate()
            // Acquire/renew the lease as part of this transaction, including after reconnect.
            packets = Self.uploadPackets(data)
            message = "Ukládám konfiguraci do MacroPadu…"; sendNext()
        } catch { message = error.localizedDescription }
    }
}
