//
//  FileTransferViewController.swift
//  Example
//
//  Created by WilliamWeng on 2026/5/6.
//

import UIKit
import CoreBluetooth
import UniformTypeIdentifiers
import WWPrint
import WWBluetoothManager

final class FileTransferViewController: UIViewController {
    
    @IBOutlet weak var logTextView: LogTextView!
    @IBOutlet weak var previewImageView: UIImageView!
    
    private let targetLocalName = "🤣🤣🤣🤣"
    private let central = WWBluetoothManager.Central()
    private let fileTransfer = WWBluetoothManager.FileTransferController()
    
    private var targetPeripheral: CBPeripheral?
    private var controlCharacteristic: CBCharacteristic?
    private var dataCharacteristic: CBCharacteristic?
    
    private var isReceivePrepared = false
    private var pendingSendFileData: Data?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bindBluetooth()
    }
    
    @IBAction func prepareReceiveAction(_ sender: UIBarButtonItem) {
        prepareReceiveMode()
    }
    
    @IBAction func sendDemoFileAction(_ sender: UIBarButtonItem) {
        
        let text = """
        Hello BLE File Transfer
        Time: \(Date())
        """
        
        guard let rawData = text.data(using: .utf8) else {
            logTextView.appendLog("建立測試文字失敗")
            return
        }
        
        let file = TransferFile(
            fileName: "demo-\(Int(Date().timeIntervalSince1970)).txt",
            typeIdentifier: UTType.plainText.identifier,
            data: rawData
        )
        
        sendTransferFile(file)
    }
    
    @IBAction func sendDemoImageAction(_ sender: UIBarButtonItem) {
        
        let image: UIImage = .chiikawa
        
        guard let rawData = image.pngData() else {
            logTextView.appendLog("建立測試圖片失敗")
            return
        }
        
        let file = TransferFile(
            fileName: "chiikawa-\(Int(Date().timeIntervalSince1970)).png",
            typeIdentifier: UTType.png.identifier,
            data: rawData
        )
        
        sendTransferFile(file)
    }
    
    @IBAction func cleanLogText(_ sender: UIBarButtonItem) {
        logTextView.text =  ""
    }
}

// MARK: - WWBluetoothManager.CentralDelegate
extension FileTransferViewController: WWBluetoothManager.CentralDelegate {
    
    func centralManager(_ central: WWBluetoothManager.Central, status: WWBluetoothManager.CentralStatus) {
        
        switch status {
        case .stateUpdated(let state): handleCentralStateUpdated(state)
        case .discovered(let result): handleDiscovered(result)
        case .connected(let peripheral): handleConnected(peripheral)
        case .disconnected(let peripheral, let error): handleDisconnected(peripheral, error: error)
        case .failedToConnect(let peripheral, let error): handleFailedToConnect(peripheral, error: error)
        }
    }
    
    func centralManager(_ central: WWBluetoothManager.Central, peripheral: CBPeripheral, status: WWBluetoothManager.PeripheralStatus) {
        
        switch status {
        case .discoveredServices(let services): handleDiscoveredServices(peripheral, services: services)
        case .discoveredCharacteristics(let service, let characteristics): handleDiscoveredCharacteristics(peripheral, service: service, characteristics: characteristics)
        case .notificationStateUpdated(let characteristic, let error): handleNotificationStateUpdated(peripheral, characteristic: characteristic, error: error)
        case .characteristicDiscoveryFailed(let service, let error): handleCharacteristicDiscoveryFailed(peripheral, service: service, error: error)
        case .characteristicValueUpdated(let characteristic, let data, let error): handleCharacteristicValueUpdated(peripheral, characteristic: characteristic, data: data, error: error)
        case .characteristicWriteCompleted(let characteristic, let error): handleCharacteristicWriteCompleted(peripheral, characteristic: characteristic, error: error)
        case .serviceDiscoveryFailed(let error): handleServiceDiscoveryFailed(peripheral, error: error)
        }
    }
}

// MARK: - Central event
private extension FileTransferViewController {
    
    func handleCentralStateUpdated(_ state: CBManagerState) {
        
        logTextView.appendLog("Bluetooth state => \(state.rawValue)")
        
        guard state == .poweredOn else { return }
        central.startScan()
        logTextView.appendLog("Start scanning...")
    }
    
