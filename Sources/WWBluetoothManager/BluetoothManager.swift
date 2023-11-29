//
//  BluetoothManager.swift
//  WWBluetoothManager
//
//  Created by William.Weng on 2023/9/11.
//  ~/Library/Caches/org.swift.swiftpm/

import UIKit
import CoreBluetooth

/// 藍牙管理的Delegate
public protocol WWBluetoothManagerDelegate {
    
    /// 手機藍牙的更新狀態
    /// - Parameters:
    ///   - manager: WWBluetoothManager
    ///   - state: CBManagerState
    func updateState(manager: WWBluetoothManager, state: CBManagerState)
    
    /// 搜尋到的週邊設備 (不重複)
    /// - Parameters:
    ///   - manager: WWBluetoothManager
    ///   - peripherals: Set<CBPeripheral>
    ///   - newPeripheralInformation: WWBluetoothManager.PeripheralInformation
    func discoveredPeripherals(manager: WWBluetoothManager, peripherals: Set<CBPeripheral>, newPeripheralInformation: WWBluetoothManager.PeripheralInformation)
    
    /// 取得剛連上設備的資訊
    /// - Parameters:
    ///   - manager: WWBluetoothManager
    ///   - result: Result<UUID, WWBluetoothManager.PeripheralError>
    func didConnectPeripheral(manager: WWBluetoothManager, result: Result<UUID, WWBluetoothManager.PeripheralError>)
    
    /// 處理已經連上設備的Services / Characteristics / Descriptors
    /// - Parameters:
    ///   - manager: WWBluetoothManager
    ///   - result: Result<WWBluetoothManager.DiscoverValueType, WWBluetoothManager.PeripheralError>
    func didDiscoverPeripheral(manager: WWBluetoothManager, result: Result<WWBluetoothManager.DiscoverValueType, WWBluetoothManager.PeripheralError>)
    
    /// 週邊設備數值相關的功能
    /// - Parameters:
    ///   - manager: WWBluetoothManager
    ///   - result: Result<WWBluetoothManager.UpdateType, WWBluetoothManager.PeripheralError>
    func didUpdatePeripheral(manager: WWBluetoothManager, result: Result<WWBluetoothManager.UpdateType, WWBluetoothManager.PeripheralError>)
}

// MARK: - WWBluetoothManager
open class WWBluetoothManager: NSObject {
    
    public typealias PeripheralInformation = (UUID: UUID, name: String?, advertisementData: [String : Any], RSSI: NSNumber)
    public typealias DiscoverServicesInformation = (UUID: UUID, name: String?, services: [CBService]?)
    public typealias DiscoverCharacteristics = (UUID: UUID, name: String?, characteristics: [CBCharacteristic]?)
    public typealias DiscoverDescriptors = (UUID: UUID, name: String?, descriptors: [CBDescriptor]?)
    public typealias UpdateValueInformation = (UUID: UUID, name: String?, data: Data?)
    public typealias UpdateNotificationStateInformation = (UUID: UUID, name: String?, data: Data?)
    
    /// 搜尋數值的類型
    public enum DiscoverValueType {
        case services(_ info: DiscoverServicesInformation)
        case characteristics(_ info: DiscoverCharacteristics)
        case descriptors(_ info: DiscoverDescriptors)
    }
    
    /// 更新數值的類型
    public enum UpdateType {
        case value(_ info: UpdateValueInformation)
        case notificationState(_ info: UpdateNotificationStateInformation)
    }

    /// 相關錯誤
    public enum PeripheralError: Error {
        case connect(_ UUID: UUID, name: String?, error: ConnectError)
        case discover(_ UUID: UUID, name: String?, error: DiscoverError)
        case update(_ UUID: UUID, name: String?, error: UpdateError)
    }
    
    /// 連接管理中心錯誤
    public enum ConnectError {
        case centralManager(_ error: Error)
    }
    
    /// 設備搜尋錯誤
    public enum DiscoverError {
        case services(_ error: Error)
        case characteristics(_ error: Error)
        case descriptors(_ error: Error)
    }
    
