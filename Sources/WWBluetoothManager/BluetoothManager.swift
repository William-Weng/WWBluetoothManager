//
//  BluetoothManager.swift
//  WWBluetoothManager
//
//  Created by William.Weng on 2023/11/29.
//  ~/Library/Caches/org.swift.swiftpm/

import UIKit
import CoreBluetooth
import WWPrint

// MARK: - WWBluetoothManager
open class WWBluetoothManager: NSObject {

    public static let shared = WWBluetoothManager()
    
    private var peripherals: Set<CBPeripheral> = []
    private var centralManager: CBCentralManager!
    private var delegate: WWBluetoothManagerDelegate?
    
    private override init() {}
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
    
    /// 解析特徵值設定 => ["broadcast", "read"]
    /// - Parameter properties: CBCharacteristicProperties
    /// - Returns: [String]
    func parseProperties(_ properties: CBCharacteristicProperties) -> [String] {
        return properties._parse()
    }
    
    /// 某特徵值的文字訊息
    /// - Parameter properties: CBCharacteristicProperties
    /// - Returns: String?
    func propertiesMessage(_ properties: CBCharacteristicProperties) -> String? {
        return properties._message()
    }
    
    /// [取得特徵值的全部設定值 => [1: "broadcast"]](https://blog.csdn.net/RazilFelix/article/details/68776794)
    /// - Returns: [UInt: CBCharacteristicProperties]
    func properties() -> [UInt: CBCharacteristicProperties] {
        return CBCharacteristicProperties._dictionary()
    }
}

// MARK: - CBCentralManagerDelegate
extension WWBluetoothManager: CBCentralManagerDelegate {
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
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
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        
        let newPeripheralInfo: PeripheralInformation = (UUID: peripheral.identifier, name: peripheral.name, advertisementData: advertisementData, RSSI: RSSI)
        peripherals.insert(peripheral)
        delegate?.discoveredPeripherals(manager: self, peripherals: peripherals, newPeripheralInformation: newPeripheralInfo)
    }
}

// MARK: - CBCentralManagerDelegate
extension WWBluetoothManager {
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        delegate?.didConnectPeripheral(manager: self, result: .success(peripheral.identifier))
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
        if let error = error {
            delegate?.didConnectPeripheral(manager: self, result: .failure(PeripheralError.connect(peripheral.identifier, name: peripheral.name, error: .centralManager(error))))
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        if let error = error {
            delegate?.didConnectPeripheral(manager: self, result: .failure(PeripheralError.connect(peripheral.identifier, name: peripheral.name, error: .centralManager(error))))
        }
    }
}

// MARK: - CBPeripheralDelegate
extension WWBluetoothManager: CBPeripheralDelegate {
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        if let error = error { delegate?.didDiscoverPeripheral(manager: self, result: .failure(.discover(peripheral.identifier, name: peripheral.name, error: .services(error)))); return }
        
        let info: DiscoverServicesInformation = (UUID: peripheral.identifier, name: peripheral.name, peripheral: peripheral)
        delegate?.didDiscoverPeripheral(manager: self, result: .success(.services(info)))
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        if let error = error { delegate?.didDiscoverPeripheral(manager: self, result: .failure(.discover(peripheral.identifier, name: peripheral.name, error: .characteristics(error)))); return }
        
        let info: DiscoverCharacteristics = (UUID: peripheral.identifier, name: peripheral.name, service: service)
        delegate?.didDiscoverPeripheral(manager: self, result: .success(.characteristics(info)))
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        
        if let error = error { delegate?.didDiscoverPeripheral(manager: self, result: .failure(.discover(peripheral.identifier, name: peripheral.name, error: .descriptors(error)))); return }
        
        let info: DiscoverDescriptors = (UUID: peripheral.identifier, name: peripheral.name, characteristic: characteristic)
        delegate?.didDiscoverPeripheral(manager: self, result: .success(.descriptors(info)))
    }
}

// MARK: - CBPeripheralDelegate
extension WWBluetoothManager {
        
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        if let error = error { delegate?.didUpdatePeripheral(manager: self, result: .failure(.discover(peripheral.identifier, name: peripheral.name, error: .characteristics(error)))); return }
        
        let _info: UpdateValueInformation = (UUID: peripheral.identifier, characteristic: characteristic)
        let info = updatePeripheral(with: .value(_info))
        
        delegate?.didUpdatePeripheral(manager: self, result: .success(info))
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
      
        if let error = error { delegate?.didUpdatePeripheral(manager: self, result: .failure(.discover(peripheral.identifier, name: peripheral.name, error: .characteristics(error)))); return }
        
        let _info: UpdateValueInformation = (UUID: peripheral.identifier, characteristic: characteristic)
        let info = updatePeripheral(with: .notificationState(_info))

        delegate?.didUpdatePeripheral(manager: self, result: .success(info))
    }
}

// MARK: - CBPeripheralDelegate
extension WWBluetoothManager {
    
    public func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        
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


