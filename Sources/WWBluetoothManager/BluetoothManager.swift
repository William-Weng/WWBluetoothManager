//
//  BluetoothManager.swift
//  WWBluetoothManager
//
//  Created by William.Weng on 2023/11/29.
//

import UIKit
import CoreBluetooth

// MARK: - WWBluetoothManager
open class WWBluetoothManager: NSObject {

    public static let shared = build()
    
    private var peripherals: Set<CBPeripheral> = []
    private var centralManager: CBCentralManager!
    private var delegate: WWBluetoothManagerDelegate?
    
    private override init() {}
    
    deinit {
        peripherals = []
        delegate = nil
    }
}

/// MARK: - 公開函式 (1)
public extension WWBluetoothManager {
    
    /// [建立新BluetoothManager](https://www.cnblogs.com/iini/p/12334646.html)
    /// - Returns: WWBluetoothManager
    static func build() -> WWBluetoothManager { return WWBluetoothManager() }
}

/// MARK: - 公開函式 (2)
public extension WWBluetoothManager {
    
    /// [開始掃瞄](http://wisdomskyduan.blogspot.com/2013/06/ios-cb-class-note.html)
    /// - Parameters:
    ///   - queue: DispatchQueue?
    ///   - delegate: WWBluetoothManagerDelegate?
    func startScan(queue: DispatchQueue? = nil, delegate: WWBluetoothManagerDelegate?) {
        self.delegate = delegate
        self.peripherals.removeAll()
        centralManager = CBCentralManager(delegate: self, queue: queue)
    }
    
    /// [停止掃瞄](https://bbs.huaweicloud.com/blogs/354107)
    func stopScan() {
        centralManager.stopScan()
    }
    
    /// [重新開始掃瞄](https://punchthrough.com/lightblue-features/)
    /// - Parameters:
    ///   - queue: DispatchQueue?
    ///   - delegate: WWBluetoothManagerDelegate?
    func restartScan(queue: DispatchQueue? = nil, delegate: WWBluetoothManagerDelegate?) {
        stopScan()
        startScan(queue: queue, delegate: delegate)
    }
    
    /// [連接藍牙設備](https://www.wpgdadatong.com/blog/detail/40547)
    /// - Parameters:
    ///   - peripheral: CBPeripheral
    ///   - options: [String : Any]?
    func connect(peripheral: CBPeripheral, options: [String : Any]? = nil) {
        centralManager.connect(peripheral, options: options)
    }
    
    /// [藍牙設備斷開連接](doc.iotxx.com/index.php?title=BLE技术揭秘&oldid=2096)
    /// - Parameter peripheral: CBPeripheral
    func disconnect(peripheral: CBPeripheral) {
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    /// [搜尋設備](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/PerformingCommonCentralRoleTasks/PerformingCommonCentralRoleTasks.html#//apple_ref/doc/uid/TP40013257-CH3-SW7)
    /// - Parameter UUID: UUID
    /// - Returns: CBPeripheral?
    func peripheral(UUID: UUID) -> CBPeripheral? {
        let peripheral = peripherals.first { $0.identifier == UUID }
        return peripheral
    }
}

/// MARK: - 公開函式 (3)
public extension WWBluetoothManager {
    
    /// [搜尋設備](https://github.com/Eronwu/Getting-Started-with-Bluetooth-Low-Energy-in-Chinese)
    /// - Parameter UUIDString: String
    /// - Returns: CBPeripheral?
    func peripheral(UUIDString: String) -> CBPeripheral? {
        guard let UUID = UUID(uuidString: UUIDString) else { return nil }
        return peripheral(UUID: UUID)
    }
    
    /// [連接藍牙設備](https://blog.csdn.net/lang523493505/article/details/103474961)
    /// - Parameters:
    ///   - UUID: UUID
    ///   - options: [String : Any]?
    /// - Returns: Bool
    func connect(UUID: UUID, options: [String : Any]? = nil) -> UUID? {
        
        guard let peripheral = peripheral(UUID: UUID) else { return nil }
        
        connect(peripheral: peripheral, options: options)
        return peripheral.identifier
    }
    
    /// [連接藍牙設備](https://medium.com/@nalydadad/概述-gatt-藍芽傳輸-9fa218ce6022)
    /// - Parameters:
    ///   - UUIDString: String
    ///   - options: [String : Any]?
    /// - Returns: Bool
    func connect(UUIDString: String, options: [String : Any]? = nil) -> UUID? {
        
        guard let peripheral = peripheral(UUIDString: UUIDString) else { return nil }
        
        connect(peripheral: peripheral, options: options)
        return peripheral.identifier
    }
    
    /// [藍牙設備斷開連接](http://www.wowotech.net/bluetooth/ble_stack_overview.html)
    /// - Parameter UUID: UUID
    /// - Returns: CBPeripheral?
    func disconnect(UUID: UUID) -> UUID? {
        
        guard let peripheral = peripheral(UUID: UUID) else { return nil }
        
        centralManager.cancelPeripheralConnection(peripheral)
        return peripheral.identifier
    }
    