    func handleDiscovered(_ result: WWBluetoothManager.Central.ScanResult) {
        
        guard let displayName = result.displayName else { return }
        logTextView.appendLog("設備 displayName => \(displayName)")
        logTextView.appendLog("設備 localName => \(result.localName ?? "Unknown")")
        
        guard displayName == targetLocalName else { return }
        
        logTextView.appendLog("找到目標設備 => \(result.jsonString())")
        central.stopScan()
        central.connect(result.peripheral)
    }
    
    func handleConnected(_ peripheral: CBPeripheral) {
        targetPeripheral = peripheral
        controlCharacteristic = nil
        dataCharacteristic = nil
        isReceivePrepared = false
        pendingSendFileData = nil
        logTextView.appendLog("Connected => \(peripheral.name ?? "Unknown")")
    }
    
    func handleDisconnected(_ peripheral: CBPeripheral, error: Error?) {
        
        logTextView.appendLog("Disconnected => \(peripheral.name ?? "Unknown"), error => \(String(describing: error))")
        
        targetPeripheral = nil
        controlCharacteristic = nil
        dataCharacteristic = nil
        isReceivePrepared = false
        pendingSendFileData = nil
    }
    
    func handleFailedToConnect(_ peripheral: CBPeripheral, error: Error?) {
        logTextView.appendLog("Failed to connect => \(peripheral.name ?? "Unknown"), error => \(String(describing: error))")
    }
}

// MARK: - Peripheral event
private extension FileTransferViewController {
    
    func handleDiscoveredServices(_ peripheral: CBPeripheral, services: [CBService]) {
        
        logTextView.appendLog("Services of \(peripheral.name ?? "Unknown"): (\(services.count) 個)")
        services.forEach { logTextView.appendLog("Service => \($0.uuid.uuidString)") }
    }
    
    func handleDiscoveredCharacteristics(_ peripheral: CBPeripheral, service: CBService, characteristics: [CBCharacteristic]) {
        
        logTextView.appendLog("Characteristics of \(service.uuid.uuidString): (\(characteristics.count) 個)")
        
        characteristics.forEach { characteristic in
            
            logTextView.appendLog("Characteristic => \(characteristic.uuid.uuidString), properties => \(characteristic.properties.rawValue)")
                        
            guard let uuidType = WWBluetoothManager.UUIDType.find(uuid: characteristic.uuid) else { return }

            switch uuidType {
            case .control:
                controlCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                logTextView.appendLog("Control characteristic ready => \(characteristic.uuid.uuidString)")
                
            case .data:
                dataCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                logTextView.appendLog("Data characteristic ready => \(characteristic.uuid.uuidString)")
                
            default:
                break
            }
        }
        
        flushPendingSendIfNeeded()
    }
    
    func handleNotificationStateUpdated(_ peripheral: CBPeripheral, characteristic: CBCharacteristic, error: Error?) {
        logTextView.appendLog("Notification state updated => \(characteristic.uuid.uuidString), isNotifying => \(characteristic.isNotifying), error => \(String(describing: error))")
    }
    
    func handleCharacteristicDiscoveryFailed(_ peripheral: CBPeripheral, service: CBService, error: Error?) {
        logTextView.appendLog("Characteristic discovery failed => \(service.uuid.uuidString), error => \(String(describing: error))")
    }
    
    func handleCharacteristicValueUpdated(_ peripheral: CBPeripheral, characteristic: CBCharacteristic, data: Data?, error: Error?) {
        
        logTextView.appendLog("Value updated => \(characteristic.uuid.uuidString), error => \(String(describing: error))")
        
        if let data {
            let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
            logTextView.appendLog("Value bytes => \(data.count)")
            logTextView.appendLog("Value hex => \(hexString)")
        } else {
            logTextView.appendLog("Value data => nil")
        }
        
        let status = WWBluetoothManager.PeripheralStatus.characteristicValueUpdated(
            characteristic: characteristic,
            data: data,
            error: error
        )
        
        fileTransfer.handle(peripheral: peripheral, status: status)
        logTextView.appendLog("Phase after handle => \(fileTransfer.phase)")
    }
    
    func handleCharacteristicWriteCompleted(_ peripheral: CBPeripheral, characteristic: CBCharacteristic, error: Error?) {
        
        logTextView.appendLog("Write completed => \(characteristic.uuid.uuidString), error => \(String(describing: error))")
        
        let status = WWBluetoothManager.PeripheralStatus.characteristicWriteCompleted(
            characteristic: characteristic,
            error: error
        )
        
        fileTransfer.handle(peripheral: peripheral, status: status)
    }
    
