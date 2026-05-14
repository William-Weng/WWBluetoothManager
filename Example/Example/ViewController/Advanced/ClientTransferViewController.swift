//
//  ViewController.swift
//  Example
//
//  Created by William.Weng on 2026/5/14.
//

import UIKit
import CoreBluetooth
import UniformTypeIdentifiers
import WWBluetoothManager

final class ClientTransferViewController: UIViewController {
    
    @IBOutlet weak var logTextView: LogTextView!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var sourceImageView: UIImageView!
    
    private let client = WWBluetoothManager.Client()
    private let clientTransfer = WWBluetoothManager.ClientTransfer()
    
    private var targetLocalName: String { nameTextField.text ?? "" }
    private var connectedDevice: WWBluetoothManager.Device?
    private var connectedPeripheral: CBPeripheral?
    
    private var controlCharacteristic: CBCharacteristic?
    private var dataCharacteristic: CBCharacteristic?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBluetooth()
        bindTransferEvents()
    }
}

// MARK: - IBAction
extension ClientTransferViewController {
    
    @IBAction func sendDemoFileAction(_ sender: UIBarButtonItem) {
        
        let text = """
        Hello BLE File Transfer
        Time: \(Date())
        """
        
        guard let data = text.data(using: .utf8) else {
            logTextView.appendLog("建立測試文字失敗")
            return
        }
        
        sendTransferFile(
            name: "demo-\(Int(Date().timeIntervalSince1970)).txt",
            contentType: .plainText,
            data: data
        )
    }
    
    @IBAction func sendDemoImageAction(_ sender: UIBarButtonItem) {
        
        let image: UIImage = sourceImageView.image ?? .chiikawa
        
        guard let data = image.pngData() else {
            logTextView.appendLog("建立測試圖片失敗")
            return
        }
        
        sendTransferFile(
            name: "chiikawa-\(Int(Date().timeIntervalSince1970)).png",
            contentType: .png,
            data: data
        )
    }
}

// MARK: - Setup
private extension ClientTransferViewController {
    
    func setupBluetooth() {
        
        client.onEvent = { [weak self] event in
            guard let self else { return }
            Task { @MainActor in self.handleClientEvent(event) }
        }
        
        Task { @MainActor in
            try await Task.sleep(for: .seconds(1.0))
            client.startScan()
        }
    }
    
