//
//  Client.swift
//  WWBluetoothManager
//
//  Created by WilliamWeng on 2026/5/4.
//

import CoreBluetooth

// MARK: - 再將 Central 簡化成快速易用的 Client
public extension WWBluetoothManager {
    
    final class Client {
        
        public var onEvent: ((ClientEvent) -> Void)?                                        // 用於向外部回報藍牙事件的閉包 => 當掃描到裝置、連線狀態變更或接收到數據時，此閉包會被觸發
        
        public private(set) var scannedDevices: [UUID: WWBluetoothManager.Device] = [:]     // 已掃描到的設備列表，以設備 UUID 為鍵值進行快取 => 這能確保 UI 層可以輕鬆透過 UUID 檢索並顯示清單
        public private(set) var connectedDevice: WWBluetoothManager.Device?                 // 目前已成功連線的設備 => 若為 nil 表示目前沒有連線中的設備
        
        private let central: WWBluetoothManager.Central                                     // 底層負責處理 CBCentralManager 和 CBPeripheralDelegate 邏輯的引擎
        
        private var connectedPeripheral: CBPeripheral?                                      // 當前連線的周邊設備實體 (CoreBluetooth 底層物件)
        private var writableCharacteristics: [CBUUID: CBCharacteristic] = [:]               // 快取所有「可寫入」的特徵值 (Characteristics)，以 UUID 為鍵值 => 用於快速查閱並執行寫入操作，無需每次重新遍歷服務列表
        private var notifyCharacteristics: [CBUUID: CBCharacteristic] = [:]                 // 快取所有「具備通知/指示功能」的特徵值 (Characteristics)，以 UUID 為鍵值 => 用於快速開啟或關閉特定特徵值的數據推送
        
        /// 初始化 Client 並注入 Central 引擎。
        /// - Parameter central: 用於執行藍牙操作的 Central 實例，預設為新建立的實例。
        public init(central: WWBluetoothManager.Central = .init()) {
            self.central = central
            bindCentral()
        }
    }
}

// MARK: - 公開 API (Public API)
public extension WWBluetoothManager.Client {
    
    /// 開始掃描周邊設備
    /// - Parameters:
    ///   - serviceUUIDs: 過濾特定服務的 UUID，nil 則掃描所有設備
    ///   - allowDuplicates: 是否允許重複回報同一設備
    func startScan(serviceUUIDs: [CBUUID]? = nil, allowDuplicates: Bool = false) {
        central.startScan(serviceUUIDs: serviceUUIDs, allowDuplicates: allowDuplicates)
    }
    
    /// 開始掃描周邊設備
    /// - Parameters:
    ///   - serviceUUIDTypes: 一組預定義的 `ServiceUUIDType`，用於過濾包含這些服務的周邊設備。若為 nil 則掃描所有設備。
    ///   - allowDuplicates: 是否允許重複回報同一設備
    func startScan(serviceUUIDTypes: [WWBluetoothManager.UUIDType], allowDuplicates: Bool = false) {
        central.startScan(serviceUUIDTypes: serviceUUIDTypes, allowDuplicates: allowDuplicates)
    }
    
    /// 停止藍牙掃描
    func stopScan() {
        central.stopScan()
    }

    /// 連線至指定設備
    /// - Parameter device: 要連線的目標裝置
    func connect(_ device: WWBluetoothManager.Device) {
        central.connect(device.peripheral)
    }

