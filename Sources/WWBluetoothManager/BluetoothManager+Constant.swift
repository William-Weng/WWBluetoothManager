//
//  BluetoothManager+Constant.swift
//  WWBluetoothManager
//
//  Created by William.Weng on 2023/11/29.
//

import CoreBluetooth

/// MARK: - 公用常數 (1)
public extension WWBluetoothManager {
    
    typealias PeripheralInformation = (UUID: UUID, name: String?, advertisementData: [String : Any], RSSI: NSNumber)
    typealias DiscoverServicesInformation = (UUID: UUID, name: String?, peripheral: CBPeripheral)
    typealias DiscoverCharacteristics = (UUID: UUID, name: String?, service: CBService)
    typealias DiscoverDescriptors = (UUID: UUID, name: String?, characteristic: CBCharacteristic)
    typealias UpdateValueInformation = (UUID: UUID, characteristic: CBCharacteristic)
    typealias UpdateNotificationStateInformation = (UUID: UUID, characteristic: CBCharacteristic)
    typealias ModifyServicesInformation = (UUID: UUID, invalidatedServices: [CBService])
    typealias PeripheralValueInformation = (peripheralId: UUID, characteristicId: CBUUID, characteristicValue: Data?)
    
    /// [周邊設備的UUID代號類型](https://github.com/Eronwu/Getting-Started-with-Bluetooth-Low-Energy-in-Chinese/blob/master/chapter9.md)
    /// => CBUUID(string: "0x180f") -> Battery (電量)
    enum PeripheralUUIDType: String {
        
        case healthThermometer = "0x1809"
        case battery = "0x180F"                                     // 電量
        case deviceInformation = "0x180A"                           // 設備資訊
        case manufacturerNameString = "0x2A29"                      // 製造商編號 (Apple Inc.)
        case modelNumberString = "0x2A24"                           // 設備編號 (iPhone14,5)
        case continuity = "D0611E78-BBB4-4591-A5F8-487910AE4366"    // 接續互通
        case bluMidi = "03B80E5A-EDE8-4B33-A751-6CE34EC4C700"       // 藍芽Midi
        case read = "0000FF10-0000-1000-8000-00805F9B34FB"          // 讀取
        
        /// UUID數值
        /// - Returns: CBUUID
        public func value() -> CBUUID { return CBUUID(string: self.rawValue) }
    }
    
    /// 搜尋數值的類型
    enum DiscoverValueType {
        case services(_ info: DiscoverServicesInformation)
        case characteristics(_ info: DiscoverCharacteristics)
        case descriptors(_ info: DiscoverDescriptors)
    }
    
    /// 更新數值的類型
    enum UpdateType {
        case notificationState(_ info: UpdateNotificationStateInformation)
        case value(_ info: UpdateValueInformation)
    }

    /// 相關錯誤
    enum PeripheralError: Error {
        case connect(_ UUID: UUID, name: String?, error: ConnectError)
        case discover(_ UUID: UUID, name: String?, error: DiscoverError)
        case update(_ UUID: UUID, name: String?, error: UpdateError)
    }
    
    /// 設備連線狀態
    enum PeripheralConnectType {
        case didConnect(_ UUID: UUID)
        case didDisconnect(_ UUID: UUID)
    }
    
    /// 連接管理中心錯誤
    enum ConnectError {
        case centralManager(_ error: Error)
    }
    
    /// 設備搜尋錯誤
    enum DiscoverError {
        case services(_ error: Error)
        case characteristics(_ error: Error)
        case descriptors(_ error: Error)
    }
    
    /// 設備傳值錯誤
    enum UpdateError {
        case value(_ error: Error)
        case notificationState(_ error: Error)
    }
}