    func bindTransferEvents() {
        
        clientTransfer.onEvent = { [weak self] event in
            
            guard let self else { return }
            
            Task { @MainActor in
                
                switch event {
                case .didStart(let transferId): self.logTextView.appendLog("開始傳輸: \(transferId)")
                case .didSendHello(let transferId): self.logTextView.appendLog("已送出 Hello: \(transferId)")
                case .didSendChunk(let index, let total): self.logTextView.appendLog("已送出切片: \(index + 1) / \(total)")
                case .didFinish(let transferId): self.logTextView.appendLog("傳輸完成: \(transferId)")
                case .didFail(let error): self.logTextView.appendLog("傳輸失敗: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Client Event
private extension ClientTransferViewController {
    
    func handleClientEvent(_ event: WWBluetoothManager.ClientEvent) {
        
        logTextView.appendLog("\(event)")
        
        switch event {
        case .stateChanged(let state): handleBluetoothStateChanged(state)
        case .discovered(let device): connectDeviceIfNeeded(device)
        case .connected(let device): handleConnected(device)
        case .disconnected(let device, let error): handleDisconnected(device: device, error: error)
        case .servicesDiscovered(let device, let uuids): handleServicesDiscovered(device: device, uuids: uuids)
        case .characteristicsDiscovered(let service, let characteristics): handleCharacteristicsDiscovered(service: service, characteristics: characteristics)
        case .notificationEnabled(let uuid): handleNotificationEnabled(uuid: uuid)
        case .valueUpdated(let uuid, let data): handleValueUpdated(uuid: uuid, data: data)
        case .writeCompleted(let uuid, let error): handleWriteCompleted(uuid: uuid, error: error)
        case .failed(let error): logTextView.appendLog("Client 錯誤: \(error.localizedDescription)")
        }
    }
    
    func handleBluetoothStateChanged(_ state: CBManagerState) {
        
        guard state == .poweredOn else { logTextView.appendLog("藍牙尚未可用: \(state.rawValue)"); return }
        
        logTextView.appendLog("藍牙已開啟，開始掃描")
        client.startScan()
    }
}

// MARK: - Connection
private extension ClientTransferViewController {
    
    func connectDeviceIfNeeded(_ device: WWBluetoothManager.Device) {
        
        guard device.name == targetLocalName else { return }
        
        connectedDevice = device
        logTextView.appendLog(device.jsonString ?? "")
        
        client.stopScan()
        client.connect(device)
    }
    
    func handleConnected(_ device: WWBluetoothManager.Device) {
        
        connectedDevice = device
        connectedPeripheral = device.peripheral
        
        logTextView.appendLog("已連線: \(device.name)")
    }
    
    func handleDisconnected(device: WWBluetoothManager.Device?, error: Error?) {
        
        logTextView.appendLog("裝置斷線: \(device?.name ?? "unknown") / \(error?.localizedDescription ?? "nil")")
        
        connectedDevice = nil
        connectedPeripheral = nil
        controlCharacteristic = nil
        dataCharacteristic = nil
    }
}

// MARK: - Discovery
private extension ClientTransferViewController {
    
    func handleServicesDiscovered(device: WWBluetoothManager.Device, uuids: [CBUUID]) {
        logTextView.appendLog("已發現 Services: \(uuids)")
    }
    
    func handleCharacteristicsDiscovered(service: CBService, characteristics: [CBCharacteristic]) {
        
        logTextView.appendLog("Service[\(service.uuid.uuidString)] 的 Characteristics: \(characteristics.map { $0.uuid.uuidString })")
        
        characteristics.forEach { characteristic in
            
            guard let uuidType = WWBluetoothManager.UUIDType.find(uuid: characteristic.uuid) else { return }
            
            switch uuidType {
            case .control:
                controlCharacteristic = characteristic
                connectedPeripheral?.setNotifyValue(true, for: characteristic)
                logTextView.appendLog("Control characteristic ready => \(characteristic.uuid.uuidString)")
                
            case .data:
                dataCharacteristic = characteristic
                connectedPeripheral?.setNotifyValue(true, for: characteristic)
                logTextView.appendLog("Data characteristic ready => \(characteristic.uuid.uuidString)")
                
            default:
                break
            }
        }
    }
    
    func handleNotificationEnabled(uuid: CBUUID) {
        logTextView.appendLog("已啟用通知: \(uuid.uuidString)")
    }
}
    
// MARK: - Transfer Bridge
private extension ClientTransferViewController {
    
    func handleValueUpdated(uuid: CBUUID, data: Data) {
        
        guard let peripheral = connectedPeripheral,
              let characteristic = matchedCharacteristic(for: uuid)
        else {
            return
        }
        
        let status = WWBluetoothManager.PeripheralStatus.characteristicValueUpdated(characteristic: characteristic, data: data, error: nil)
        clientTransfer.handle(peripheral: peripheral, status: status)
    }
    
    func handleWriteCompleted(uuid: CBUUID, error: Error?) {
        
        guard let peripheral = connectedPeripheral,
              let characteristic = matchedCharacteristic(for: uuid)
        else {
            return
        }
        
        let status = WWBluetoothManager.PeripheralStatus.characteristicWriteCompleted(characteristic: characteristic, error: error)
        clientTransfer.handle(peripheral: peripheral, status: status)
    }
    
    func matchedCharacteristic(for uuid: CBUUID) -> CBCharacteristic? {
        
        if controlCharacteristic?.uuid == uuid { return controlCharacteristic }
        if dataCharacteristic?.uuid == uuid { return dataCharacteristic }
        
        return nil
    }
}

// MARK: - Send File
private extension ClientTransferViewController {
    
    func sendTransferFile(name: String, contentType: UTType, data: Data) {
        
        guard let peripheral = connectedPeripheral else { logTextView.appendLog("尚未連線 peripheral"); return }
        guard let controlCharacteristic, let dataCharacteristic else { logTextView.appendLog("尚未取得傳輸用 characteristic"); return }
        
        let fileInfo = WWBluetoothManager.FileInformation(name: name, contentType: contentType, data: data)
        let characteristics = WWBluetoothManager.TransferCharacteristics(control: controlCharacteristic, data: dataCharacteristic)
        
        do {
            try clientTransfer.sendFile(using: peripheral, fileInfo: fileInfo, characteristics: characteristics)
        } catch {
            logTextView.appendLog("送檔失敗: \(error.localizedDescription)")
        }
    }
}