    /// [藍牙設備斷開連接](http://www.sunyouqun.com/2017/04/understand-ble-5-stack-generic-attribute-profile-layer/)
    /// - Parameter UUID: UUID
    /// - Returns: CBPeripheral?
    func disconnect(UUIDString: String) -> UUID? {
        
        guard let peripheral = peripheral(UUIDString: UUIDString) else { return nil }
        
        centralManager.cancelPeripheralConnection(peripheral)
        return peripheral.identifier
    }
}

// MARK: - CBCentralManagerDelegate
extension WWBluetoothManager: CBCentralManagerDelegate {}

// MARK: - CBCentralManagerDelegate
public extension WWBluetoothManager {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        centralManagerDidUpdateStateAction(with: central)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        centralManagerAction(with: central, didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
    }
}

// MARK: - CBCentralManagerDelegate
public extension WWBluetoothManager {
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        centralManagerAction(with: central, didConnect: peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        centralManagerAction(with: central, didFailToConnect: peripheral, error: error)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        centralManagerAction(with: central, didDisconnectPeripheral: peripheral, error: error)
    }
}

// MARK: - CBPeripheralDelegate
extension WWBluetoothManager: CBPeripheralDelegate {}

// MARK: - CBPeripheralDelegate
public extension WWBluetoothManager {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheralAction(with: peripheral, didDiscoverServices: error)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        peripheralAction(with: peripheral, didDiscoverCharacteristicsFor: service, error: error)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        peripheralAction(with: peripheral, didDiscoverDescriptorsFor: characteristic, error: error)
    }
}

// MARK: - CBPeripheralDelegate
public extension WWBluetoothManager {
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        peripheralAction(with: peripheral, didUpdateValueFor: characteristic, error: error)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        peripheralAction(with: peripheral, didUpdateNotificationStateFor: characteristic, error: error)
    }
}

// MARK: - CBPeripheralDelegate
public extension WWBluetoothManager {
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        peripheralAction(with: peripheral, didModifyServices: invalidatedServices)
    }
}

// MARK: - 小工具
private extension WWBluetoothManager {
    
    /// 處理藍牙中心的更新狀態 (開 / 開 / 重開 / …)
    /// - Parameter central: CBCentralManager
    func centralManagerDidUpdateStateAction(with central: CBCentralManager) {
        
        switch central.state {
        case .poweredOn: centralManager?.scanForPeripherals(withServices: nil, options: nil)
        case .poweredOff: break
        case .resetting: break
        case .unauthorized: break
        case .unsupported: break
        case .unknown: break
        @unknown default: break
        }
        
        delegate?.updateState(manager: self, state: central.state)
    }
    
    /// 發現新設備的處理
    /// - Parameters:
    ///   - central: CBCentralManager
    ///   - peripheral: CBPeripheral
    ///   - advertisementData: [String: Any]
    ///   - RSSI: NSNumber
    func centralManagerAction(with central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        
        let newPeripheralInfo: PeripheralInformation = (UUID: peripheral.identifier, name: peripheral.name, advertisementData: advertisementData, RSSI: RSSI)
        
        peripherals.insert(peripheral)
        delegate?.discoveredPeripherals(manager: self, peripherals: peripherals, newPeripheralInformation: newPeripheralInfo)
    }
    