    /// 斷開目前已連線的設備
    func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        central.disconnect(peripheral)
    }
    
    /// 啟用特定特徵值的通知功能（用於接收設備推送的數據）
    /// - Parameter uuidString: 特徵值的 UUID 字串
    /// - Returns: Result<Bool, WWBluetoothManager.ClientError>
    func enableNotify(_ uuidString: String) -> Result<Bool, WWBluetoothManager.ClientError> {
        
        guard let uuid = uuidString.asCBUUID else { return .failure(.invalidUUID) }
        guard let peripheral = connectedPeripheral else { return .failure(.peripheralNotConnected) }
        guard let characteristic = notifyCharacteristics[uuid] else { return .failure(.characteristicNotFound) }
        
        peripheral.setNotifyValue(true, for: characteristic)
        
        return .success(true)
    }

    /// 停用特定特徵值的通知功能
    /// - Parameter uuidString: 特徵值的 UUID 字串
    /// - Returns: Result<Bool, WWBluetoothManager.ClientError>
    func disableNotify(_ uuidString: String) -> Result<Bool, WWBluetoothManager.ClientError> {
        
        guard let uuid = uuidString.asCBUUID else { return .failure(.invalidUUID) }
        guard let peripheral = connectedPeripheral else { return .failure(.peripheralNotConnected) }
        guard let characteristic = notifyCharacteristics[uuid] else { return .failure(.characteristicNotFound) }
        
        peripheral.setNotifyValue(false, for: characteristic)
        
        return .success(true)
    }
    
    /// 將原始資料 (Data) 寫入指定特徵值 => 自動判斷寫入模式：優先使用傳入的 type，否則依據屬性決定
    /// - Parameters:
    ///   - data: 要寫入的資料
    ///   - uuidString: 目標特徵值的 UUID 字串
    ///   - type: 寫入類型 (預設會根據屬性自動決定使用 .withResponse 或 .withoutResponse)
    /// - Returns: Result<Bool, WWBluetoothManager.ClientError>
    func write(_ data: Data, to uuidString: String, type: CBCharacteristicWriteType? = nil) -> Result<Bool, WWBluetoothManager.ClientError> {
        
        guard let uuid = uuidString.asCBUUID else { return .failure(.invalidUUID) }
        guard let peripheral = connectedPeripheral else { return .failure(.peripheralNotConnected) }
        guard let characteristic = writableCharacteristics[uuid] else { return .failure(.characteristicNotFound) }
        
        let writeType: CBCharacteristicWriteType
        
        if let type {
            writeType = type
        } else if characteristic.properties.contains(.writeWithoutResponse) {
            writeType = .withoutResponse
        } else {
            writeType = .withResponse
        }

        peripheral.writeValue(data, for: characteristic, type: writeType)
        
        return .success(true)
    }

    /// 將字串寫入指定特徵值 (自動轉換為 UTF-8 資料)
    /// - Parameters:
    ///   - string: 要寫入的字串
    ///   - uuidString: 目標特徵值的 UUID 字串
    ///   - encoding: 編碼格式，預設為 UTF-8
    ///   - type: 寫入類型
    /// - Returns: Result<Bool, WWBluetoothManager.ClientError>
    func write(_ string: String, to uuidString: String, encoding: String.Encoding = .utf8, type: CBCharacteristicWriteType? = nil) -> Result<Bool, WWBluetoothManager.ClientError> {
        
        guard let data = string.data(using: encoding) else { return .failure(.encodingFailed) }
        write(data, to: uuidString, type: type)
        
        return .success(true)
    }
}

// MARK: - WWBluetoothManager.CentralDelegate（事件中介層）
public extension WWBluetoothManager.Client {
        
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
        case .serviceDiscoveryFailed(let error):  serviceDiscoveryFailed(peripheral, error: error)
        }
    }
}

// MARK: - WWBluetoothCentralDelegate
extension WWBluetoothManager.Client: WWBluetoothManager.CentralDelegate {}

// MARK: - 實現 WWBluetoothManager.CentralDelegate (CBCentralManagerDelegate) => 此處定義了所有與藍牙協議互動的邏輯，將複雜的 Delegate 回調轉換為統一的 onEvent 通知
private extension WWBluetoothManager.Client {
    
    /// 藍牙適配器狀態變更 (如：開啟、關閉)
    func centralStateUpdated(_ state: CBManagerState) {
        onEvent?(.stateChanged(state))
    }
    
    /// 掃描到新裝置：將原始 ScanResult 轉換為 Client 專用的 Device 模型，並快取起來
    func centralDiscovered(_ result: WWBluetoothManager.Central.ScanResult) {
        
        let device = WWBluetoothManager.Device(
            peripheral: result.peripheral,
            name: result.displayName ?? "UnKnown",
            rssi: result.rssi.intValue,
            isConnectable: result.isConnectable ?? false
        )
        
        scannedDevices[device.id] = device
        onEvent?(.discovered(device))
    }
    
