//
//  ViewController.swift
//  Example
//
//  Created by William.Weng on 2024/1/1.
//

import UIKit
import CoreBluetooth

// MARK: - WWBluetoothPeripheralManagerDelegate
public protocol WWBluetoothPeripheralManagerDelegate: AnyObject {
    
    func managerIsReady(manager: WWBluetoothPeripheralManager, MTU: Int)    // 裝置準備完成
    func receiveValue(manager: WWBluetoothPeripheralManager, value: Data)   // 接到的資訊
    func errorMessage(manager: WWBluetoothPeripheralManager, error: Error)  // 錯誤訊息
}

// MARK: - WWBluetoothPeripheralManager
open class WWBluetoothPeripheralManager: NSObject {
    
    public enum MyError: Error {
        case notPowerOn(state: CBManagerState)  // 藍牙未打開
        case noValue                            // 沒有傳送有效數值
    }
    
    let serviceUUID = UUID().uuidString
    let characteristicUUID = UUID().uuidString
    
    weak var managerDelegate: WWBluetoothPeripheralManagerDelegate?
    
    private var sendDataIndex: Int = 0
    private var isSendingBOM: Bool = false
    private var isSendingEOM: Bool = false
    private var sendingData: Data?
    private var MTU = 64
    private var BOM = "BOM"
    private var EOM = "EOM"
    private var encoding: String.Encoding = .utf8
    private var peripheralName: String?
    private var peripheralManager: CBPeripheralManager?
    private var transferCharacteristic: CBMutableCharacteristic?
    
    private override init() { super.init() }
    
    /// 自定義初始化
    /// - Parameters:
    ///   - managerDelegate: WWBluetoothPeripheralManagerDelegate?
    ///   - peripheralName: String?
    ///   - queue: dispatch_queue_t?
    private convenience init(managerDelegate: WWBluetoothPeripheralManagerDelegate?, peripheralName: String?, queue: dispatch_queue_t?) {
        self.init()
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: queue)
        self.peripheralName = peripheralName
        self.managerDelegate = managerDelegate
    }
    
    deinit {
        managerDelegate = nil
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
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        peripheralManagerAction(with: peripheral, central: central, didSubscribeTo: characteristic)
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        sendFile(with: MTU, BOM: BOM, EOM: EOM, using: encoding)
    }
}

// MARK: - 公開函式 (static)
public extension WWBluetoothPeripheralManager {
    
    /// [建立新WWBluetoothPeripheralManager](https://www.cnblogs.com/iini/p/12334646.html)
    /// - Parameters:
    ///   - managerDelegate: WWBluetoothPeripheralManagerDelegate?
    ///   - peripheralName: String?
    ///   - queue: dispatch_queue_t?
    /// - Returns: WWBluetoothPeripheralManager
    static func build(managerDelegate: WWBluetoothPeripheralManagerDelegate? = nil, peripheralName: String? = nil, queue: dispatch_queue_t? = nil) -> WWBluetoothPeripheralManager {
        return WWBluetoothPeripheralManager(managerDelegate: managerDelegate, peripheralName: peripheralName, queue: queue)
    }
}

// MARK: - 公開函式 (function)
public extension WWBluetoothPeripheralManager {
    
    /// [發送文字](https://blog.csdn.net/weixin_35755389/article/details/53966240)
    /// - Parameters:
    ///   - text: String?
    ///   - BOM: String
    ///   - EOM: String
    ///   - encoding: String.Encoding
    ///   - isLossyConversion: Bool
    /// - Returns: Bool
    func sendText(_ text: String?, BOM: String = "BOM", EOM: String = "EOM", using encoding: String.Encoding = .utf8, isLossyConversion: Bool = false) -> Bool {
        
        guard let text = text,
              let data = text._data(using: encoding, isLossyConversion: isLossyConversion)
        else {
            return false
        }
        
        return sendData(data, BOM: BOM, EOM: EOM, using: encoding)
    }
    
