//
//  Extension.swift
//  Example
//
//  Created by William.Weng on 2023/11/29.
//

import CoreBluetooth

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

// MARK: - CBCharacteristicProperties (function)
extension CBCharacteristicProperties {
    
    /// 解析特徵值設定 => ["broadcast", "read"]
    /// - Returns: [String]
    func _parse() -> [String] {
        
        let dictionary = self._dictionary().keys.compactMap { key -> String? in
            
            let properties = CBCharacteristicProperties(rawValue: key)
            
            if (!self.contains(properties)) { return nil }
            return self._message(properties: properties)
        }
        
        return dictionary.sorted()
    }
    
    /// [取得特徵值的全部設定值 => [1: "broadcast"]](https://blog.csdn.net/RazilFelix/article/details/68776794)
    /// - Returns: [String: CBCharacteristicProperties]
    func _dictionary() -> [UInt: CBCharacteristicProperties] {
        
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
    
    /// 某特徵值的文字訊息
    /// - Parameter properties: CBCharacteristicProperties
    /// - Returns: String?
    func _message(properties: CBCharacteristicProperties) -> String? {
        
        if (properties == .broadcast) { return "broadcast（廣播）" }
        if (properties == .read) { return "read（讀取）" }
        if (properties == .write) { return "write（寫入）" }
        if (properties == .writeWithoutResponse) { return "writeWithoutResponse（無響應寫入）" }
        if (properties == .notify) { return "notify（通知）" }
        if (properties == .indicate) { return "indicate（指示）" }
        if (properties == .notifyEncryptionRequired) { return "notifyEncryptionRequired（通知加密要求）" }
        if (properties == .indicateEncryptionRequired) { return "indicateEncryptionRequired（指示加密要求）" }
        if (properties == .authenticatedSignedWrites) { return "authenticatedSignedWrites（身份驗證簽名寫入）" }
        if (properties == .extendedProperties) { return "extendedProperties（擴展屬性）" }
        
        return nil
    }
}
