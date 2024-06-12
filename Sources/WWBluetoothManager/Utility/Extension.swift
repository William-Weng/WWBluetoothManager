//
//  BluetoothManager+Extension.swift
//  WWBluetoothManager
//
//  Created by William.Weng on 2023/12/1.
//

import UIKit
import CoreBluetooth

// MARK: - String (function)
public extension String {
    
    /// 16進制文字轉數字
    /// - Parameter radix: 10進制 / 16進制 / …
    /// - Returns: UInt64?
    func _UInt64(radix: Int = 16) -> UInt64? {
        return UInt64(self, radix: radix)
    }
    
    /// String => Data
    /// - Parameters:
    ///   - encoding: 字元編碼
    ///   - isLossyConversion: 失真轉換
    /// - Returns: Data?
    func _data(using encoding: String.Encoding = .utf8, isLossyConversion: Bool = false) -> Data? {
        let data = self.data(using: encoding, allowLossyConversion: isLossyConversion)
        return data
    }
}

// MARK: - Data (function)
public extension Data {
    
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
public extension CBUUID {
    
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

// MARK: - CBCharacteristicProperties (static function)
public extension CBCharacteristicProperties {
    
    /// [取得特徵值的全部設定值 => [1: "broadcast"]](https://blog.csdn.net/RazilFelix/article/details/68776794)
    /// - Returns: [String: CBCharacteristicProperties]
    static func _dictionary() -> [UInt: CBCharacteristicProperties] {
        
        var dictionary: [UInt: CBCharacteristicProperties] = [:]
        
        let properties: [CBCharacteristicProperties] = [
            .broadcast,
            .read,
            .writeWithoutResponse,
            .write,
            .notify,
            .indicate,
            .authenticatedSignedWrites,
            .extendedProperties,
            .notifyEncryptionRequired,
            .indicateEncryptionRequired,
        ]
        
        properties.forEach { property in
            dictionary[property.rawValue] = property
        }
        
        return dictionary
    }
}

// MARK: - CBCharacteristicProperties (function)
public extension CBCharacteristicProperties {
    
    /// 解析特徵值設定 => ["broadcast", "read"]
    /// - Returns: [String]
    func _parse() -> [String] {
        
        let dictionary = Self._dictionary().keys.compactMap { key -> String? in
            
            let properties = CBCharacteristicProperties(rawValue: key)
            
            if (!self.contains(properties)) { return nil }
            return properties._message()
        }
        
        return dictionary.sorted()
    }
}

// MARK: - CBCharacteristicProperties (function)
private extension CBCharacteristicProperties {
    
     /// 某特徵值的文字訊息
     /// - Returns: String?
     func _message() -> String? {
         
         var message: String?
         
         switch self {
         case .broadcast: message = "broadcast（廣播）"
         case .read: message = "read（讀取）"
         case .write: message = "write（寫入）"
         case .writeWithoutResponse: message = "writeWithoutResponse（無響應寫入）"
         case .notify: message = "notify（通知）"
         case .indicate: message = "indicate（指示）"
         case .notifyEncryptionRequired: message = "notifyEncryptionRequired（通知加密要求）"
         case .indicateEncryptionRequired: message = "indicateEncryptionRequired（指示加密要求）"
         case .authenticatedSignedWrites: message = "authenticatedSignedWrites（身份驗證簽名寫入）"
         case .extendedProperties: message = "extendedProperties（擴展屬性）"
         default: break
         }
         
         return message
     }
}

// MARK: - CBPeripheral (function)
public extension CBPeripheral {
    
    /// 設定讀取配對UUID的特徵值上的資料
    /// - Parameters:
    ///   - UUID: CBUUID
    ///   - characteristic: CBCharacteristic
    ///   - properties: WWBluetoothManager.PeripheralUUIDType
    /// - Returns: CBCharacteristicProperties
    func _readValue(pairUUID UUID: CBUUID, characteristic: CBCharacteristic, contains properties: CBCharacteristicProperties = .read) -> Bool {

        if (!characteristic.properties.contains(properties)) { return false }
        if (characteristic.uuid != UUID) { return false }

        self.readValue(for: characteristic)

        return true
    }

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
