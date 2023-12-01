//
//  Extension.swift
//  Example
//
//  Created by William.Weng on 2023/11/29.
//

import CoreBluetooth
import WWBluetoothManager

// MARK: - Collection (override function)
extension Collection {

    /// [為Array加上安全取值特性 => nil](https://stackoverflow.com/questions/25329186/safe-bounds-checked-array-lookup-in-swift-through-optional-bindings)
    subscript(safe index: Index) -> Element? { return indices.contains(index) ? self[index] : nil }
}

// MARK: - UInt (function)
extension UInt {
    
    /// [進制轉換 => 16進制 (255 -> 0xff)](https://developer.apple.com/documentation/swift/int/2924481-init)
    /// - Parameters:
    ///   - radix: 2進制
    ///   - prefix: 前綴字
    ///   - isUppercase: 是否轉大寫
    /// - Returns: String
    func _radixString(_ radix: Int = 16, prefix: String = "0x", maxCount: Int = 8, isUppercase: Bool = true) -> String {
        
        let value = String(self, radix: radix, uppercase: isUppercase)
        let diffCount = maxCount - value.count
        let minCount = [maxCount, maxCount - value.count].min()
        let formatString = (diffCount > 0) ? String(repeating: "0", count: minCount ?? 0) : ""
        
        return prefix + formatString + value
    }
}

// MARK: - String (function)
extension String {
    
    /// 文字轉數字
    /// - Parameter radix: 10進制 / 16進制 / …
    /// - Returns: UInt64?
    func _UInt64(radix: Int = 16) -> UInt64? {
        return UInt64(self, radix: radix)
    }
}

// MARK: - Data (function)
extension Data {
    
    /// [Data => 16進位文字](https://zh.wikipedia.org/zh-tw/十六进制)
    /// - %02x - 推播Token常用
    /// - Returns: String
    func _hexString() -> String {
        let hexString = reduce("") { return $0 + String(format: "%02x", $1) }
        return hexString
    }
    
    /// Data => 字串
    /// - Parameter encoding: 字元編碼
    /// - Returns: String?
    func _string(using encoding: String.Encoding = .utf8) -> String? {
        return String(bytes: self, encoding: encoding)
    }
}

// MARK: - CBUUID (Operator)
extension CBUUID {
    
    /// [自定義運算子](https://www.appcoda.com.tw/operator-overloading-swift/)
    static func ===(lhs: CBUUID, rhs: String) -> Bool {
        return lhs == CBUUID(string: rhs)
    }
    
    /// [自定義運算子](https://www.appcoda.com.tw/operator-overloading-swift/)
    static func !==(lhs: CBUUID, rhs: String) -> Bool {
        return !(lhs === rhs)
    }
    
    /// [自定義運算子](https://www.appcoda.com.tw/operator-overloading-swift/)
    static func ===(lhs: CBUUID, rhs: WWBluetoothManager.PeripheralUUIDType) -> Bool {
        return lhs == rhs.value()
    }
    
    /// [自定義運算子](https://www.appcoda.com.tw/operator-overloading-swift/)
    static func !==(lhs: CBUUID, rhs: WWBluetoothManager.PeripheralUUIDType) -> Bool {
        return !(lhs === rhs)
    }
}

// MARK: - CBPeripheral (function)
extension CBPeripheral {
    
    /// 設定讀取配對UUID的特徵值上的資料
    /// - Parameters:
    ///   - UUIDString: String
    ///   - characteristic: CBCharacteristic
    ///   - properties: WWBluetoothManager.PeripheralUUIDType
    /// - Returns: CBCharacteristicProperties
    func _readValue(pairUUIDString UUIDString: String, characteristic: CBCharacteristic, contains properties: CBCharacteristicProperties = .read) -> Bool {
        
        if (!characteristic.properties.contains(properties)) { return false }
        if (characteristic.uuid !== UUIDString) { return false }
        
        self.readValue(for: characteristic)
        
        return true
    }
    
    /// 設定讀取配對UUID的特徵值上的資料
    /// - Parameters:
    ///   - UUIDType: WWBluetoothManager.PeripheralUUIDType
    ///   - characteristic: CBCharacteristic
    ///   - properties: WWBluetoothManager.PeripheralUUIDType
    /// - Returns: CBCharacteristicProperties
    func _readValue(pairUUIDType UUIDType: WWBluetoothManager.PeripheralUUIDType, characteristic: CBCharacteristic, contains properties: CBCharacteristicProperties = .read) -> Bool {
        return self._readValue(pairUUIDString: UUIDType.rawValue, characteristic: characteristic, contains: properties)
    }
    
    /// 設定通知配對UUID的特徵值上的資料
    /// - Parameters:
    ///   - UUIDString: String
    ///   - characteristic: CBCharacteristic
    ///   - properties: CBCharacteristicProperties
    ///   - enabled: Bool
    /// - Returns: Bool
    func _notifyValue(pairUUIDString UUIDString: String, characteristic: CBCharacteristic, contains properties: CBCharacteristicProperties = .notify, enabled: Bool = true) -> Bool {
        
        if (!characteristic.properties.contains(properties)) { return false }
        if (characteristic.uuid !== UUIDString) { return false }
        
        self.setNotifyValue(enabled, for: characteristic)
        self.discoverDescriptors(for: characteristic)
        
        return true
    }
    
    /// 設定通知配對UUID的特徵值上的資料
    /// - Parameters:
    ///   - UUIDString: String
    ///   - characteristic: CBCharacteristic
    ///   - properties: CBCharacteristicProperties
    ///   - enabled: Bool
    /// - Returns: Bool
    func _indicateValue(pairUUIDString UUIDString: String, characteristic: CBCharacteristic, contains properties: CBCharacteristicProperties = .indicate, enabled: Bool = true) -> Bool {
        return self._notifyValue(pairUUIDString: UUIDString, characteristic: characteristic, contains: properties, enabled: enabled)
    }
}
