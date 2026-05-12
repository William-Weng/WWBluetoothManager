//
//  Accessory.swift
//  WWBluetoothManager
//
//  Created by William.Weng on 2026/5/12.
//

import CoreBluetooth

// MARK: - 再將 Peripheral 簡化成快速易用的 Accessory
public extension WWBluetoothManager {
    
    final class Accessory: NSObject {
        
        public typealias EventHandler = (AccessoryEvent) -> Void
        
        public var onEvent: EventHandler?
        
        public private(set) var peripheral: Peripheral
        
        public init(peripheral: WWBluetoothManager.Peripheral = .init()) {
            self.peripheral = peripheral
            super.init()
            bindPeripheral()
        }
    }
}

// MARK: - WWBluetoothManager.PeripheralDelegate（事件中介層）
public extension WWBluetoothManager.Accessory {
    
    func peripheralManager(_ peripheral: WWBluetoothManager.Peripheral, status: WWBluetoothManager.PeripheralManagerStatus) {
        
        let event: WWBluetoothManager.AccessoryEvent
        
        switch status {
        case .stateUpdated(let state): event = .stateUpdated(state: state)
        case .serviceAdded(let service, let error): event = .serviceAdded(service: service, error: error)
        case .advertisingStarted(let error): event = .advertisingStarted(error: error)
        case .advertisingStopped: event = .advertisingStopped
        case .subscribed(let central, let characteristic): event = .subscribed(central: central, characteristic: characteristic)
        case .unsubscribed(let central, let characteristic): event = .unsubscribed(central: central, characteristic: characteristic)
        case .didReceiveReadRequest(let request): event = .didReceiveReadRequest(request: request)
        case .writeRequests(let requests): event = .didReceiveWriteRequests(requests: requests)
        case .readyToUpdateSubscribers: event = .readyToUpdateSubscribers
        }
        
        onEvent?(event)
    }
}

// MARK: - 公開函式
public extension WWBluetoothManager.Accessory {
    
    /// 發布一個檔案傳輸用的 GATT Service
    func publish(serviceUUID: CBUUID, controlUUID: CBUUID, dataUUID: CBUUID) {
        peripheral.publish(serviceUUID: serviceUUID, controlUUID: controlUUID, dataUUID: dataUUID)
    }
    
    /// 發布一個檔案傳輸用的 GATT Service
    func publish(serviceType: WWBluetoothManager.UUIDType, controlType: WWBluetoothManager.UUIDType, dataType: WWBluetoothManager.UUIDType) {
        peripheral.publish(serviceUUID: serviceType.cbUUID, controlUUID: controlType.cbUUID, dataUUID: dataType.cbUUID)
    }
    
    func startAdvertising(localName: String, serviceUUIDs: [CBUUID]) {
        peripheral.startAdvertising(localName: localName, serviceUUIDs: serviceUUIDs)
    }
    
    /// 開始廣播目前 Peripheral 的檔案傳輸服務 => 在 iOS 的 BLE peripheral advertising 中，最常使用的資料就是 local name 與 service UUIDs
    func startAdvertising(localName: String, serviceTypes: [WWBluetoothManager.UUIDType]) {
        peripheral.startAdvertising(localName: localName, serviceTypes: serviceTypes)
    }
    
    /// 停止目前的 BLE advertising => 呼叫 `CBPeripheralManager.stopAdvertising()` 停止廣播
    func stopAdvertising() {
        peripheral.stopAdvertising()
    }
    
    /// 移除目前已發布的所有 GATT services，並清空內部保存的參考
    func removeAllServices() {
        peripheral.removeAllServices()
    }
    
    /// 將資料以 notify 的方式推送給已訂閱此 characteristic 的 Central
    func notifyValue(_ data: Data, for characteristic: CBMutableCharacteristic) -> Bool {
        peripheral.notifyValue(data, for: characteristic)
    }
}

// MARK: - WWBluetoothManager.PeripheralDelegate
extension WWBluetoothManager.Accessory: WWBluetoothManager.PeripheralDelegate {}

// MARK: - 小工具
private extension WWBluetoothManager.Accessory {
    
    /// 綁定 WWBluetoothManager.Accessory
    func bindPeripheral() {
        peripheral.delegate = self
    }
}
