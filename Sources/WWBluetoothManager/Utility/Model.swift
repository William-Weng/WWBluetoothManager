//
//  Model.swift
//  WWBluetoothManager
//
//  Created by WilliamWeng on 2026/5/4.
//

import CoreBluetooth

// MARK: - Public
public extension WWBluetoothManager {
    
    /// 代表一個藍牙周邊設備的資料模型 (實作 Identifiable 以便在 SwiftUI List 中使用，實作 Equatable 以便判斷設備是否相同)
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

// MARK: - Private
extension WWBluetoothManager {
    
    /// CBCharacteristicProperties 的**描述定義**（支援 `CaseIterable`）
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
    
    /// 傳送端在單次檔案傳輸流程中所需維護的狀態資料 => 這個 session 只負責 sender 角色使用的資訊，例如目前的傳輸階段、本次傳輸的識別碼、切片大小、總片數，以及下一片要送出的索引
    struct SenderSession {
        
        var phase: FileTransferPhase = .idle            // 傳送端目前所處的檔案傳輸階段 => `idle / waitingServerHello / sendingData / waitingFinishAck`
        var transferId: UInt32 = 0                      // 本次傳輸的唯一識別碼 => 同一次檔案傳輸中的所有 record 都會共用這個值，用來在 ACK、finishAck 等回應中辨識是否屬於同一筆傳輸
        var totalChunks: UInt32 = 0                     // 本次檔案傳輸預計要送出的總片數 => 傳送端會根據原始資料大小與 chunkSize 計算這個值，並用來判斷何時停止送 data、改送 finish
        var chunkSize: Int = 20                         // 每一片資料實際可承載的 payload 大小 => 一般會根據 BLE 可寫入的最大長度扣掉自訂 record header 後得到
        var controlCharacteristic: CBCharacteristic?    // 傳送控制訊息使用的 characteristic => 例如 clientHello、ready、ack、finishAck 等控制封包
        var dataCharacteristic: CBCharacteristic?       // 傳送資料切片使用的 characteristic => 實際的 data / finish record 會透過這個 characteristic 傳送
        var sendingData = Data()                        // 本次要傳送的完整原始資料 => 這通常是已經包裝完成的檔案容器資料，例如 `TransferFile.encoded()` 的結果，後續會依 chunkSize 切成多片逐一送出
        var sendingIndex: UInt32 = 0                    // 下一片準備送出的切片索引，從 0 開始 => 每收到一筆對應的 ACK 後，通常會將它往後遞增

    }
    
    /// 接收端在單次檔案傳輸流程中所需維護的狀態資料 => 這個 session 專門保存 receiver 角色使用的資訊，例如目前的接收階段、預期總片數，以及已收到的資料切片
    struct ReceiverSession {
        
        var phase: FileTransferPhase = .idle            // 接收端目前所處的檔案傳輸階段 => `idle / waitingReady / receivingData / completed`
        var transferId: UInt32 = 0                      // 目前正在接收中的傳輸識別碼 => 用來確認收到的 data / finish / error record，是否屬於目前這一輪接收流程
        var expectedTotalChunks: UInt32 = 0             // 本次接收預期應該收到的總片數 => 通常會在收到 clientHello 時由對方提供，之後可用來檢查是否所有切片都已收齊
        var controlCharacteristic: CBCharacteristic?    // 接收控制訊息使用的 characteristic => 例如接收 clientHello、送出 serverHello、ACK、finishAck 等用途
        var dataCharacteristic: CBCharacteristic?       // 接收資料切片使用的 characteristic => 所有 data record 都會透過這個 characteristic 進來
        var receivedChunks: [UInt32: Data] = [:]        // 已接收的資料切片集合，key 為切片索引 => 接收端會先依 index 暫存各片資料，待全部收齊後再依序合併成完整 Data
    }
}

// MARK: - WWBluetoothManager.SenderSession
extension WWBluetoothManager.SenderSession {
    
    /// 建立一個處於等待 server hello 狀態的 SenderSession => 隨機產生一組 transferId，用來識別這次檔案傳輸流程，初始從第 0 個 chunk 開始傳送
    ///
    /// - Parameters:
    ///   - data: 準備傳送的完整資料內容
    ///   - chunkSize: 每個資料分段的大小
    ///   - controlCharacteristic: 用來傳送控制訊息的 characteristic
    ///   - dataCharacteristic: 用來傳送資料內容的 characteristic
    /// - Returns: 一個 phase 為 `.waitingServerHello` 的新 SenderSession
    static func makeWaitingServerHello(with data: Data, chunkSize: Int, controlCharacteristic: CBCharacteristic, dataCharacteristic: CBCharacteristic) -> Self {
        
        let totalChunks = UInt32((data.count + chunkSize - 1) / chunkSize)
        let transferId = UInt32.random(in: .min ... .max)
        
        return .init(phase: .waitingServerHello, transferId: transferId, totalChunks: totalChunks, chunkSize: chunkSize, controlCharacteristic: controlCharacteristic, dataCharacteristic: dataCharacteristic, sendingData: data, sendingIndex: 0)
    }
}

// MARK: - WWBluetoothManager.ReceiverSession
extension WWBluetoothManager.ReceiverSession {
    
    /// 根據既有的 session 與檔案傳輸紀錄，建立一個處於等待 ready 狀態的 ReceiverSession
    ///
    /// - Parameters:
    ///   - session: 目前已存在的接收 Session，沿用其中的 characteristic 設定
    ///   - record: 檔案傳輸紀錄，提供 transferId 與預期的 chunk 總數
    /// - Returns: 一個 phase 為 `.waitingReady` 的新 ReceiverSession
    static func makeWaitingReady(from session: WWBluetoothManager.ReceiverSession, record: WWBluetoothManager.FileTransferRecord) -> Self {
        .init(phase: .waitingReady, transferId: record.transferId, expectedTotalChunks: record.total, controlCharacteristic: session.controlCharacteristic, dataCharacteristic: session.dataCharacteristic, receivedChunks: [:])
    }
    
    /// 建立一個處於 idle 狀態的 ReceiverSession
    ///
    /// - Parameters:
    ///   - controlCharacteristic: 控制訊息使用的 characteristic
    ///   - dataCharacteristic: 資料傳輸使用的 characteristic
    /// - Returns: 一個 phase 為 `.idle` 的新 ReceiverSession
    static func makeIdle(controlCharacteristic: CBCharacteristic, dataCharacteristic: CBCharacteristic) -> Self {
        .init(phase: .idle, transferId: 0, expectedTotalChunks: 0, controlCharacteristic: controlCharacteristic, dataCharacteristic: dataCharacteristic, receivedChunks: [:])
    }
}
