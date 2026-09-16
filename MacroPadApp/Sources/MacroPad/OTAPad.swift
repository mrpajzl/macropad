import Foundation
import CoreBluetooth
import NordicDFU

/// Separate transport for the temporary, unbonded Nordic bootloader identity.
/// The user selects a DFU target; its Device Information is checked before any write.
final class OTAPad: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate, DFUServiceDelegate, DFUProgressDelegate {
    static let service = CBUUID(string: "00001530-1212-EFDE-1523-785FEABCD123")
    @Published private(set) var devices: [CBPeripheral] = []
    @Published private(set) var searching = false
    @Published private(set) var transferring = false
    @Published private(set) var progress = 0
    @Published private(set) var message = ""
    var onCompleted: (() -> Void)?
    private var central: CBCentralManager?
    private var target: CBPeripheral?
    private var image: OTAFirmware.Image?
    private var manufacturer: String?, model: String?
    private var handoff = false
    private var timeout: Timer?
    private var initiator: DFUServiceInitiator?
    private var controller: DFUServiceController?
    private var transferActivity: NSObjectProtocol?

    func search(softDevice: UInt16) {
        guard !transferring else { return }
        stopSearch()
        do { image = try OTAFirmware.image(uf2: FirmwareInstaller.validatedImage(), softDevice: softDevice) }
        catch { message = error.localizedDescription; return }
        devices = []; searching = true; progress = 0
        message = "Hledám nahrávací režim Bluetooth. Vyberte svůj XIAO v seznamu."
        if central == nil { central = CBCentralManager(delegate: self, queue: .main) }
        else { beginScan() }
    }
    private func beginScan() {
        guard searching, let central, central.state == .poweredOn else { return }
        central.scanForPeripherals(withServices: [Self.service])
        armTimeout(30) { [weak self] in
            guard let self else { return }
            self.stopSearch()
            self.message = self.devices.isEmpty
                ? "Bluetooth bootloader nebyl nalezen. Starší bootloader může vyžadovat úpravu; USB aktualizace zůstává dostupná."
                : "Vyberte svůj XIAO pro nahrání. Pokud jste ho mezitím restartovali, obnovte hledání."
        }
    }
    func stopSearch() { central?.stopScan(); searching = false; timeout?.invalidate() }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn { beginScan() }
        else if transferring { fail("Bluetooth není dostupné. Pro obnovu použijte USB, pokud se pad nevrátí.") }
        else if central.state != .unknown && central.state != .resetting {
            stopSearch(); message = "Zapněte Bluetooth a povolte přístup aplikaci."
        }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard searching, !devices.contains(where: { $0.identifier == peripheral.identifier }) else { return }
        devices.append(peripheral)
    }
    func install(on peripheral: CBPeripheral) {
        guard !transferring, image != nil, central?.state == .poweredOn,
              devices.contains(where: { $0.identifier == peripheral.identifier }) else { return }
        stopSearch(); transferring = true
        transferActivity = ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "Bluetooth aktualizace firmwaru MacroPadu")
        target = peripheral; manufacturer = nil; model = nil; handoff = false
        message = "Ověřuji, že vybrané zařízení je XIAO…"
        peripheral.delegate = self; central?.connect(peripheral)
        armTimeout(15) { [weak self] in self?.fail("Zařízení nepotvrdilo kompatibilitu s XIAO. Nic nebylo nahráno.") }
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral == target else { return }
        peripheral.discoverServices([CBUUID(string: "180A"), Self.service])
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard peripheral == target else { return }; fail(error?.localizedDescription ?? "Bootloader se nepřipojil.")
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard peripheral == target else { return }
        guard error == nil, peripheral.services?.contains(where: { $0.uuid == Self.service }) == true,
              let info = peripheral.services?.first(where: { $0.uuid == CBUUID(string: "180A") }) else {
            fail("Zařízení nemá podporovaný XIAO DFU bootloader. Nic nebylo nahráno."); return
        }
        peripheral.discoverCharacteristics([CBUUID(string: "2A29"), CBUUID(string: "2A24")], for: info)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard peripheral == target else { return }
        guard error == nil, let characteristics = service.characteristics, characteristics.count == 2 else {
            fail("Chybí identifikace výrobce nebo modelu. Nic nebylo nahráno."); return
        }
        for characteristic in characteristics { peripheral.readValue(for: characteristic) }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral == target else { return }
        guard error == nil, let data = characteristic.value, let value = String(data: data, encoding: .utf8) else {
            fail("Identifikaci bootloaderu se nepodařilo přečíst. Nic nebylo nahráno."); return
        }
        if characteristic.uuid == CBUUID(string: "2A29") { manufacturer = value }
        if characteristic.uuid == CBUUID(string: "2A24") { model = value }
        guard let manufacturer, let model else { return }
        guard Self.isXIAO(manufacturer: manufacturer, model: model) else {
            fail("Vybrané zařízení není XIAO nRF52840. Nic nebylo nahráno."); return
        }
        handoff = true
        central?.cancelPeripheralConnection(peripheral)
    }
    static func isXIAO(manufacturer: String, model: String) -> Bool {
        manufacturer.lowercased().contains("seeed") && model.lowercased().contains("xiao") && model.lowercased().contains("nrf52840")
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard peripheral == target, transferring else { return }
        guard handoff, let image else { fail("Spojení s bootloaderem se přerušilo."); return }
        handoff = false; target = nil; peripheral.delegate = nil
        let service = DFUServiceInitiator(queue: .main)
        service.delegate = self; service.progressDelegate = self
        service.packetReceiptNotificationParameter = 1 // Conservative flow control for stock 0.6.x.
        service.connectionTimeout = 20
        service.forceDfu = true
        initiator = service
        _ = service.with(firmware: DFUFirmware(binFile: image.binary, datFile: image.initPacket, type: .application))
        controller = service.start(targetWithIdentifier: peripheral.identifier)
        guard controller != nil else { fail("Bluetooth DFU se nepodařilo spustit."); return }
        watchTransfer()
    }
    private func armTimeout(_ seconds: TimeInterval, action: @escaping () -> Void) {
        timeout?.invalidate(); timeout = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in action() }
    }
    private func watchTransfer() {
        armTimeout(90) { [weak self] in self?.fail("Přenos se zastavil. Obnovte nahrání; pokud bootloader není vidět, použijte USB a dvojstisk RESETu.") }
    }
    private func endTransferActivity() {
        if let transferActivity { ProcessInfo.processInfo.endActivity(transferActivity) }
        transferActivity = nil
    }
    private func fail(_ text: String) {
        endTransferActivity()
        let controller = self.controller
        transferring = false; handoff = false; timeout?.invalidate()
        if let target { central?.cancelPeripheralConnection(target) }
        target = nil; self.controller = nil; initiator = nil
        _ = controller?.abort()
        message = text
    }
    func dfuStateDidChange(to state: DFUState) {
        guard transferring else { return }
        watchTransfer()
        switch state {
        case .completed:
            endTransferActivity()
            timeout?.invalidate(); transferring = false; controller = nil; initiator = nil; progress = 100
            message = "Firmware přenesen přes Bluetooth. Ověřuji návrat MacroPadu…"; onCompleted?()
        case .aborted: fail("Přenos byl přerušen. Pro obnovení můžete potřebovat USB a dvojstisk RESETu.")
        case .uploading: message = "Nahrávám firmware přes Bluetooth… Nechte MacroPad zapnutý a poblíž Macu."
        case .validating: message = "Bootloader ověřuje přenesený firmware…"
        case .disconnecting: message = "MacroPad se restartuje…"
        default: message = "Připravuji Bluetooth přenos…"
        }
    }
    func dfuError(_ error: DFUError, didOccurWithMessage message: String) {
        guard transferring else { return }
        fail("Bluetooth aktualizace selhala: \(message). Firmware není ověřený; případně obnovte pad přes USB.")
    }
    func dfuProgressDidChange(for part: Int, outOf totalParts: Int, to progress: Int,
                              currentSpeedBytesPerSecond: Double, avgSpeedBytesPerSecond: Double) {
        guard transferring else { return }; self.progress = progress; watchTransfer()
    }
}
