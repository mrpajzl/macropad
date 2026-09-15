import Foundation
import CoreBluetooth
import Combine

final class BLEPad: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let service = CBUUID(string: "9A7B1000-6E57-4B21-9C35-91AE24F3D801")
    static let configID = CBUUID(string: "9A7B1001-6E57-4B21-9C35-91AE24F3D801")
    @Published private(set) var devices: [CBPeripheral] = []
    @Published private(set) var ready = false
    @Published private(set) var searching = false
    @Published private(set) var connecting = false
    @Published private(set) var message = "Připoj MacroPad přes Bluetooth a načti jeho nastavení."
    var onRead: (([UInt8: MacroDef]) -> Void)?
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    private var searchRequested = false
    private var timeout: DispatchWorkItem?
    private var scanTimeout: DispatchWorkItem?
    private var pending: [Data] = []
    private var expected: [UInt8: Data] = [:]
    private var completion: ((Result<Void, Error>) -> Void)?
    @Published private(set) var reading = false

    func search() {
        searchRequested = true
        if central == nil { central = CBCentralManager(delegate: self, queue: .main) }
        else if central.state == .poweredOn { beginSearch() }
        else { centralManagerDidUpdateState(central) }
    }
    private func beginSearch() {
        guard peripheral == nil else { return }
        searchRequested = false
        devices = []; searching = true; message = "Hledám MacroPad…"
        // HID may already be connected by macOS and no longer advertising.
        for p in central.retrieveConnectedPeripherals(withServices: [CBUUID(string: "1812"), Self.service]) {
            add(p)
        }
        // ZMK advertises HID, not our secondary configuration service.
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        scanTimeout?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.central.stopScan(); self.searching = false
            if self.devices.isEmpty { self.message = "MacroPad nenalezen. Probuď ho klávesou a připoj ho v nastavení Bluetooth macOS." }
        }
        scanTimeout = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: item)
    }
    private func add(_ p: CBPeripheral, name: String? = nil) {
        guard (name ?? p.name ?? "").localizedCaseInsensitiveContains("macropad"),
              !devices.contains(where: { $0.identifier == p.identifier }) else { return }
        devices.append(p)
    }
    func connect(_ p: CBPeripheral) {
        guard peripheral == nil else { return }
        central.stopScan(); scanTimeout?.cancel(); searching = false; connecting = true
        peripheral = p; p.delegate = self; message = "Připojuji a načítám nastavení…"
        central.connect(p, options: nil)
        armTimeout()
    }
    func disconnect() {
        if let p = peripheral { central.cancelPeripheralConnection(p) }
        clearConnection("Odpojeno.")
    }
    func read() {
        guard ready, !reading, completion == nil, let p = peripheral, let c = characteristic else { return }
        reading = true; message = "Načítám nastavení…"; p.readValue(for: c); armTimeout()
    }
    func write(_ records: [Data], completion: @escaping (Result<Void, Error>) -> Void) {
        guard ready, !reading, self.completion == nil, let p = peripheral,
              !records.isEmpty, records.allSatisfy({ $0.count == BLEProtocol.recordSize && $0.count <= p.maximumWriteValueLength(for: .withResponse) }) else {
            completion(.failure(BLEProtocol.Failure(message: "Bluetooth není připravené. Počkej na načtení nastavení."))); return
        }
        self.completion = completion
        pending = records
        expected = Dictionary(uniqueKeysWithValues: records.map { ($0[1], $0) })
        message = "Zapisuji nastavení do paměti padu…"
        writeNext()
    }
    private func writeNext() {
        guard let p = peripheral, let c = characteristic else { return }
        armTimeout()
        if let next = pending.first { p.writeValue(next, for: c, type: .withResponse) }
        else { reading = true; p.readValue(for: c) }
    }
    private func finish(_ error: Error? = nil) {
        timeout?.cancel(); timeout = nil; reading = false
        let callback = completion; completion = nil; pending = []; expected = [:]
        if let error { message = error.localizedDescription; callback?(.failure(error)) }
        else { callback?(.success(())) }
    }
    private func clearConnection(_ reason: String) {
        ready = false; connecting = false; characteristic = nil; peripheral?.delegate = nil; peripheral = nil
        finish(BLEProtocol.Failure(message: reason)); message = reason
    }
    private func armTimeout() {
        timeout?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if let p = self.peripheral { self.central.cancelPeripheralConnection(p) }
            self.clearConnection("MacroPad neodpovídá. Připoj ho znovu; část změn již může být uložená.")
        }
        timeout = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: item)
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn { if searchRequested { beginSearch() }; return }
        searching = false
        let reason: String
        switch central.state {
        case .unauthorized: reason = "Povol aplikaci Bluetooth v Nastavení systému → Soukromí a zabezpečení → Bluetooth."
        case .poweredOff: reason = "Zapni Bluetooth na Macu."
        case .unsupported: reason = "Tento Mac nepodporuje Bluetooth LE."
        default: reason = "Bluetooth se připravuje…"
        }
        clearConnection(reason)
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        add(peripheral, name: advertisementData[CBAdvertisementDataLocalNameKey] as? String)
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard self.peripheral === peripheral else { return }
        peripheral.discoverServices([Self.service]); armTimeout()
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard self.peripheral === peripheral else { return }
        clearConnection(error?.localizedDescription ?? "Připojení selhalo.")
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard self.peripheral === peripheral else { return }
        clearConnection("Bluetooth spojení se přerušilo. Připoj pad znovu a načti nastavení.")
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard self.peripheral === peripheral else { return }
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.service }), error == nil else {
            central.cancelPeripheralConnection(peripheral)
            clearConnection("Pad potřebuje nový firmware s bezdrátovým konfigurátorem. Nahraj ho jednou přes USB.")
            return
        }
        peripheral.discoverCharacteristics([Self.configID], for: service)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard self.peripheral === peripheral else { return }
        guard error == nil, let c = service.characteristics?.first(where: { $0.uuid == Self.configID }),
              c.properties.contains(.read), c.properties.contains(.write) else {
            central.cancelPeripheralConnection(peripheral); clearConnection("Firmware nemá podporované konfigurační rozhraní."); return
        }
        characteristic = c; reading = true; peripheral.readValue(for: c); armTimeout()
    }
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard self.peripheral === peripheral else { return }
        guard characteristic.uuid == Self.configID, completion != nil else { return }
        if let error {
            let e = error as NSError
            let reason = e.domain == CBATTErrorDomain && e.code == CBATTError.insufficientAuthorization.rawValue
                ? "Zápis je zamčený. Stiskni současně všechny 3 klávesy a do 60 sekund zopakuj zápis."
                : "Zápis selhal: \(error.localizedDescription). Část změn již může být uložená."
            finish(BLEProtocol.Failure(message: reason)); return
        }
        pending.removeFirst(); writeNext()
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard self.peripheral === peripheral else { return }
        guard characteristic.uuid == Self.configID, reading else { return }
        do {
            if let error { throw error }
            guard let data = characteristic.value else { throw BLEProtocol.Failure(message: "Pad neposlal nastavení.") }
            let macros = try BLEProtocol.decode(data)
            if completion != nil {
                for (slot, record) in expected {
                    let i = BLEProtocol.slotIDs.firstIndex(of: slot)! * BLEProtocol.recordSize
                    guard data.subdata(in: i..<(i + BLEProtocol.recordSize)) == record else {
                        throw BLEProtocol.Failure(message: "Ověření zápisu selhalo. Načti nastavení a zápis zopakuj.")
                    }
                }
                message = "Nastavení uloženo v padu a ověřeno."
            } else {
                onRead?(macros); message = "XIAO připojeno přes Bluetooth. Nastavení načteno."
            }
            ready = true; connecting = false; finish()
        } catch {
            if !ready { central.cancelPeripheralConnection(peripheral); clearConnection(error.localizedDescription) }
            else { finish(error) }
        }
    }
}
