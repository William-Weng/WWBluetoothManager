//
//  BluetoothManager+Extension.swift
//  WWBluetoothManager
//
//  Created by iOS on 2023/12/1.
//

import CoreBluetooth

// MARK: - CBCharacteristicProperties (static function)
extension CBCharacteristicProperties {
    
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
extension CBCharacteristicProperties {
    
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
    
    /// 某特徵值的文字訊息
    /// - Returns: String?
    func _message() -> String? {
        
        if (self == .broadcast) { return "broadcast（廣播）" }
        if (self == .read) { return "read（讀取）" }
        if (self == .write) { return "write（寫入）" }
        if (self == .writeWithoutResponse) { return "writeWithoutResponse（無響應寫入）" }
        if (self == .notify) { return "notify（通知）" }
        if (self == .indicate) { return "indicate（指示）" }
        if (self == .notifyEncryptionRequired) { return "notifyEncryptionRequired（通知加密要求）" }
        if (self == .indicateEncryptionRequired) { return "indicateEncryptionRequired（指示加密要求）" }
        if (self == .authenticatedSignedWrites) { return "authenticatedSignedWrites（身份驗證簽名寫入）" }
        if (self == .extendedProperties) { return "extendedProperties（擴展屬性）" }
        
        return nil
    }
}
