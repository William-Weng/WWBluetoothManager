//
//  Central.swift
//  WWBluetoothManager
//
//  Created by WilliamWeng on 2026/5/4.
//

import Foundation
import CoreBluetooth

// MARK: - Central Manager 主類別 (封裝了 `CBCentralManager` 和 `CBPeripheralDelegate`，提供簡潔的委派介面)
public extension WWBluetoothManager {
    
    final class Central: NSObject {
        
        public weak var delegate: CentralDelegate?                      // 委派物件，接收所有 CentralManager 和 Peripheral 事件
        
        private var centralManager: CBCentralManager!                   // 藍牙中央管理器
        private var discoveredPeripherals: [UUID: CBPeripheral] = [:]   // 發現的周邊設備們（掃描期間累積）
        private var connectedPeripheral: CBPeripheral?                  // 目前連線中的周邊設備（僅一個）
        
        public override init() {
            super.init()
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
    }
}

// MARK: - 公開唯讀屬性 (提供 Central 狀態和已發現設備的唯讀存取)
public extension WWBluetoothManager.Central {
    
    var state: CBManagerState { getState() }                            // 目前 Bluetooth 適配器狀態
    var peripherals: [CBPeripheral] { getPeripherals() }                // 所有已發現的周邊設備列表（掃描期間累積）
}

// MARK: - 公開 API (掃描、連線、斷線等核心操作方法)
public extension WWBluetoothManager.Central {
    
    /// 開始掃描周邊設備 (支援型別安全的服務過濾)
    /// - Parameters:
    ///   - serviceUUIDs: 過濾特定服務的 UUID（nil = 掃描所有）
    ///   - allowDuplicates: 是否允許重複回報（預設 false）
    /// - 注意: 僅在 `state == .poweredOn` 時才會執行
    func startScan(serviceUUIDs: [CBUUID]? = nil, allowDuplicates: Bool = false) {
        
        if (centralManager.state != .poweredOn) { return }
        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: [CBCentralManagerScanOptionAllowDuplicatesKey: allowDuplicates])
    }
    
    /// 開始掃描周邊設備 (支援型別安全的服務過濾)
    /// - Parameters:
    ///   - serviceUUIDTypes: 一組預定義的 `ServiceUUIDType`，用於過濾包含這些服務的周邊設備。若為 nil 則掃描所有設備。
    ///   - allowDuplicates: 是否允許掃描期間重複回報同一個設備。預設為 false。
    func startScan(serviceUUIDTypes: [WWBluetoothManager.ServiceUUIDType], allowDuplicates: Bool = false) {
        
        let uuids = serviceUUIDTypes.map { $0.cbuuid() }
        startScan(serviceUUIDs: uuids, allowDuplicates: allowDuplicates)
    }
    
    /// 停止掃描
    func stopScan() {
        centralManager.stopScan()
    }

    /// 連接到指定周邊設備
    /// - Parameters:
    ///   - peripheral: 目標設備
    ///   - options: 連線選項（可選）
    /// - 注意: 設定為目前 `connectedPeripheral`
    func connect(_ peripheral: CBPeripheral, options: [String: Any]? = nil) {
        connectedPeripheral = peripheral
        centralManager.connect(peripheral, options: options)
    }
    
    /// 斷開指定周邊設備連線
    func disconnect(_ peripheral: CBPeripheral) {
        centralManager.cancelPeripheralConnection(peripheral)
    }

    /// 開始發現指定設備的服務
    /// - Parameters:
    ///   - serviceUUIDs: 目標服務 UUID（nil = 發現所有）
    ///   - peripheral: 目標設備
    func discoverServices(_ serviceUUIDs: [CBUUID]? = nil, for peripheral: CBPeripheral) {
        peripheral.discoverServices(serviceUUIDs)
    }
}

// MARK: - CBCentralManagerDelegate 實作 (將 CoreBluetooth 委派事件轉發為統一的 `CentralStatus`)
public extension WWBluetoothManager.Central {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        delegate?.centralManager(self, status: .stateUpdated(state: central.state))
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        appendPeripheral(peripheral, advertisementData: advertisementData, rssi: RSSI)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        discoverServices(from: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        peripheralDisconnect(peripheral, error: error)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        peripheralConnectFail(peripheral, error: error)
    }
}

// MARK: - CBPeripheralDelegate 實作 (將外設委派事件轉發為統一的 `PeripheralStatus`)
public extension WWBluetoothManager.Central {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        discoverServices(from: peripheral, error: error)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        didDiscoverCharacteristics(at: peripheral, for: service, error: error)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        delegate?.centralManager(self, peripheral: peripheral, status: .notificationStateUpdated(characteristic: characteristic, error: error))
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        delegate?.centralManager(self, peripheral: peripheral, status: .characteristicValueUpdated(characteristic: characteristic, data: characteristic.value, error: error))
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        delegate?.centralManager(self, peripheral: peripheral, status: .characteristicWriteCompleted(characteristic: characteristic, error: error))
    }
}

// MARK: - Protocol Conformance
extension WWBluetoothManager.Central: CBPeripheralDelegate {}
extension WWBluetoothManager.Central: CBCentralManagerDelegate {}

// MARK: - 內部工具方法
private extension WWBluetoothManager.Central {
    
