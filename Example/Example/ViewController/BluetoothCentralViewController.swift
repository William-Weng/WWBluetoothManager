//
//  ViewController.swift
//  Example
//
//  Created by William.Weng on 2025/10/29.
//
// NSBluetoothAlwaysUsageDescription = 需要藍牙權限來搜尋並連接附近裝置
// 掃描 → connect → didConnect → discoverServices → discoverCharacteristics
//
// 展示完整的 Bluetooth LE 開發流程：
// 1. 掃描特定設備（"Control for SB1830"）
// 2. 自動連線並發現服務/特性
// 3. 啟用通知並發送寫入指令

import UIKit
import CoreBluetooth
import WWPrint
import WWBluetoothManager

final class BluetoothCentralViewController: UIViewController {
    
    private let central = WWBluetoothManager.Central()                  // WWBluetoothManager 的 Central 管理器實例
    private let targetLocalName = "Control for SB1830"                  // 目標設備名稱過濾（廣告資料中的 localName）
    private let writeUUID = "B7860002-11B8-B681-6343-5A6C2286633F"      // 寫入特性 UUID
    private let notifyUUID = "B7860003-11B8-B681-6343-5A6C2286633F"     // 通知特性 UUID
    
    private var targetPeripheral: CBPeripheral?                         // 目標周邊設備（連線中的 SB1830）
    private var writableCharacteristic: CBCharacteristic?               // 可寫入特性（用於發送控制指令）
    private var notifyCharacteristic: CBCharacteristic?                 // 可通知特性（接收設備回報）
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bindBluetooth()
    }
    
    @IBAction func sendHex01(_ sender: UIButton) { sendHex() }
}

// MARK: - WWBluetoothManager.CentralDelegate（事件中介層）
extension BluetoothCentralViewController: WWBluetoothManager.CentralDelegate {
    
    /// CentralManager 事件處理（CBCentralManagerDelegate）
    func centralManager(_ central: WWBluetoothManager.Central, status: WWBluetoothManager.CentralStatus) {
        switch status {
        case .stateUpdated(let state): centralStateUpdated(state)
        case .discovered(let result): centralDiscovered(result)
        case .connected(let peripheral): centralConnected(peripheral)
        case .disconnected(let peripheral, let error): centralDisconnected(peripheral, error: error)
        case .failedToConnect(let peripheral, let error): centralFailedToConnect(peripheral, error: error)
        }
    }
    
    /// Peripheral 事件處理（CBPeripheralDelegate）
    func centralManager(_ central: WWBluetoothManager.Central, peripheral: CBPeripheral, status: WWBluetoothManager.PeripheralStatus) {
        switch status {
        case .discoveredServices(let services): discoveredServices(peripheral, services: services)
        case .discoveredCharacteristics(let service, let characteristics): discoveredCharacteristics(peripheral, service: service, characteristics: characteristics)
        case .notificationStateUpdated(let characteristic, let error): notificationStateUpdated(peripheral, characteristic: characteristic, error: error)
        case .characteristicDiscoveryFailed(let service, let error): characteristicDiscoveryFailed(peripheral, service: service, error: error)
        case .characteristicValueUpdated(let characteristic, let data, let error): characteristicValueUpdated(peripheral, characteristic: characteristic, data: data, error: error)
        case .characteristicWriteCompleted(let characteristic, let error): characteristicWriteCompleted(peripheral, characteristic: characteristic, error: error)
        case .serviceDiscoveryFailed(let error): serviceDiscoveryFailed(peripheral, error: error)
        }
    }
}

// MARK: - CentralManager 事件實現
private extension BluetoothCentralViewController {
    
    /// Bluetooth 狀態更新
    /// - 僅在 `.poweredOn` 時自動開始掃描
    func centralStateUpdated(_ state: CBManagerState) {
        
        wwPrint("Bluetooth state => \(state.rawValue)")
        
        guard state == .poweredOn else { return }
        central.startScan()
    }
    
    /// 掃描發現設備，檢查目標設備並自動連線
    func centralDiscovered(_ result: WWBluetoothManager.Central.ScanResult) {
        
        guard let displayName = result.displayName,
              displayName == targetLocalName
        else {
            return
        }
        
        wwPrint("\(result.jsonString())")
        central.stopScan()
        central.connect(result.peripheral)
    }
    
