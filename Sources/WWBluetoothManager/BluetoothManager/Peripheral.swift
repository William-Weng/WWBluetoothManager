//
//  Peripheral.swift
//  WWBluetoothManager
//
//  Created by William.Weng on 2026/5/7.
//
//  iPhone (WWBluetoothManager.Peripheral)
//  └── Service FF10 (檔案傳輸服務)
//      ├── Characteristic FF11 (控制通道)  ← write + notify
//      └── Characteristic FF12 (資料通道)  ← write + notify

import Foundation
import CoreBluetooth

// MARK: - BLE Peripheral 管理器
public extension WWBluetoothManager {
    
    /// 用來把目前裝置模擬成一個可被 Central 掃描、連線與操作的 BLE Peripheral
    final class Peripheral: NSObject {
        
        public weak var delegate: PeripheralDelegate?                               // Peripheral 事件委派
        
        public var state: CBManagerState { peripheralManager.state }                // 目前藍牙 PeripheralManager 的狀態

        public private(set) var controlCharacteristic: CBMutableCharacteristic?     // 控制通道 characteristic => 通常用於接收或發送控制命令
        public private(set) var dataCharacteristic: CBMutableCharacteristic?        // 資料通道 characteristic => 通常用於實際傳送資料內容

        private var peripheralManager: CBPeripheralManager!                         // CoreBluetooth 原生的 PeripheralManager
        private var service: CBMutableService?                                      // 目前已建立並準備發布的 service
        
        /// 建立 Peripheral 物件 => 建立完成後，系統會很快透過 `peripheralManagerDidUpdateState(_:)` 回報當前藍牙狀態
        public override init() {
            super.init()
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        }
    }
}

// MARK: - 實現 CBPeripheralManagerDelegate
public extension WWBluetoothManager.Peripheral {
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        delegate?.peripheralManager(self, status: .stateUpdated(peripheral.state))
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        delegate?.peripheralManager(self, status: .serviceAdded(service, error: error))
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        delegate?.peripheralManager(self, status: .advertisingStarted(error))
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        delegate?.peripheralManager(self, status: .subscribed(central, characteristic))
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        delegate?.peripheralManager(self, status: .unsubscribed(central, characteristic))
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        delegate?.peripheralManager(self, status: .readyToUpdateSubscribers)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        delegate?.peripheralManager(self, status: .didReceiveReadRequest(request))
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        
        delegate?.peripheralManager(self, status: .writeRequests(requests))
        
        guard let firstRequest = requests.first else { return }
        peripheral.respond(to: firstRequest, withResult: .success)
    }
}

// MARK: - 公開函式
public extension WWBluetoothManager.Peripheral {
    
    /// 發布一個檔案傳輸用的 GATT Service
    /// - Parameters:
    ///   - serviceUUID: Service 的 UUID（整個檔案傳輸服務的容器）
    ///   - controlUUID: 控制用 Characteristic 的 UUID（例如 hello / ack / ready / finish）
    ///   - dataUUID: 資料用 Characteristic 的 UUID（例如檔案 chunk）
    /// 流程：
    /// 1. 確認 PeripheralManager 已經進入 `.poweredOn`
    /// 2. 停止目前廣播，避免舊的 advertising 狀態殘留
    /// 3. 移除先前已發布的 services，準備重新建立新的 GATT 結構
    /// 4. 建立 control / data 兩條 characteristic
    /// 5. 建立 primary service，並把 characteristic 掛上去
    /// 6. 呼叫 `add(service)` 正式發布；成功後會回到 `didAdd service` delegate
    func publish(serviceUUID: CBUUID, controlUUID: CBUUID, dataUUID: CBUUID) {
        
        guard peripheralManager.state == .poweredOn else { return }
        
        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()
        
        let service = prepareTransferService(serviceUUID: serviceUUID, controlUUID: controlUUID, dataUUID: dataUUID)
        peripheralManager.add(service)
    }
    
    /// 發布一個檔案傳輸用的 GATT Service
    /// - Parameters:
    ///   - serviceUUID: Service 的 UUID 類型（整個檔案傳輸服務的容器）
    ///   - controlUUID: 控制用 Characteristic 的 UUID 類型（例如 hello / ack / ready / finish）
    ///   - dataUUID: 資料用 Characteristic 的 UUID 類型（例如檔案 chunk）
    func publish(serviceType: WWBluetoothManager.UUIDType, controlType: WWBluetoothManager.UUIDType, dataType: WWBluetoothManager.UUIDType) {
        publish(serviceUUID: serviceType.cbUUID, controlUUID: controlType.cbUUID, dataUUID: dataType.cbUUID)
    }
    
