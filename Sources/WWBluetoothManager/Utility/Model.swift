//
//  Model.swift
//  WWBluetoothManager
//
//  Created by WilliamWeng on 2026/5/4.
//

import CoreBluetooth

// MARK: -  代表一個藍牙周邊設備的資料模型 (實作 Identifiable 以便在 SwiftUI List 中使用，實作 Equatable 以便判斷設備是否相同)
public extension WWBluetoothManager {
    
    struct Device: Identifiable, Equatable, Encodable {
        
        public let id: UUID                     // 設備的唯一識別碼 (通常是 peripheral.identifier)
        
        public let peripheral: CBPeripheral
        public let name: String
        public let rssi: Int
        public let isConnectable: Bool
        
        enum CodingKeys: String, CodingKey {
            case id, name, rssi, isConnectable
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(rssi, forKey: .rssi)
            try container.encode(isConnectable, forKey: .isConnectable)
        }
        
        public var jsonString: String? {
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            guard let data = try? encoder.encode(self) else { return nil }
            return data.string()
        }
        
        /// 初始化器：將底層的 CBPeripheral 轉換為易於 UI 使用的 Device 物件
        /// - Parameters:
        ///   - peripheral: 底層的 CoreBluetooth 周邊物件
        ///   - name: 設備名稱 (防呆處理，若無名則顯示為 Unknown)
        ///   - rssi: 訊號強度 (RSSI)，可用於判斷設備遠近
        ///   - isConnectable: 是否可連線 (由 advertisementData 解析而來)
        public init(peripheral: CBPeripheral, name: String, rssi: Int, isConnectable: Bool) {
            
            self.id = peripheral.identifier
            self.peripheral = peripheral
            self.name = name
            self.rssi = rssi
            self.isConnectable = isConnectable
        }
        
        /// 定義相等性邏輯：只要兩個設備的 UUID 相同，就視為同一個設備
        public static func == (lhs: Device, rhs: Device) -> Bool {
            lhs.id == rhs.id
        }
    }
}

// MARK: -  CBCharacteristicProperties 的**描述定義**（支援 `CaseIterable`）
extension WWBluetoothManager {
    
    struct Property: CaseIterable {
        
        let rawValue: CBCharacteristicProperties
        let englishName: String
        let localizedName: String
        
        static let allCases: [Self] = [
            .init(rawValue: .broadcast, englishName: "Broadcast", localizedName: "廣播"),
            .init(rawValue: .read, englishName: "Read", localizedName: "讀取"),
            .init(rawValue: .writeWithoutResponse, englishName: "Write Without Response", localizedName: "無響應寫入"),
            .init(rawValue: .write, englishName: "Write", localizedName: "寫入"),
            .init(rawValue: .notify, englishName: "Notify", localizedName: "通知"),
            .init(rawValue: .indicate, englishName: "Indicate", localizedName: "指示"),
            .init(rawValue: .authenticatedSignedWrites, englishName: "Authenticated Signed Writes", localizedName: "身份驗證簽名寫入"),
            .init(rawValue: .extendedProperties, englishName: "Extended Properties", localizedName: "擴展屬性"),
            .init(rawValue: .notifyEncryptionRequired, englishName: "Notify Encryption Required", localizedName: "通知加密要求"),
            .init(rawValue: .indicateEncryptionRequired, englishName: "Indicate Encryption Required", localizedName: "指示加密要求"),
        ]
    }
}
