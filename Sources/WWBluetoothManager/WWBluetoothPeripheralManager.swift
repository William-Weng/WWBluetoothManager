//
//  ViewController.swift
//  Example
//
//  Created by William.Weng on 2024/1/1.
//

import UIKit
import CoreBluetooth

// MARK: - WWBluetoothPeripheralManager
open class WWBluetoothPeripheralManager: NSObject {
    
    let serviceUUID = UUID().uuidString
    let characteristicUUID = UUID().uuidString
    
    public enum MyError: Error {
        case notPowerOn(state: CBManagerState)  // 藍牙未打開
        case noValue                            // 沒有傳送有效數值
    }
    
    private var peripheralName: String?
    private var peripheralManager: CBPeripheralManager?
    private var transferCharacteristic: CBMutableCharacteristic?
    
    private var errorBlock: ((MyError) -> Void)?
    private var receiveValueBlock: ((Data) -> Void)?
    
    private override init() { super.init() }
    
    private convenience init(peripheralName: String?, queue: dispatch_queue_t?) {
        
        self.init()
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: queue)
        self.peripheralName = peripheralName
    }
    
    deinit {
        errorBlock = nil
        receiveValueBlock = nil
    }
}

// MARK: - CBPeripheralManagerDelegate
extension WWBluetoothPeripheralManager: CBPeripheralManagerDelegate {}

// MARK: - CBPeripheralManagerDelegate
public extension WWBluetoothPeripheralManager {
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        peripheralManagerDidUpdateStateAction(with: peripheral)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        peripheralManagerAction(with: peripheral, didReceiveWrite: requests)
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {}
}

// MARK: - 公開函式 (static)
public extension WWBluetoothPeripheralManager {
    
    /// [建立新WWBluetoothPeripheralManager](https://www.cnblogs.com/iini/p/12334646.html)
    /// - Parameters:
    ///   - name: String?
    ///   - queue: dispatch_queue_t?
    /// - Returns: WWBluetoothPeripheralManager
    static func build(peripheralName: String? = nil, queue: dispatch_queue_t? = nil) -> WWBluetoothPeripheralManager {
        return WWBluetoothPeripheralManager(peripheralName: peripheralName, queue: queue)
    }
}

// MARK: - 公開函式 (function)
public extension WWBluetoothPeripheralManager {
    
    /// [發送資料](harumi.sakura.ne.jp/wordpress/2019/06/10/cbperipheralのadvertisementdataについて/)
    /// - Parameter data: Data
    /// - Returns: Bool
    func sendData(_ data: Data) -> Bool {
        
        guard let transferCharacteristic = transferCharacteristic,
              let peripheralManager = peripheralManager
        else {
            return false
        }
        
        return peripheralManager.updateValue(data, for: transferCharacteristic, onSubscribedCentrals: nil)
    }
    
    /// [發送文字](https://blog.csdn.net/weixin_35755389/article/details/53966240)
    /// - Parameters:
    ///   - text: String?
    ///   - encoding: String.Encoding
    ///   - isLossyConversion: Bool
    /// - Returns: Bool
    func sendText(_ text: String?, using encoding: String.Encoding = .utf8, isLossyConversion: Bool = false) -> Bool {
        
        guard let text = text,
              let data = text._data(using: encoding, isLossyConversion: isLossyConversion)
        else {
            return false
        }
        
        return sendData(data)
    }
    
    /// 處理接收到的數據
    /// - Parameter dataBlock: ((Data) -> Void)
    func receivedValueHandler(_ receiveValueBlock: @escaping ((Data) -> Void)) {
        self.receiveValueBlock = receiveValueBlock
    }
    
    /// 處理錯誤訊息
    /// - Parameter errorBlock: ((Error) -> Void)
    func errorMessageHandler(_ errorBlock: @escaping ((MyError) -> Void)) {
        self.errorBlock = errorBlock
    }
}

// MARK: - 小工具
private extension WWBluetoothPeripheralManager {
    
    /// 開始廣播 (設定功能 / 權限)
    func startAdvertising() {
        
        let transferCharacteristic = CBMutableCharacteristic(type: CBUUID(string: characteristicUUID), properties: [.notify, .read, .write], value: nil, permissions: [.readable, .writeable])
        let transferService = CBMutableService(type: CBUUID(string: serviceUUID), primary: true)
        let advertisementData: [String: Any] = [CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: serviceUUID)], CBAdvertisementDataLocalNameKey: peripheralName ?? "<WWBluetoothPeripheralManager>"]
        
        self.transferCharacteristic = transferCharacteristic
        transferService.characteristics = [transferCharacteristic]
        
        peripheralManager?.add(transferService)
        peripheralManager?.startAdvertising(advertisementData)
    }
        
    /// 裝置開始更新狀態的動作
    /// - Parameter peripheral: CBPeripheralManager
    func peripheralManagerDidUpdateStateAction(with peripheral: CBPeripheralManager) {
        if (peripheral.state != .poweredOn) { errorBlock?(MyError.notPowerOn(state: peripheral.state)); return }
        startAdvertising()
    }
    
    /// 處理接收到的數據
    /// - Parameters:
    ///   - peripheral: CBPeripheralManager
    ///   - requests: [CBATTRequest]
    func peripheralManagerAction(with peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        
        var hasValue = false
        
        for request in requests {
            
            if (request.characteristic.uuid == transferCharacteristic?.uuid) { continue }
            
            transferCharacteristic?.value = request.value
            peripheralManager?.respond(to: request, withResult: .success)
                
            if let value = request.value {
                receiveValueBlock?(value)
                hasValue = true
            }
        }
        
        if (!hasValue) { errorBlock?(MyError.noValue) }
    }
}