    /// 開始廣播目前 Peripheral 的檔案傳輸服務 => 在 iOS 的 BLE peripheral advertising 中，最常使用的資料就是 local name 與 service UUIDs
    /// - Parameters:
    ///   - localName: 廣播時顯示的裝置名稱
    ///   - serviceUUIDs: 要放進廣告資料中的 service UUID 清單
    func startAdvertising(localName: String, serviceUUIDs: [CBUUID]) {
        
        guard peripheralManager.state == .poweredOn else { return }
        
        let advertisementData: [WWBluetoothManager.AdvertisementDataKey: Any] = [
            .localName: localName,
            .serviceUUIDs: serviceUUIDs
        ]
        
        peripheralManager.startAdvertising(advertisementData: advertisementData)
    }
    
    /// 開始廣播目前 Peripheral 的檔案傳輸服務 => 在 iOS 的 BLE peripheral advertising 中，最常使用的資料就是 local name 與 service UUIDs
    /// - Parameters:
    ///   - localName: 廣播時顯示的裝置名稱
    ///   - serviceTypes: 要放進廣告資料中的 service UUID 清單類型
    func startAdvertising(localName: String, serviceTypes: [WWBluetoothManager.UUIDType]) {
        
        let serviceUUIDs = serviceTypes.map { $0.cbUUID }
        startAdvertising(localName: localName, serviceUUIDs: serviceUUIDs)
    }
    
    /// 停止目前的 BLE advertising => 呼叫 `CBPeripheralManager.stopAdvertising()` 停止廣播
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        delegate?.peripheralManager(self, status: .advertisingStopped)
    }
    
    /// 移除目前已發布的所有 GATT services，並清空內部保存的參考 => 這只會清除本機 Peripheral 端已發布的 services，不會自動停止 advertising；若需要完整重置，通常會先 `stopAdvertising()`，再 `removeAllServices()`
    func removeAllServices() {
        peripheralManager.removeAllServices()
        service = nil
        controlCharacteristic = nil
        dataCharacteristic = nil
    }
    
    /// 將資料以 notify 的方式推送給已訂閱此 characteristic 的 Central => 只有已經訂閱該 characteristic 的 Central，才會收到 notify 更新
    /// - Parameters:
    ///   - data: 要推送的資料內容
    ///   - characteristic: 目標 characteristic，通常是 control 或 data 通道
    /// - Returns:
    ///   - `true`：資料已成功送進底層傳送佇列
    ///   - `false`：目前傳送佇列已滿，需等待 `peripheralManagerIsReady(toUpdateSubscribers:)` 再繼續送
    func notifyValue(_ data: Data, for characteristic: CBMutableCharacteristic) -> Bool {
        peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
    }
    
    /// 回應 Central 發出的 Read / Write request
    func respond(to request: CBATTRequest, withResult result: CBATTError.Code) {
        peripheralManager.respond(to: request, withResult: result)
    }
}

// MARK: - CBPeripheralManagerDelegate
extension WWBluetoothManager.Peripheral: CBPeripheralManagerDelegate {}

// MARK: - 私用工具
private extension WWBluetoothManager.Peripheral {
    
    /// 建立檔案傳輸用的 Service
    /// - Parameters:
    ///   - serviceUUID: Service 的 UUID（整個檔案傳輸服務的容器）
    ///   - controlUUID: 控制用 Characteristic 的 UUID（例如 hello / ack / ready / finish）
    ///   - dataUUID: 資料用 Characteristic 的 UUID（例如檔案 chunk）
    /// - Returns: 已配置完成的 `CBMutableService`
    func prepareTransferService(serviceUUID: CBUUID, controlUUID: CBUUID, dataUUID: CBUUID) -> CBMutableService {
        
        let controlCharacteristic = makeTransferCharacteristic(uuid: controlUUID)
        let dataCharacteristic = makeTransferCharacteristic(uuid: dataUUID)
        let service = CBMutableService(type: serviceUUID, primary: true)
        
        service.characteristics = [controlCharacteristic, dataCharacteristic]
        
        self.controlCharacteristic = controlCharacteristic
        self.dataCharacteristic = dataCharacteristic
        self.service = service
        
        return service
    }
    
    /// 建立雙向傳輸用的 Characteristic
    /// 用於檔案傳輸協議中的 control 與 data 通道。
    /// - Parameters:
    ///   - uuid: Characteristic 的唯一識別碼
    ///   - value: 初始值（預設 nil）
    /// - Returns: 可寫入與通知的 CBMutableCharacteristic
    /// **支援的功能：**
    /// - `.write`：允許 Central 端寫入控制命令或資料片段
    /// - `.notify`：允許 Peripheral 端主動推送狀態更新或資料 chunk
    /// - `.writeable`：Central 可以修改此 characteristic 的值
    func makeTransferCharacteristic(uuid: CBUUID, value: Data? = nil) -> CBMutableCharacteristic {
        
        let characteristic = CBMutableCharacteristic(
            type: uuid,
            properties: [.write, .notify],
            value: value,
            permissions: [.writeable]
        )
        
        return characteristic
    }
}
