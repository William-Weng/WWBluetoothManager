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
        
        static let minimumCount = 13                                                            // 最小長度 = type(1) + transferId(4) + index(4) + total(4) = 13 bytes
        static let emptyData: Self = .init(type: .data, transferId: 0, index: 0, total: 0)      // 表示沒有有效 payload 的空資料 record，通常用於 sender session 不存在時的保底回傳
        
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

// MARK: - FileTransferRecord
extension WWBluetoothManager.FileTransferRecord {
        
    /// 根據既有 record 建立一筆錯誤封包
    ///
    /// 此封包會沿用原 record 的 `transferId` 與 `total`，並以 `index = 0` 表示這是一筆控制用途的錯誤通知，而非資料片段回應。
    ///
    /// - Parameter record: 作為本次錯誤回應基礎的既有封包
    /// - Returns: 可用於通知對端傳輸失敗的 error record
    static func makeError(from record: Self) -> Self {
        .init(type: .error, transferId: record.transferId, index: 0, total: record.total)
    }
    
    /// 根據既有 record 建立一筆 `ready` 封包
    ///
    /// 此封包通常用於握手階段，表示接收端或對端已準備好進入資料傳輸流程。它會沿用原 record 的 `transferId` 與 `total`，並固定使用 `index = 0`。
    ///
    /// - Parameter record: 作為本次 ready 回應基礎的既有封包
    /// - Returns: 可用於通知對端開始進入資料傳輸階段的 ready record
    static func makeReady(from record: Self) -> Self {
        .init(type: .ready, transferId: record.transferId, index: 0, total: record.total)
    }
    
    /// 根據既有 record 建立一筆 `serverHello` 封包
    ///
    /// 此封包通常用於回應 `clientHello`，表示接收端已接受本次傳輸請求，並準備進行後續握手流程。它會沿用原 record 的 `transferId` 與 `total`，並固定使用 `index = 0`
    ///
    /// - Parameter record: 作為本次 `serverHello` 回應基礎的既有封包。
    /// - Returns: 可用於握手流程中的 `serverHello` record。
    static func makeServerHello(from record: Self) -> Self {
        .init(type: .serverHello, transferId: record.transferId, index: 0, total: record.total)
    }
    
    /// 根據目前的 SenderSession 與 hello payload，建立 client hello 封包
    ///
    /// - Parameters:
    ///   - session: 目前的傳送 Session
    ///   - helloPayload: client hello 要附帶的 payload
    /// - Returns: 一個 type 為 `.clientHello` 的 FileTransferRecord
    static func makeClientHello(from session: WWBluetoothManager.SenderSession, payload: Data) -> Self {
        .init(type: .clientHello, transferId: session.transferId, index: 0, total: session.totalChunks, payload: payload)
    }
    
    /// 根據既有 record 建立一筆 ACK 封包
    ///
    /// 此封包會沿用原 record 的 `transferId`、`index` 與 `total`，用來表示某個特定資料片段已成功被接收端接受。
    ///
    /// - Parameter record: 要回應的既有資料封包
    /// - Returns: 對應該資料片段的 ACK record
    static func makeAck(from record: Self) -> Self {
        .init(type: .ack, transferId: record.transferId, index: record.index, total: record.total)
    }
    
    /// 根據既有 record 建立一筆 `finishAck` 封包
    ///
    /// 此封包表示接收端已完成整筆檔案資料的接收與重組。它會沿用原 record 的 `transferId` 與 `total`，並使用 `index = total` 表示本次傳輸的所有資料片段都已完成確認。
    ///
    /// - Parameter record: 作為本次完成回應基礎的既有封包。
    /// - Returns: 可用於通知對端整筆傳輸已完成的 `finishAck` record。
    static func makeFinishAck(from record: Self) -> Self {
        .init(type: .finishAck, transferId: record.transferId, index: record.total, total: record.total)
    }
}

// MARK: - Sender record factories
extension WWBluetoothManager.FileTransferRecord {
    
    /// 根據目前 sender session 建立一筆資料封包
    ///
    /// 此封包會使用 session 中的 `transferId`、`sendingIndex` 與 `totalChunks`，並將傳入的 `payload` 作為本次實際要傳送的資料片段內容。
    ///
    /// - Parameters:
    ///   - senderSession: 目前傳送流程使用中的 sender session
    ///   - payload: 本次要送出的資料片段內容
    /// - Returns: 可用於送出單一資料切片的 data record
    static func makeData(from senderSession: WWBluetoothManager.SenderSession, payload: Data) -> Self {
        .init(type: .data, transferId: senderSession.transferId, index: senderSession.sendingIndex, total: senderSession.totalChunks, payload: payload)
    }
    
    /// 根據目前 sender session 建立一筆完成封包
    ///
    /// 此封包表示 sender 已完成所有資料片段的送出。它會使用 session 中的 `transferId` 與 `totalChunks`，並以 `index = totalChunks` 表示整筆資料傳輸已到達結尾。
    ///
    /// - Parameter senderSession: 目前傳送流程使用中的 sender session
    /// - Returns: 可用於通知對端資料已全部送完的 finish record
    static func makeFinish(from senderSession: WWBluetoothManager.SenderSession) -> Self {
        .init(type: .finish, transferId: senderSession.transferId, index: senderSession.totalChunks, total: senderSession.totalChunks)
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