    /// 取得目前 Bluetooth 狀態
    func getState() -> CBManagerState {
        centralManager.state
    }
    
    /// 取得所有已發現設備
    func getPeripherals() -> [CBPeripheral] {
        Array(discoveredPeripherals.values)
    }
}

// MARK: - 內部工具方法 (封裝 CBCentralManagerDelegate 的核心邏輯，提供重用性和可測試性)
private extension WWBluetoothManager.Central {
    
    /// 掃描期間發現新設備的處理邏輯
    /// - Parameters:
    ///   - peripheral: 發現的周邊設備
    ///   - advertisementData: 廣告資料包
    ///   - rssi: 訊號強度
    /// **行為**：
    /// 1. 將設備加入 `discoveredPeripherals` 快取（以 UUID 為 key）
    /// 2. 建立 `ScanResult` 並透過委派通知發現事件
    /// 3. 不重複儲存相同 UUID 的設備
    func appendPeripheral(_ peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        
        let result = ScanResult(peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI)
        
        discoveredPeripherals[peripheral.identifier] = peripheral
        delegate?.centralManager(self, status: .discovered(result: result))
    }
    
    /// 連線成功後的初始化流程
    /// - Parameter peripheral: 已連線的周邊設備
    /// **自動執行流程**：
    /// 1. 設定 `peripheral.delegate = self`（啟用 CBPeripheralDelegate）
    /// 2. 更新 `connectedPeripheral` 狀態
    /// 3. 通知 `CentralStatus.connected` 事件
    /// 4. 自動開始服務發現 `discoverServices(nil)`
    func discoverServices(from peripheral: CBPeripheral) {
        
        peripheral.delegate = self
        connectedPeripheral = peripheral
        delegate?.centralManager(self, status: .connected(peripheral: peripheral))
        
        peripheral.discoverServices(nil)
    }
    
    /// 周邊設備斷線處理
    /// - Parameters:
    ///   - peripheral: 斷線的設備
    ///   - error: 斷線原因（可為 nil）
    /// **狀態清理**：
    /// - 若為目前連線設備，清除 `connectedPeripheral`
    /// - 通知 `CentralStatus.disconnected` 事件
    /// - 不影響其他已發現設備快取
    func peripheralDisconnect(_ peripheral: CBPeripheral, error: Error?) {
        
        if (connectedPeripheral?.identifier == peripheral.identifier) { connectedPeripheral = nil }
        delegate?.centralManager(self, status: .disconnected(peripheral: peripheral, error: error))
    }
    
    /// 周邊設備連線失敗處理
    /// - Parameters:
    ///   - peripheral: 連線失敗的設備
    ///   - error: 失敗原因（可為 nil）
    /// **狀態清理**：
    /// - 若為目前連線目標，清除 `connectedPeripheral`
    /// - 通知 `CentralStatus.failedToConnect` 事件
    /// - 設備仍保留在 `discoveredPeripherals`（可重試連線）
    func peripheralConnectFail(_ peripheral: CBPeripheral, error: Error?) {
        
        if (connectedPeripheral?.identifier == peripheral.identifier) { connectedPeripheral = nil }
        delegate?.centralManager(self, status: .failedToConnect(peripheral: peripheral, error: error))
    }
}

// MARK: - 內部工具方法 (封裝 `CBPeripheralDelegate` 的核心邏輯，提供重用性、可測試性和一致的錯誤處理)
private extension WWBluetoothManager.Central {
    
    /// 服務發現結果處理 => 自動啟動每個服務的特性發現（異步鏈式呼叫）
    /// - Parameters:
    ///   - peripheral: 觸發服務發現的周邊設備
    ///   - error: 發現錯誤（nil 表示成功）
    /// **執行流程**：
    /// - **失敗**：通知 `.serviceDiscoveryFailed` 並終止
    /// - **成功**：
    ///   1. 通知 `.discoveredServices` 事件
    ///   2. 自動對每個服務呼叫 `discoverCharacteristics(nil)`
    func discoverServices(from peripheral: CBPeripheral, error: Error?) {
        
        if let error { delegate?.centralManager(self, peripheral: peripheral, status: .serviceDiscoveryFailed(error: error)); return }

        let services = peripheral.services ?? []
        delegate?.centralManager(self, peripheral: peripheral, status: .discoveredServices(services: services))
        services.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
    }
    
    /// 單一服務的特性發現結果處理
    /// - Parameters:
    ///   - peripheral: 周邊設備
    ///   - service: 目標服務
    ///   - error: 發現錯誤（nil 表示成功）
    /// **執行流程**：
    /// - **失敗**：通知 `.characteristicDiscoveryFailed` 並終止
    /// - **成功**：通知 `.discoveredCharacteristics` 事件
    /// - **不自動觸發後續操作**（讓委派處理者決定）
    func didDiscoverCharacteristics(at peripheral: CBPeripheral, for service: CBService, error: Error?) {
        
        if let error { delegate?.centralManager(self, peripheral: peripheral, status: .characteristicDiscoveryFailed(service: service, error: error)); return }
        
        let characteristics = service.characteristics ?? []
        delegate?.centralManager(self, peripheral: peripheral, status: .discoveredCharacteristics(service: service, characteristics: characteristics))
    }
}
