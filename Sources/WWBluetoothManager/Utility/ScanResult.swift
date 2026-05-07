//
//  ScanResult.swift
//  WWBluetoothManager
//
//  Created by WilliamWeng on 2026/5/4.
//

import Foundation
import CoreBluetooth

/// 掃描結果結構體，封裝周邊設備的廣告資料解析 (提供對 CoreBluetooth 廣告資料的**類型安全存取**，避免直接操作 `[String: Any]`)
public extension WWBluetoothManager.Central {
    
    struct ScanResult {
        
        public let peripheral: CBPeripheral                             // CoreBluetooth 周邊設備實例
        public let advertisementData: [String: Any]                     // 原始廣告資料包（來自 `didDiscover` 委派）
        public let rssi: NSNumber                                       // 訊號強度（RSSI），範圍約 -120 ~ -30，數值越大訊號越強
    }
}

/// 掃描結果細節
public extension WWBluetoothManager.Central.ScanResult {
    
    var localName: String? { getLocalName() }                           // 本地設備名稱（廣告資料優先）
    var manufacturerData: Data? { getManufacturerData() }               // 製造商專用資料（原始 bytes）
    var manufacturerHexString: String? { getManufacturerHexString() }   // 製造商資料的 16 進位字串表示（`XX XX XX...`）
    var serviceUUIDs: [CBUUID]? { getServiceUUIDs() }                   // 廣告中宣告的服務 UUID 列表
    var isConnectable: Bool? { checkConnectable() }                     // 是否可連線標記
    var displayName: String? { getDisplayName() }                       // 顯示名稱（優先順序：localName > peripheral.name > "Unknown"）
}

// MARK: - 友好文字顯示
extension WWBluetoothManager.Central.ScanResult: CustomStringConvertible, CustomDebugStringConvertible {
    
    /// 簡潔顯示（Console 友好）
    public var description: String {
        """
        📱 \(displayName) | 📶 \(rssi.stringValue)dBm | 🔗 \(isConnectable.map { $0 ? "YES" : "NO" } ?? "unknown")
        """
    }
    
    /// 詳細 JSON 格式（Debug 用）
    public var debugDescription: String {
        """
        {
          "displayName": "\(displayName)",
          "rssi": \(rssi.stringValue),
          "isConnectable": \(String(describing: isConnectable)),
          "localName": "\(localName ?? "null")",
          "manufacturerHex": "\(manufacturerHexString ?? "null")",
          "serviceUUIDs": \(serviceUUIDs?.map { $0.uuidString } ?? []),
          "peripheral": {
            "name": "\(peripheral.name ?? "null")",
            "identifier": "\(peripheral.identifier.uuidString)",
            "state": "\(peripheral.state.rawValue)"
          }
        }
        """
    }
}

// MARK: - JSON 序列化
extension WWBluetoothManager.Central.ScanResult: Encodable {
        
    public func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(displayName, forKey: .displayName)
        try container.encode(rssi.stringValue, forKey: .rssi)
        try container.encode(isConnectable, forKey: .isConnectable)
        try container.encode(localName, forKey: .localName)
        try container.encode(manufacturerHexString, forKey: .manufacturerHex)
        try container.encode(serviceUUIDs?.map(\.uuidString), forKey: .serviceUUIDs)
        
        var peripheralContainer = container.nestedContainer(keyedBy: PeripheralKey.self, forKey: .peripheral)
        try peripheralContainer.encode(peripheral.name, forKey: .name)
        try peripheralContainer.encode(peripheral.identifier.uuidString, forKey: .identifier)
        try peripheralContainer.encode(peripheral.state.rawValue, forKey: .state)
    }
}

// MARK: - 便利打印方法（完全相容）
public extension WWBluetoothManager.Central.ScanResult {
    
    /// 美化 JSON 輸出（支援 iOS 11+）
    func jsonString(prettyPrinted: Bool = true) -> String {
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        
        if (!prettyPrinted) { encoder.outputFormatting = [] }
        
        guard let data = try? encoder.encode(self),
              let jsonString = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        
        return jsonString
    }
}

// MARK: - CodingKey
private extension WWBluetoothManager.Central.ScanResult {
    
    enum CodingKeys: String, CodingKey {
        case displayName, rssi, isConnectable, localName
        case manufacturerHex = "manufacturerHexString"
        case serviceUUIDs, peripheral
    }
    
    enum PeripheralKey: String, CodingKey {
        case name, identifier, state
    }
}

// MARK: - 小工具 (ScanResult 的**私有實現細節**，隱藏 CoreBluetooth 字串常數的複雜性)
private extension WWBluetoothManager.Central.ScanResult {
    
    /// 提取本地設備名稱
    /// **類型轉換**：`[String: Any][key]` → `String?`
    func getLocalName() -> String? {
        advertisementData[.localName] as? String
    }
    
    /// 提取製造商資料
    /// **類型轉換**：`[String: Any][key]` → `Data?`
    func getManufacturerData() -> Data? {
        advertisementData[.manufacturerData] as? Data
    }
    
    /// 將製造商資料轉為 16 進位字串
    /// **格式**：`[0x]AA BB CC DD...`（小寫，無分隔符）
    func getManufacturerHexString() -> String? {
        getManufacturerData()?.hexString()
    }
    
    /// 提取服務 UUID 列表
    /// **類型轉換**：`[String: Any][key]` → `[CBUUID]?`
    func getServiceUUIDs() -> [CBUUID]? {
        advertisementData[.serviceUUIDs] as? [CBUUID]
    }
    
    /// 檢查可連線標記（支援 Bool 和 NSNumber 雙重類型）
    /// **相容性處理**：
    /// - `Bool` → 直接回傳
    /// - `NSNumber` → `.boolValue`
    /// - 其他類型 → `nil`
    func checkConnectable() -> Bool? {
        
        if let value = advertisementData[.isConnectable] as? Bool { return value }
        if let value = advertisementData[.isConnectable] as? NSNumber { return value.boolValue }
        
        return nil
    }
    
    /// 產生顯示名稱（三層 fallback）
    /// **優先順序**：
    /// 1. `localName`（廣告資料）
    /// 2. `peripheral.name`（系統快取）
    /// 3. 預設名稱 `"Unknown"`
    func getDisplayName() -> String? {
                
        if let localName = getLocalName(), !localName.isEmpty { return localName }
        if let name = peripheral.name, !name.isEmpty { return name }
        
        return nil
    }
}