    /// [發送資料](harumi.sakura.ne.jp/wordpress/2019/06/10/cbperipheralのadvertisementdataについて/)
    /// - Parameters:
    ///   - data: Data
    ///   - BOM: String
    ///   - EOM: String
    ///   - encoding: String.Encoding
    /// - Returns: Bool
    func sendData(_ data: Data, BOM: String = "BOM", EOM: String = "EOM", using encoding: String.Encoding = .utf8) -> Bool {
        
        self.encoding = encoding
        self.BOM = BOM
        self.EOM = EOM
        
        sendDataIndex = 0
        isSendingBOM = false
        isSendingEOM = false
        sendingData = nil
        
        if (data.count > MTU) {
            isSendingBOM = true
            sendingData = data
            return sendFile(with: MTU, BOM: BOM, EOM: EOM, using: encoding)
        }
        
        return sendData(with: data)
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
    
    /// [設定取得的MTU - Maximum Transmission Unit](https://zh.wikipedia.org/zh-tw/最大传输单元)
    /// - Parameter central: CBCentral
    func mtuSetting(with central: CBCentral) {
        MTU = central.maximumUpdateValueLength
        managerDelegate?.managerIsReady(manager: self, MTU: MTU)
    }
    
    /// 發送資料 (小量的)
    /// - Parameter data: Data
    /// - Returns: Bool
    func sendData(with data: Data) -> Bool {
        
        guard let transferCharacteristic = transferCharacteristic,
              let peripheralManager = peripheralManager
        else {
            return false
        }
        
        return peripheralManager.updateValue(data, for: transferCharacteristic, onSubscribedCentrals: nil)
    }
    
    /// 發送檔案資料 (大量的)
    /// - Parameters:
    ///   - MTU: Int
    ///   - BOM: String
    ///   - EOM: String
    ///   - encoding: String.Encoding
    /// - Returns: Bool
    func sendFile(with MTU: Int, BOM: String, EOM: String, using encoding: String.Encoding) -> Bool {
        
        guard let transferCharacteristic = transferCharacteristic,
              let peripheralManager = peripheralManager,
              let dataBOM = BOM.data(using: encoding),
              let dataEOM = EOM.data(using: encoding)
        else {
            return false
        }
        
        if isSendingBOM { _ = sendBOMAction(dataBOM, peripheralManager: peripheralManager, transferCharacteristic: transferCharacteristic) }
        if isSendingEOM { return sendEOMAction(dataEOM, peripheralManager: peripheralManager, transferCharacteristic: transferCharacteristic) }
        
        guard let sendingData = sendingData,
              sendDataIndex < sendingData.count
        else {
            return false
        }
        
        var isSendedChunkData = true
        
        while isSendedChunkData {
            
            var sendAmount = sendingData.count - sendDataIndex
            
            if sendAmount > MTU { sendAmount = MTU }
            
            let sendRange = sendDataIndex..<sendDataIndex + sendAmount
            let chunkData = sendingData.subdata(in: sendRange)
            
            isSendedChunkData = peripheralManager.updateValue(chunkData, for: transferCharacteristic, onSubscribedCentrals: nil)
            if !isSendedChunkData { return isSendedChunkData }
            
            sendDataIndex += sendAmount
            print("\(sendDataIndex) of \(sendingData.count)")
            
            if sendDataIndex >= sendingData.count {
                isSendingEOM = true
                return sendEOMAction(dataEOM, peripheralManager: peripheralManager, transferCharacteristic: transferCharacteristic)
            }
        }
        
        return true
    }
}

// MARK: - 小工具
private extension WWBluetoothPeripheralManager {
    
    /// 裝置開始更新狀態的動作
    /// - Parameter peripheral: CBPeripheralManager
    func peripheralManagerDidUpdateStateAction(with peripheral: CBPeripheralManager) {
        
        if (peripheral.state != .poweredOn) { managerDelegate?.errorMessage(manager: self, error: MyError.notPowerOn(state: peripheral.state)); return }
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
                managerDelegate?.receiveValue(manager: self, value: value)
                hasValue = true
            }
        }
        
        if (!hasValue) { managerDelegate?.errorMessage(manager: self, error: MyError.noValue) }
    }
    
    /// 被訂閱的處理
    /// - Parameters:
    ///   - peripheral: CBPeripheralManager
    ///   - central: CBCentral
    ///   - characteristic: CBCharacteristic
    func peripheralManagerAction(with peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        mtuSetting(with: central)
    }
    
    /// 寄送開頭標記的處理
    /// - Parameters:
    ///   - dataBOM: Data
    ///   - peripheralManager: CBPeripheralManager
    ///   - transferCharacteristic: CBMutableCharacteristic
    /// - Returns: Bool
    func sendBOMAction(_ dataBOM: Data, peripheralManager: CBPeripheralManager, transferCharacteristic: CBMutableCharacteristic) -> Bool {
                
        let isSendedBOM = peripheralManager.updateValue(dataBOM, for: transferCharacteristic, onSubscribedCentrals: nil) ?? false
        if isSendedBOM { isSendingBOM = false }
        
        return isSendedBOM
    }
    
    /// 寄送結束標記的處理
    /// - Parameters:
    ///   - dataBOM: Data
    ///   - peripheralManager: CBPeripheralManager
    ///   - transferCharacteristic: CBMutableCharacteristic
    /// - Returns: Bool
    func sendEOMAction(_ dataEOM: Data, peripheralManager: CBPeripheralManager, transferCharacteristic: CBMutableCharacteristic) -> Bool {
        
        let isSendedEOM = peripheralManager.updateValue(dataEOM, for: transferCharacteristic, onSubscribedCentrals: nil) ?? false
        if isSendedEOM { isSendingBOM = false }
        
        return isSendedEOM
    }
}
