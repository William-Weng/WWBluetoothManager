//
//  Extension.swift
//  WWBluetoothManager
//
//  Created by William.Weng on 2026/5/4.
//

import UIKit
import CoreBluetooth

// MARK: - CBCharacteristicProperties 擴展 (封裝了 `CBCharacteristicProperties`（位元旗標）的常用操作，讓 GATT 特性解析更直觀)
public extension CBCharacteristicProperties {
    
    var canRead: Bool { contains(.read) }                                                                           // 是否可讀取
    var canWrite: Bool { contains(.write) || contains(.writeWithoutResponse) }                                      // 是否可寫入（包含有響應和無響應）
    var canNotify: Bool { contains(.notify) || contains(.indicate) }                                                // 是否支援通知（notify 或 indicate）
    var requiresAuthentication: Bool { contains(.authenticatedSignedWrites) }                                       // 是否需要身份驗證
    var requiresEncryption: Bool { contains(.notifyEncryptionRequired) || contains(.indicateEncryptionRequired) }   // 是否需要加密
    
    var localizedDescriptions: [String] { parseProperties().map(\.localizedName).sorted() }                         // 中文描述陣列（排序）
    var englishDescriptions: [String] { parseProperties().map(\.englishName).sorted() }                             // 英文描述陣列（排序）
    var descriptions: [String] { parseProperties().map { "\($0.englishName) (\($0.localizedName))" }.sorted() }     // 中英雙語描述（格式化）
    var description: String { localizedDescriptions.joined(separator: ", ") }                                       // 簡化描述（僅名稱，逗號分隔）
}

// MARK: - 公用函式
public extension CBCharacteristicProperties {
    
    /// 檢查是否包含所有指定屬性
    func containsAll(_ properties: CBCharacteristicProperties) -> Bool {
        intersection(properties) == properties
    }
    
    /// 檢查是否至少包含一個指定屬性
    func containsAny(_ properties: CBCharacteristicProperties) -> Bool {
        !intersection(properties).isEmpty
    }
}

// MARK: - Data
public extension Data {
    
    /// [Data => 16進位文字](https://zh.wikipedia.org/zh-tw/十六进制)
    /// - %02x - 推播Token常用
    /// - Returns: String
    func hexString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
    
    /// Data => 文字
    /// - Returns: String?
    func string(encoding: String.Encoding = .utf8) -> String? {
        String(data: self, encoding: encoding)
    }
}

// MARK: - String
extension String {
    
    /// 將字串轉換為 CBUUID
    var asCBUUID: CBUUID? { return CBUUID(string: self) }
}

// MARK: - Dictionary
extension Dictionary where Key == String, Value == Any {
    
    subscript(key: WWBluetoothManager.AdvertisementDataKey) -> Value? {
        self[key.rawValue]
    }
}

// MARK: - CBPeripheralManager
extension CBPeripheralManager {
    
    /// 使用型別化的廣告資料鍵值，開始 BLE advertising
    func startAdvertising(advertisementData: [WWBluetoothManager.AdvertisementDataKey: Any]) {
        
        var options: [String: Any] = [:]
        
        for (key, value) in advertisementData {
            options[key.rawValue] = value
        }
        
        startAdvertising(options)
    }
}

// MARK: - 私有實現
private extension CBCharacteristicProperties {
    
    /// 解析所有啟用的屬性
    func parseProperties() -> [WWBluetoothManager.Property] {
        WWBluetoothManager.Property.allCases.filter { contains($0.rawValue) }
    }
}
