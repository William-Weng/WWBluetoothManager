//
//  Constant.swift
//  WWBluetoothManager
//
//  Created by WilliamWeng on 2026/5/4.
//

import CoreBluetooth

// MARK: -  CBCharacteristicProperties 的**描述定義**（支援 `CaseIterable`）
extension WWBluetoothManager {
    
    struct Property: CaseIterable {
        
        let rawValue: CBCharacteristicProperties
        let englishName: String
        let localizedName: String
        
        static let allCases: [WWBluetoothManager.Property] = [
            Property(rawValue: .broadcast, englishName: "Broadcast", localizedName: "廣播"),
            Property(rawValue: .read, englishName: "Read", localizedName: "讀取"),
            Property(rawValue: .writeWithoutResponse, englishName: "Write Without Response", localizedName: "無響應寫入"),
            Property(rawValue: .write, englishName: "Write", localizedName: "寫入"),
            Property(rawValue: .notify, englishName: "Notify", localizedName: "通知"),
            Property(rawValue: .indicate, englishName: "Indicate", localizedName: "指示"),
            Property(rawValue: .authenticatedSignedWrites, englishName: "Authenticated Signed Writes", localizedName: "身份驗證簽名寫入"),
            Property(rawValue: .extendedProperties, englishName: "Extended Properties", localizedName: "擴展屬性"),
            Property(rawValue: .notifyEncryptionRequired, englishName: "Notify Encryption Required", localizedName: "通知加密要求"),
            Property(rawValue: .indicateEncryptionRequired, englishName: "Indicate Encryption Required", localizedName: "指示加密要求"),
        ]
    }
}