    /// 連線成功，記錄目標設備
    func centralConnected(_ peripheral: CBPeripheral) {
        
        targetPeripheral = peripheral
        wwPrint("Connected => \(peripheral.name ?? "Unknown")")
    }
    
    /// 斷線事件，清理所有狀態
    func centralDisconnected(_ peripheral: CBPeripheral, error: Error?) {
        
        wwPrint("Disconnected => \(peripheral.name ?? "Unknown"), error => \(String(describing: error))")
        
        targetPeripheral = nil
        writableCharacteristic = nil
        notifyCharacteristic = nil
    }
    
    /// 連線失敗
    func centralFailedToConnect(_ peripheral: CBPeripheral, error: Error?) {
        wwPrint("Failed => \(peripheral.name ?? "Unknown"), error => \(String(describing: error))")
    }
}

// MARK: - Peripheral 事件實現
private extension BluetoothCentralViewController {
    
    /// 服務發現完成，列印所有服務 UUID
    func discoveredServices(_ peripheral: CBPeripheral, services: [CBService]) {
        
        wwPrint("Services of \(peripheral.name ?? "Unknown"): (\(services.count) 個)")
        services.forEach { service in wwPrint("Service => \(service.uuid.uuidString)") }
    }
    
    /// 特性發現完成，尋找目標寫入/通知特性並啟用通知
    func discoveredCharacteristics(_ peripheral: CBPeripheral, service: CBService, characteristics: [CBCharacteristic]) {
        
        wwPrint("Characteristics of \(service.uuid.uuidString) (\(characteristics.count) 個):")
        
        characteristics.forEach { characteristic in
            let uuid = characteristic.uuid.uuidString
            wwPrint("\(uuid)")
            wwPrint("Properties => \(characteristic.properties)")
            
            // 找到寫入特性
            if uuid == writeUUID {
                writableCharacteristic = characteristic
                wwPrint("Writable characteristic found!")
            }
            
            // 找到通知特性並自動啟用
            if uuid == notifyUUID {
                notifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                wwPrint("Notify enabled!")
            }
        }
    }
    
    /// 服務發現失敗（空實作）
    func serviceDiscoveryFailed(_ peripheral: CBPeripheral, error: Error?) {}
    
    /// 特性發現失敗（空實作）
    func characteristicDiscoveryFailed(_ peripheral: CBPeripheral, service: CBService, error: Error?) {}
    
    /// 通知狀態更新
    func notificationStateUpdated(_ peripheral: CBPeripheral, characteristic: CBCharacteristic, error: Error?) {
        wwPrint("Notification state updated => \(characteristic.uuid.uuidString), isNotifying => \(characteristic.isNotifying), error => \(String(describing: error))")
    }
    
    /// 接收通知資料
    func characteristicValueUpdated(_ peripheral: CBPeripheral, characteristic: CBCharacteristic, data: Data?, error: Error?) {
        
        wwPrint("Value updated => \(characteristic.uuid.uuidString), error => \(String(describing: error))")
        guard let data else { wwPrint("  Notify data => nil"); return }
        
        wwPrint("Notify hex => \(data.hexString())")
        wwPrint("Notify utf8 => \(data.string() ?? "<non-utf8>")")
    }
    
    /// 寫入完成回調
    func characteristicWriteCompleted(_ peripheral: CBPeripheral, characteristic: CBCharacteristic, error: Error?) {
        wwPrint("Write completed => \(characteristic.uuid.uuidString), error => \(String(describing: error))")
    }
}

// MARK: - 小工具
private extension BluetoothCentralViewController {
    
    /// 綁定 Bluetooth 委派，啟動事件監聽
    func bindBluetooth() {
        central.delegate = self
    }
    
    /// 發送 0x01 控制指令（延遲 0.5 秒避免連續寫入）
    func sendHex(byte: UInt8 = 0x01) {
        
        guard let peripheral = targetPeripheral else { wwPrint("No connected peripheral"); return }
        guard let characteristic = writableCharacteristic else { wwPrint("No writable characteristic"); return }
        
        let data = Data([byte])
        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            peripheral.writeValue(data, for: characteristic, type: writeType)
            wwPrint("Send hex => \(data.map { String(format: "%02x", $0) }.joined())")
        }
    }
}