    /// 裝置連線成功：更新當前連線狀態並發布連線事件 => 嘗試從掃描清單中取回裝置資訊，若無則建立一個臨時實例
    func centralConnected(_ peripheral: CBPeripheral) {
        
        connectedPeripheral = peripheral
        
        let device = scannedDevices[peripheral.identifier] ?? WWBluetoothManager.Device(
            peripheral: peripheral,
            name: peripheral.name ?? "Unknown",
            rssi: 0,
            isConnectable: true
        )
        
        connectedDevice = device
        onEvent?(.connected(device))
    }
    
    /// 裝置斷線：清除連線快取與所有特徵值對應表 => 清除快取，避免錯誤操作
    func centralDisconnected(_ peripheral: CBPeripheral, error: Error?) {
        
        let device = scannedDevices[peripheral.identifier] ?? connectedDevice
        
        connectedPeripheral = nil
        connectedDevice = nil
        writableCharacteristics.removeAll()
        notifyCharacteristics.removeAll()
        onEvent?(.disconnected(device, error))
    }
    
    /// 連線失敗處理
    func centralFailedToConnect(_ peripheral: CBPeripheral, error: Error?) {
        guard let error else { return }
        onEvent?(.failed(error))
    }
}

// MARK: - 實現 WWBluetoothManager.CentralDelegate (CBPeripheralDelegate) => 此處定義了所有與藍牙協議互動的邏輯，將複雜的 Delegate 回調轉換為統一的 onEvent 通知
private extension WWBluetoothManager.Client {
  
    /// 服務發現成功：通知外部已發現該裝置的所有服務
    func discoveredServices(_ peripheral: CBPeripheral, services: [CBService]) {
        
        guard let device = scannedDevices[peripheral.identifier] ?? connectedDevice else { return }
        onEvent?(.servicesDiscovered(device, services.map(\.uuid)))
    }
        
    /// 特性發現成功：自動分類並快取具備通知 (Notify) 或寫入 (Write) 功能的特性
    func discoveredCharacteristics(_ peripheral: CBPeripheral, service: CBService, characteristics: [CBCharacteristic]) {
        
        characteristics.forEach { characteristic in
            if characteristic.properties.canNotify { self.notifyCharacteristics[characteristic.uuid] = characteristic }
            if characteristic.properties.canWrite { self.writableCharacteristics[characteristic.uuid] = characteristic }
        }
        
        onEvent?(.characteristicsDiscovered(service.uuid, characteristics.map(\.uuid)))
    }
    
    /// 可根據需求加入錯誤日誌記錄
    func serviceDiscoveryFailed(_ peripheral: CBPeripheral, error: Error?) {}
    
    /// 特徵值發現錯誤
    func characteristicDiscoveryFailed(_ peripheral: CBPeripheral, service: CBService, error: Error?) {
        if let error { onEvent?(.failed(error)) }
    }
    
    /// 通知狀態變更：監聽通知是否成功開啟
    func notificationStateUpdated(_ peripheral: CBPeripheral, characteristic: CBCharacteristic, error: Error?) {
        
        if let error { onEvent?(.failed(error)); return }
        if characteristic.isNotifying { onEvent?(.notificationEnabled(characteristic.uuid)) }
    }
    
    /// 接收到資料更新：從藍牙裝置獲取回傳數據
    func characteristicValueUpdated(_ peripheral: CBPeripheral, characteristic: CBCharacteristic, data: Data?, error: Error?) {
        
        if let error { onEvent?(.failed(error)); return }
        
        guard let data else { return }
        onEvent?(.valueUpdated(characteristic.uuid, data))
    }
    
    /// 寫入資料完成：通知外部寫入指令是否成功
    func characteristicWriteCompleted(_ peripheral: CBPeripheral, characteristic: CBCharacteristic, error: Error?) {
        onEvent?(.writeCompleted(characteristic.uuid, error))
    }
}

// MARK: - 小工具
private extension WWBluetoothManager.Client {
    
    /// 綁定 WWBluetoothManager.Central
    func bindCentral() {
        central.delegate = self
    }
}