    /// 設備傳值錯誤
    public enum UpdateError {
        case value(_ error: Error)
        case notificationState(_ error: Error)
    }

    public static let shared = WWBluetoothManager()

    private var peripherals: Set<CBPeripheral> = []
    private var centralManager: CBCentralManager!
    private var delegate: WWBluetoothManagerDelegate?
    
    private override init() {}
}

/// MARK: - 公開函式 (0)
public extension WWBluetoothManager {
    
    /// 建立新BluetoothManager
    /// - Returns: WWBluetoothManager
    static func build() -> WWBluetoothManager { return WWBluetoothManager() }
}

/// MARK: - 公開函式 (1)
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
    
    /// [停止掃瞄](https://bbs.huaweicloud.com/blogs/354107)
    func stopScan() {
        centralManager.stopScan()
    }
}

/// MARK: - 公開函式 (2)
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
    
    /// 藍牙設備斷開連接
    /// - Parameter UUID: UUID
    /// - Returns: CBPeripheral?
    func disconnect(UUID: UUID) -> UUID? {
        
        guard let peripheral = peripheral(UUID: UUID) else { return nil }
        
        centralManager.cancelPeripheralConnection(peripheral)
        return peripheral.identifier
    }
    
    /// 藍牙設備斷開連接
    /// - Parameter UUID: UUID
    /// - Returns: CBPeripheral?
    func disconnect(UUIDString: String) -> UUID? {
        
        guard let peripheral = peripheral(UUIDString: UUIDString) else { return nil }
        
        centralManager.cancelPeripheralConnection(peripheral)
        return peripheral.identifier
    }
}

// MARK: - CBCentralManagerDelegate
extension WWBluetoothManager: CBCentralManagerDelegate {
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        delegate?.updateState(manager: self, state: central.state)
        
        switch central.state {
        case .poweredOn: centralManager?.scanForPeripherals(withServices: nil, options: nil)
        case .poweredOff: break
        case .resetting: break
        case .unauthorized: break
        case .unsupported: break
        case .unknown: break
        @unknown default: break
        }
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
        
        let info: DiscoverServicesInformation = (UUID: peripheral.identifier, name: peripheral.name, services: peripheral.services)
        delegate?.didDiscoverPeripheral(manager: self, result: .success(.services(info)))
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        if let error = error { delegate?.didDiscoverPeripheral(manager: self, result: .failure(.discover(peripheral.identifier, name: peripheral.name, error: .characteristics(error)))); return }
        
        let info: DiscoverCharacteristics = (UUID: peripheral.identifier, name: peripheral.name, characteristics: service.characteristics)
        delegate?.didDiscoverPeripheral(manager: self, result: .success(.characteristics(info)))
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        
        if let error = error { delegate?.didDiscoverPeripheral(manager: self, result: .failure(.discover(peripheral.identifier, name: peripheral.name, error: .descriptors(error)))); return }
        
        let info: DiscoverDescriptors = (UUID: peripheral.identifier, name: peripheral.name, descriptors: characteristic.descriptors)
        delegate?.didDiscoverPeripheral(manager: self, result: .success(.descriptors(info)))
    }
}

// MARK: - CBPeripheralDelegate
extension WWBluetoothManager {
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        if let error = error { delegate?.didUpdatePeripheral(manager: self, result: .failure(.discover(peripheral.identifier, name: peripheral.name, error: .characteristics(error)))); return }
        
        let info: UpdateValueInformation = (UUID: peripheral.identifier, name: peripheral.name, data: characteristic.value)
        delegate?.didUpdatePeripheral(manager: self, result: .success(.value(info)))
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
      
        if let error = error { delegate?.didUpdatePeripheral(manager: self, result: .failure(.discover(peripheral.identifier, name: peripheral.name, error: .characteristics(error)))); return }
        
        let info: UpdateNotificationStateInformation = (UUID: peripheral.identifier, name: peripheral.name, data: characteristic.value)
        delegate?.didUpdatePeripheral(manager: self, result: .success(.notificationState(info)))
    }
}
