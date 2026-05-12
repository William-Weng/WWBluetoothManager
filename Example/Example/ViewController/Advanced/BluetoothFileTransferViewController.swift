//
//  FileTransferViewController.swift
//  Example
//
//  Created by WilliamWeng on 2026/5/6.
//

import UIKit
import CoreBluetooth
import WWPrint
import WWBluetoothManager

final class FileTransferViewController: UIViewController {
    
    @IBOutlet weak var logTextView: LogTextView!
    
    private let targetLocalName = "WWFileTransfer"
    private let central = WWBluetoothManager.Central()
    private let fileTransfer = WWBluetoothManager.FileTransferController()
    
    private var targetPeripheral: CBPeripheral?
    private var controlCharacteristic: CBCharacteristic?
    private var dataCharacteristic: CBCharacteristic?
    
    private var isReceivePrepared = false
    private var pendingSendData: Data?
    
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
        
        guard let data = text.data(using: .utf8) else {
            logTextView.appendLog("建立測試檔案失敗")
            return
        }
        
        sendFile(data: data)
    }
}

// MARK: - WWBluetoothManager.CentralDelegate
extension FileTransferViewController: WWBluetoothManager.CentralDelegate {
    
    func centralManager(_ central: WWBluetoothManager.Central, status: WWBluetoothManager.CentralStatus) {
        
        switch status {
        case .stateUpdated(let state):
            handleCentralStateUpdated(state)
        case .discovered(let result):
            handleDiscovered(result)
        case .connected(let peripheral):
            handleConnected(peripheral)
        case .disconnected(let peripheral, let error):
            handleDisconnected(peripheral, error: error)
        case .failedToConnect(let peripheral, let error):
            handleFailedToConnect(peripheral, error: error)
        }
    }
    
    func centralManager(_ central: WWBluetoothManager.Central, peripheral: CBPeripheral, status: WWBluetoothManager.PeripheralStatus) {
        
        switch status {
        case .discoveredServices(let services):
            handleDiscoveredServices(peripheral, services: services)
        case .discoveredCharacteristics(let service, let characteristics):
            handleDiscoveredCharacteristics(peripheral, service: service, characteristics: characteristics)
        case .notificationStateUpdated(let characteristic, let error):
            handleNotificationStateUpdated(peripheral, characteristic: characteristic, error: error)
        case .characteristicDiscoveryFailed(let service, let error):
            handleCharacteristicDiscoveryFailed(peripheral, service: service, error: error)
        case .characteristicValueUpdated(let characteristic, let data, let error):
            handleCharacteristicValueUpdated(peripheral, characteristic: characteristic, data: data, error: error)
        case .characteristicWriteCompleted(let characteristic, let error):
            handleCharacteristicWriteCompleted(peripheral, characteristic: characteristic, error: error)
        case .serviceDiscoveryFailed(let error):
            handleServiceDiscoveryFailed(peripheral, error: error)
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
        logTextView.appendLog("Connected => \(peripheral.name ?? "Unknown")")
    }
    
    func handleDisconnected(_ peripheral: CBPeripheral, error: Error?) {
        
        logTextView.appendLog("Disconnected => \(peripheral.name ?? "Unknown"), error => \(String(describing: error))")
        
        targetPeripheral = nil
        controlCharacteristic = nil
        dataCharacteristic = nil
        isReceivePrepared = false
        pendingSendData = nil
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
            
            guard let uuidType = WWBluetoothManager.UUIDType(rawValue: characteristic.uuid.uuidString) else { return }
            
            switch uuidType {
            case .control:
                controlCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                logTextView.appendLog("Control characteristic ready => \(characteristic.uuid.uuidString)")
                
            case .data:
                dataCharacteristic = characteristic
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
            logTextView.appendLog("Notify hex => \(data.hexString())")
            logTextView.appendLog("Notify utf8 => \(data.string() ?? "<non-utf8>")")
        } else {
            logTextView.appendLog("Notify data => nil")
        }
        
        let status = WWBluetoothManager.PeripheralStatus.characteristicValueUpdated(
            characteristic: characteristic,
            data: data,
            error: error
        )
        
        fileTransfer.handle(peripheral: peripheral, status: status)
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
        prepareReceiveIfNeeded(with: peripheral, controlCharacteristic: controlCharacteristic, dataCharacteristic: dataCharacteristic)
    }
    
    func prepareReceiveIfNeeded(with peripheral: CBPeripheral, controlCharacteristic: CBCharacteristic, dataCharacteristic: CBCharacteristic) {
        
        guard !isReceivePrepared else {
            logTextView.appendLog("Receive mode already prepared.")
            return
        }
        
        isReceivePrepared = true
        
        fileTransfer.receiveFile(
            using: peripheral,
            controlCharacteristic: controlCharacteristic,
            dataCharacteristic: dataCharacteristic
        ) { [weak self] data in
            
            guard let self else { return }
            
            self.logTextView.appendLog("Receive completed => \(data.count) bytes")
            
            let fileName = "received-\(Int(Date().timeIntervalSince1970)).bin"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            do {
                try data.write(to: url)
                self.logTextView.appendLog("Saved file => \(url.path)")
            } catch {
                self.logTextView.appendLog("Save file failed => \(error.localizedDescription)")
            }
        }
        
        logTextView.appendLog("Receive mode prepared.")
    }
    
    func sendFile(url: URL) {
        
        do {
            let data = try Data(contentsOf: url)
            logTextView.appendLog("Load file => \(url.lastPathComponent), \(data.count) bytes")
            sendFile(data: data)
        } catch {
            logTextView.appendLog("Load file failed => \(error.localizedDescription)")
        }
    }
    
    func sendFile(data: Data) {
        
        guard let peripheral = targetPeripheral else {
            logTextView.appendLog("No connected peripheral, save as pending.")
            pendingSendData = data
            return
        }
        
        guard let controlCharacteristic else {
            logTextView.appendLog("No control characteristic, save as pending.")
            pendingSendData = data
            return
        }
        
        guard let dataCharacteristic else {
            logTextView.appendLog("No data characteristic, save as pending.")
            pendingSendData = data
            return
        }
        
        pendingSendData = nil
        
        fileTransfer.sendFile(
            using: peripheral,
            data: data,
            controlCharacteristic: controlCharacteristic,
            dataCharacteristic: dataCharacteristic
        )
        
        logTextView.appendLog("Start send file => \(data.count) bytes")
        logTextView.appendLog("Phase => \(fileTransfer.phase)")
        logTextView.appendLog("Chunk size => \(fileTransfer.chunkSize), total chunks => \(fileTransfer.totalChunks)")
    }
    
    func flushPendingSendIfNeeded() {
        guard let pendingSendData else { return }
        sendFile(data: pendingSendData)
    }
}

// MARK: - Tool
private extension FileTransferViewController {
    
    func bindBluetooth() {
        logTextView.configure()
        logTextView.appendLog("bindBluetooth()")
        central.delegate = self
    }
}