    func handleServiceDiscoveryFailed(_ peripheral: CBPeripheral, error: Error?) {
        logTextView.appendLog("Service discovery failed => \(peripheral.name ?? "Unknown"), error => \(String(describing: error))")
    }
}

// MARK: - File transfer
private extension FileTransferViewController {
    
    func prepareReceiveMode() {
        
        guard let peripheral = targetPeripheral else {
            logTextView.appendLog("No connected peripheral.")
            return
        }
        
        guard let controlCharacteristic else {
            logTextView.appendLog("No control characteristic.")
            return
        }
        
        guard let dataCharacteristic else {
            logTextView.appendLog("No data characteristic.")
            return
        }
        
        isReceivePrepared = false
        
        fileTransfer.receiveFile(using: peripheral, controlCharacteristic: controlCharacteristic, dataCharacteristic: dataCharacteristic) { [weak self] container in
            
            guard let self else { return }
            
            self.logTextView.appendLog("Receive completed => \(container.count) bytes")
            
            do {
                let file = try TransferFile.decode(from: container)
                self.handleReceivedTransferFile(file)
            } catch {
                self.logTextView.appendLog("Decode transfer file failed => \(error.localizedDescription)")
                
                let fileName = "received-\(Int(Date().timeIntervalSince1970)).bin"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                
                do {
                    try container.write(to: url)
                    self.logTextView.appendLog("Saved raw file => \(url.path)")
                } catch {
                    self.logTextView.appendLog("Save raw file failed => \(error.localizedDescription)")
                }
            }
        }
        
        isReceivePrepared = true
        logTextView.appendLog("Receive mode prepared.")
    }
    
    func sendTransferFile(_ file: TransferFile) {
        
        do {
            let packagedData = try file.encoded()
            sendRawFile(data: packagedData)
            logTextView.appendLog("Prepare send => \(file.normalizedFileName), type => \(file.typeIdentifier), payload => \(file.data.count) bytes")
        } catch {
            logTextView.appendLog("Encode transfer file failed => \(error.localizedDescription)")
        }
    }
    
    func sendRawFile(data: Data) {
        
        guard let peripheral = targetPeripheral else {
            logTextView.appendLog("No connected peripheral, save as pending.")
            pendingSendFileData = data
            return
        }
        
        guard let controlCharacteristic else {
            logTextView.appendLog("No control characteristic, save as pending.")
            pendingSendFileData = data
            return
        }
        
        guard let dataCharacteristic else {
            logTextView.appendLog("No data characteristic, save as pending.")
            pendingSendFileData = data
            return
        }
        
        pendingSendFileData = nil
        
        fileTransfer.sendFile(
            using: peripheral,
            fileName: "demo.png",
            typeIdentifier: "public.png",
            data: data,
            controlCharacteristic: controlCharacteristic,
            dataCharacteristic: dataCharacteristic
        )
        
        logTextView.appendLog("Start send file => \(data.count) bytes")
        logTextView.appendLog("Phase => \(fileTransfer.phase)")
        logTextView.appendLog("Chunk size => \(fileTransfer.chunkSize), total chunks => \(fileTransfer.totalChunks)")
    }
    
    func handleReceivedTransferFile(_ file: TransferFile) {
        
        let fileName = file.normalizedFileName
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try file.data.write(to: url)
            logTextView.appendLog("Saved file => \(url.path)")
            logTextView.appendLog("Type => \(file.typeIdentifier)")
        } catch {
            logTextView.appendLog("Save file failed => \(error.localizedDescription)")
            return
        }
        
        if file.isImage, let image = UIImage(data: file.data) {
            previewImageView.image = image
            logTextView.appendLog("Image preview updated => \(image.size)")
        } else {
            previewImageView.image = nil
            logTextView.appendLog("Received file is not image.")
        }
    }
    
    func flushPendingSendIfNeeded() {
        guard let pendingSendFileData else { return }
        sendRawFile(data: pendingSendFileData)
    }
}

// MARK: - Tool
private extension FileTransferViewController {
    
    func bindBluetooth() {
        logTextView.configure()
        previewImageView.contentMode = .scaleAspectFit
        previewImageView.image = nil
        logTextView.appendLog("bindBluetooth()")
        central.delegate = self
    }
}
