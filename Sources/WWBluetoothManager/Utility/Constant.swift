//
//  BluetoothManager+Constant.swift
//  WWBluetoothManager
//
//  Created by William.Weng on 2023/11/29.
//

import CoreBluetooth

// MARK: - Typealias
public extension WWBluetoothManager {
    
    typealias PeripheralInformation = (UUID: UUID, name: String?, advertisementData: [String : Any], RSSI: NSNumber)
    typealias DiscoverServicesInformation = (UUID: UUID, name: String?, peripheral: CBPeripheral)
    typealias DiscoverCharacteristics = (UUID: UUID, name: String?, service: CBService)
    typealias DiscoverDescriptors = (UUID: UUID, name: String?, characteristic: CBCharacteristic)
    typealias UpdateValueInformation = (UUID: UUID, characteristic: CBCharacteristic)
    typealias UpdateNotificationStateInformation = (UUID: UUID, characteristic: CBCharacteristic)
    typealias ModifyServicesInformation = (UUID: UUID, invalidatedServices: [CBService])
    typealias PeripheralValueInformation = (peripheralId: UUID, characteristicId: CBUUID, characteristicValue: Data?)
}

// MARK: - Enum
public extension WWBluetoothManager {
    
    /// 設備ID類型
    enum PeripheralIdType {
        case UUID(_ UUID: UUID)
        case UUIDString(_ UUIDString: String)
    }
    
    /// [周邊設備的UUID代號類型](https://github.com/Eronwu/Getting-Started-with-Bluetooth-Low-Energy-in-Chinese/blob/master/chapter9.md)
    /// => CBUUID(string: "0x180f") -> Battery (電量)
    enum PeripheralUUIDType: String {
        
        case genericAccess = "0x1800"
        case alertNotificationService = "0x1811"
        case automationIO = "0x1815"
        case batteryService = "0x180F"                              // 電池資訊
        case binarySensor = "0x183B"
        case bloodPressure = "0x1810"
        case bodyComposition = "0x181B"
        case bondManagementService = "0x181E"
        case continuousGlucoseMonitoring = "0x181F"
        case currentTimeService = "0x1805"
        case cyclingPower = "0x1818"
        case cyclingSpeedAndCadence = "0x1816"
        case deviceInformation = "0x180A"                           // 設備訊息
        case emergencyConfiguration = "0x183C"
        case environmentalSensing = "0x181A"
        case fitnessMachine = "0x1826"
        case genericAttribute = "0x1801"
        case glucose = "0x1808"
        case healthThermometer = "0x1809"                           // 溫度計
        case heartRate = "0x180D"
        case httpProxy = "0x1823"
        case humanInterfaceDevice = "0x1812"
        case immediateAlert = "0x1802"
        case indoorPositioning = "0x1821"
        case insulinDelivery = "0x183A"
        case internetProtocolSupportService = "0x1820"
        case linkLoss = "0x1803"
        case locationAndNavigation = "0x1819"
        case meshProvisioningService = "0x1827"
        case meshProxyService = "0x1828"
        case nextDSTChangeService = "0x1807"
        case objectTransferService = "0x1825"
        case phoneAlertStatusService = "0x180E"
        case pulseOximeterService = "0x1822"
        case reconnectionConfiguration = "0x1829"
        case referenceTimeUpdateService = "0x1806"
        case runningSpeedAndCadence = "0x1814"
        case scanParameters = "0x1813"
        case transportDiscovery = "0x1824"
        case txPower = "0x1804"
        case userData = "0x181C"
        case weightScale = "0x181D"
        case modelNumberString = "0x2A24"                           // 設備編號 (iPhone14,5)
        case continuity = "D0611E78-BBB4-4591-A5F8-487910AE4366"    // 接續互通
        case bluMidi = "03B80E5A-EDE8-4B33-A751-6CE34EC4C700"       // 藍芽Midi
        case read = "0000FF10-0000-1000-8000-00805F9B34FB"          // 讀取
        
        /// [UUID數值](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Assigned_Numbers/out/en/Assigned_Numbers.pdf)
        /// - Returns: [CBUUID](https://blog.csdn.net/hjj801006/article/details/135593595)
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

// MARK: - Enum
public extension WWBluetoothPeripheralManager {
    
    enum DeviceError: Error {
        case notPowerOn(state: CBManagerState)  // 藍牙未打開
        case noValue                            // 沒有傳送有效數值
    }
}
