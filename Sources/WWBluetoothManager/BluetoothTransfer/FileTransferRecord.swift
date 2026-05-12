//
//  FileTransferRecord.swift
//  WWBluetoothManager
//
//  Created by WilliamWeng on 2026/5/6.
//

import Foundation
import CoreBluetooth
import WWByteReader

// MARK: - FileTransferRecord
public extension WWBluetoothManager {
    
    /// 檔案傳輸協議中的單一封包資料模型 => 代表一次在 BLE characteristic 間傳送的協議單位
    struct FileTransferRecord {
        
        static let minimumCount = 13        // 最小長度 = type(1) + transferId(4) + index(4) + total(4) = 13 bytes
        
        public let type: FileTransferRecordType
        public let transferId: UInt32
        public let index: UInt32
        public let total: UInt32
        public let payload: Data
        
        /// 建立一筆檔案傳輸封包
        /// - Parameters:
        ///   - type: 封包類型 => 用來表示這筆 record 是握手封包、資料封包、ACK 封包，或是完成 / 錯誤控制封包
        ///   - transferId: 檔案傳輸會話識別碼 => 同一次傳輸中的所有封包都應使用相同的 `transferId`，用來區分不同的檔案傳輸流程
        ///   - index: 目前片段索引 => 對 `data` / `ack` 這類需要順序的封包特別重要，可用來表示「這是第幾片」
        ///   - total: 此次傳輸的總片數 => 接收端可搭配 `index` 與 `total` 來判斷是否已收齊所有資料片段
        ///   - payload: 封包承載的實際資料內容 => 在握手封包中，這裡可能放檔案大小、chunk size 等額外資訊；在 `data` 封包中，這裡則是實際的檔案片段內容
        public init(type: FileTransferRecordType, transferId: UInt32, index: UInt32, total: UInt32, payload: Data = .init()) {
            self.type = type
            self.transferId = transferId
            self.index = index
            self.total = total
            self.payload = payload
        }
    }
}

// MARK: - 公開 API
public extension WWBluetoothManager.FileTransferRecord {
    
    /// 將接收到的二進位資料解碼成 `FileTransferRecord` => 若資料長度不足，或 `type` 無法對應到合法的 `FileTransferRecordType`，則會回傳 `nil`
    /// - Parameter data: 從 BLE characteristic 收到的原始資料
    /// - Returns: 解碼成功的 `FileTransferRecord`；失敗時回傳 `nil`
    static func decode(from data: Data) throws -> Self? {
        
        if (data.count < minimumCount) { return nil }
        
        var reader = WWByteReader(data: data)
        
        let rawType: UInt8 = try reader.readUIntValue()
        
        guard let recordType = WWBluetoothManager.FileTransferRecordType(rawValue: rawType) else { return nil }
        
        let transferId: UInt32 = try reader.readUIntValue()
        let index: UInt32 = try reader.readUIntValue()
        let total: UInt32 = try reader.readUIntValue()
        let payload: Data = try reader.readRemainingData()
        
        return .init(type: recordType, transferId: transferId, index: index, total: total, payload: payload)
    }
}

// MARK: - 公開 API
public extension WWBluetoothManager.FileTransferRecord {
    
    /// 將 `FileTransferRecord` 編碼成可傳輸的二進位資料 => 編碼格式目前固定為： [ `type`: 1 byte | `transferId`: 4 bytes | `index`: 4 bytes | `total`: 4 bytes | `payload`: n bytes ]
    /// - Returns: 可直接透過 BLE characteristic 傳送的 `Data`
    public func encode() -> Data {
        
        var writer = WWByteWriter()
        
        writer.writeInteger(type.rawValue)
        writer.writeInteger(transferId)
        writer.writeInteger(index)
        writer.writeInteger(total)
        writer.writeData(payload)
        
        return writer.data
    }
}