    /// 已經連上的設備處理
    /// - Parameters:
    ///   - central: CBCentralManager
    ///   - peripheral: CBPeripheral
    func centralManagerAction(with central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        delegate?.didConnectPeripheral(manager: self, result: .success(.didConnect(peripheral.identifier)))
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
    
    /// 連線錯誤的處理
    /// - Parameters:
    ///   - central: CBCentralManager
    ///   - peripheral: CBPeripheral
    ///   - error: Error?
    func centralManagerAction(with central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
        if let error = error {
            delegate?.didConnectPeripheral(manager: self, result: .failure(PeripheralError.connect(peripheral.identifier, name: peripheral.name, error: .centralManager(error))))
        }
    }
    
    /// 斷開連線的處理
    /// - Parameters:
    ///   - central: CBCentralManager
    ///   - peripheral: CBPeripheral
    ///   - error: Error?
    func centralManagerAction(with central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        if let error = error {
            delegate?.didConnectPeripheral(manager: self, result: .failure(PeripheralError.connect(peripheral.identifier, name: peripheral.name, error: .centralManager(error))))
        }
        
        delegate?.didConnectPeripheral(manager: self, result: .success(.didDisconnect(peripheral.identifier)))
    }
    
    
    /// 發現服務時的處理
    /// - Parameters:
    ///   - peripheral: CBPeripheral
    ///   - error: Error?
    func peripheralAction(with peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        if let error = error { delegate?.didDiscoverPeripheral(manager: self, result: .failure(.discover(peripheral.identifier, name: peripheral.name, error: .services(error)))); return }
        
        let info: DiscoverServicesInformation = (UUID: peripheral.identifier, name: peripheral.name, peripheral: peripheral)
        delegate?.didDiscoverPeripheral(manager: self, result: .success(.services(info)))
    }
    
    /// 發現特徵值的處理
    /// - Parameters:
    ///   - peripheral: CBPeripheral
    ///   - service: CBService
    ///   - error: Error?
    func peripheralAction(with peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        if let error = error { delegate?.didDiscoverPeripheral(manager: self, result: .failure(.discover(peripheral.identifier, name: peripheral.name, error: .characteristics(error)))); return }
        
        let info: DiscoverCharacteristics = (UUID: peripheral.identifier, name: peripheral.name, service: service)
        delegate?.didDiscoverPeripheral(manager: self, result: .success(.characteristics(info)))
    }
    
    /// 發現敘述的處理
    /// - Parameters:
    ///   - peripheral: CBPeripheral
    ///   - characteristic: CBCharacteristic
    ///   - error: Error?
    func peripheralAction(with peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        
        if let error = error { delegate?.didDiscoverPeripheral(manager: self, result: .failure(.discover(peripheral.identifier, name: peripheral.name, error: .descriptors(error)))); return }
        
        let info: DiscoverDescriptors = (UUID: peripheral.identifier, name: peripheral.name, characteristic: characteristic)
        delegate?.didDiscoverPeripheral(manager: self, result: .success(.descriptors(info)))
    }
    
    /// 更新特徵值的處理
    /// - Parameters:
    ///   - peripheral: CBPeripheral
    ///   - characteristic: CBCharacteristic
    ///   - error: Error?
    func peripheralAction(with peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        if let error = error { delegate?.didUpdatePeripheral(manager: self, result: .failure(.discover(peripheral.identifier, name: peripheral.name, error: .characteristics(error)))); return }
        
        let _info: UpdateValueInformation = (UUID: peripheral.identifier, characteristic: characteristic)
        let info = updatePeripheral(with: .value(_info))
        
        delegate?.didUpdatePeripheral(manager: self, result: .success(info))
    }
    
    /// 更新通知狀態的處理
    /// - Parameters:
    ///   - peripheral: CBPeripheral
    ///   - characteristic: characteristic
    ///   - error: Error?
    func peripheralAction(with peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        if let error = error { delegate?.didUpdatePeripheral(manager: self, result: .failure(.discover(peripheral.identifier, name: peripheral.name, error: .characteristics(error)))); return }
        
        let _info: UpdateValueInformation = (UUID: peripheral.identifier, characteristic: characteristic)
        let info = updatePeripheral(with: .notificationState(_info))

        delegate?.didUpdatePeripheral(manager: self, result: .success(info))
    }
    
    /// 更動服務的處理
    /// - Parameters:
    ///   - peripheral: CBPeripheral
    ///   - invalidatedServices: [CBService]
    public func peripheralAction(with peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        
        let info: ModifyServicesInformation = (UUID: peripheral.identifier, invalidatedServices: invalidatedServices)
        delegate?.didModifyServices(manager: self, information: info)
    }
}

// MARK: - 小工具
private extension WWBluetoothManager {
    
    /// 跟據類型取得設定回傳的資料
    /// - Parameters:
    ///   - updateType: WWBluetoothManager.UpdateType
    /// - Returns: WWBluetoothManager.PeripheralValueInformation
    func updatePeripheral(with updateType: (UpdateType)) -> PeripheralValueInformation {
        
        let valueInfo: WWBluetoothManager.PeripheralValueInformation
        
        switch updateType {
        case .notificationState(let info): valueInfo = updatePeripheralNotificationState(info)
        case .value(let info): valueInfo = updatePeripheralValue(info)
        }
        
        return valueInfo
    }
    
    /// 處理設備數值事件 (.read)
    /// - Parameters:
    ///   - info: WWBluetoothManager.UpdateValueInformation
    func updatePeripheralValue(_ info: UpdateValueInformation) -> PeripheralValueInformation {
        
        let characteristic = info.characteristic
        let info: PeripheralValueInformation = (peripheralId: info.UUID, characteristicId: characteristic.uuid, characteristicValue: characteristic.value)
        
        return info
    }
    
    /// 處理設備通知事件 (.notify)
    /// - Parameters:
    ///   - info: WWBluetoothManager.UpdateNotificationStateInformation
    func updatePeripheralNotificationState(_ info: UpdateNotificationStateInformation) -> PeripheralValueInformation {
        
        let characteristic = info.characteristic
        let info: PeripheralValueInformation = (peripheralId: info.UUID, characteristicId: characteristic.uuid, characteristicValue: characteristic.value)
        
        return info
    }
}


