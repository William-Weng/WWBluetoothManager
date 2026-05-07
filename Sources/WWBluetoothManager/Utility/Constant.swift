//
//  Constant.swift
//  WWBluetoothManager
//
//  Created by WilliamWeng on 2026/5/4.
//

import CoreBluetooth

// MARK: - Central事件狀態常數化
public extension WWBluetoothManager {
    
    /// CentralManager 相關的事件狀態，用於 `centralManager(_:status:)` 委派方法。
    /// 這些事件來自 `CBCentralManagerDelegate`，代表 Bluetooth 中央設備管理器的核心操作：
    /// - 狀態更新（開關、權限等）
    /// - 設備掃描發現
    /// - 設備連線/斷線狀態變化
    /// **使用情境**：處理掃描、連線等中央管理器層級的事件。
    enum CentralStatus {
        
        case stateUpdated(state: CBManagerState)                                                        // Bluetooth 狀態更新（`.poweredOn`, `.poweredOff`, `.unauthorized` 等）
        case discovered(result: Central.ScanResult)                                                     // 掃描期間發現新的周邊設備
        case connected(peripheral: CBPeripheral)                                                        // 成功連接到周邊設備，開始服務發現流程
        case disconnected(peripheral: CBPeripheral, error: Error?)                                      // 周邊設備斷線，可能因使用者手動斷開、設備離開範圍或錯誤
        case failedToConnect(peripheral: CBPeripheral, error: Error?)                                   // 連線失敗，可能因超時、設備拒絕連線或錯誤
    }
    
    /// CBPeripheral 相關的事件狀態，用於 `centralManager(_:peripheral:status:)` 委派方法。
    /// 這些事件來自 `CBPeripheralDelegate`，代表已連線周邊設備的詳細操作：
    /// - 服務和特性發現
    /// - 通知狀態變化
    /// - 資料讀寫完成
    /// **使用情境**：處理特定設備的 GATT 服務操作和資料通訊。
    enum PeripheralStatus {
        
        case discoveredServices(services: [CBService])                                                  // 成功發現設備的所有服務
        case discoveredCharacteristics(service: CBService, characteristics: [CBCharacteristic])         // 某個服務的特性發現完成
        case notificationStateUpdated(characteristic: CBCharacteristic, error: Error?)                  // 通知狀態更新（啟用/停用），可能伴隨錯誤
        case characteristicValueUpdated(characteristic: CBCharacteristic, data: Data?, error: Error?)   // 特性值更新（通知/指示觸發），包含接收到的資料
        case characteristicWriteCompleted(characteristic: CBCharacteristic, error: Error?)              // 特性寫入操作完成，可能伴隨錯誤
        case characteristicDiscoveryFailed(service: CBService, error: Error?)                           // 特性發現失敗
        case serviceDiscoveryFailed(error: Error?)                                                      // 服務發現失敗
    }
}

// MARK: - Client事件狀態常數化
public extension WWBluetoothManager {
    
    /// 代表藍牙 Client 運作過程中產生的各種狀態與事件 => 透過訂閱這些事件，外部開發者可以即時掌握藍牙連線的生命週期與數據流向。
    enum ClientEvent {
        
        case stateChanged(CBManagerState)                                                               // 藍牙硬體狀態變更 (例如：poweredOn, poweredOff, resetting)
        case discovered(Device)                                                                         // 發現周邊設備
        case connected(Device)                                                                          // 成功連線至周邊設備
        case disconnected(Device?, Error?)                                                              // 設備斷線。回傳該設備與斷線原因 (若為 nil 代表正常斷線)
        case servicesDiscovered(Device, [CBUUID])                                                       // 已成功發現設備的所有服務 (Services)
        case characteristicsDiscovered(CBUUID, [CBUUID])                                                // 已成功發現指定服務下的所有特徵值 (Characteristics)
        case notificationEnabled(CBUUID)                                                                // 特定特徵值的通知功能已開啟 (Notification/Indication enabled)
        case valueUpdated(CBUUID, Data)                                                                 // 接收到來自藍牙裝置的數據更新
        case writeCompleted(CBUUID, Error?)                                                             // 寫入資料操作已完成。回傳錯誤以標記是否發生失敗
        case failed(Error)                                                                              // 操作失敗。包含所有階段（掃描、連線、發現、讀寫）的錯誤 => 建議配合 ClientError 進行類型匹配與處理
    }
    
    /// 代表藍牙 Client 運作過程中產生的各種錯誤
    enum ClientError: Error {
        
        case invalidUUID                                                                                // 無效的 UUID 格式，無法轉換為 CBUUID
        case peripheralNotConnected                                                                     // 設備尚未連線或連線已斷開
        case characteristicNotFound                                                                     // 特徵值不可用（未發現、無權限或該設備不支援）
        case encodingFailed                                                                             // 字串轉 Data 編碼失敗 (例如：使用了不支援該字元集的編碼)
        case operationFailed(Error)                                                                     // 底層藍牙作業錯誤（關聯到底層的錯誤訊息）
    }
}

// MARK: - 檔案傳輸
public extension WWBluetoothManager {
    
    /// 檔案傳輸協議的封包型別 => 設計概念參考 TLS/SSL handshake：先做握手協商，再進入資料傳輸，最後做完成確認 / 每一個 case 都代表一種「控制訊息」或「資料訊息」。
    enum FileTransferRecordType: UInt8 {
        
        case clientHello = 0x01             // 傳送端發起傳檔請求 => 類似 TLS 的 ClientHello
        case serverHello = 0x02             // 接收端回覆已收到傳檔請求，並同意建立此次傳輸會話 => 類似 TLS 的 ServerHello
        case ready = 0x03                   // 傳送端確認握手完成，準備開始傳送資料片段
        case data = 0x04                    // 檔案內容的實際資料片段
        case ack = 0x05                     // 接收端確認已收到某個資料片段 (ACK = Acknowledgement)
        case finish = 0x06                  // 傳送端表示檔案資料已經全部送完 => 表示所有 `.data` 都已送出
        case finishAck = 0x07               // 接收端確認整個檔案已成功接收並完成重組 => 類似傳輸流程中的最終完成確認
        case error = 0x08                   // 傳輸過程中發生錯誤 => 可表示握手失敗、資料缺片、格式錯誤、狀態不一致等問題
    }
    
    /// 檔案傳輸狀態機目前所處的階段 => `FileTransferRecordType` = 「收到 / 送出的封包是什麼」 / `FileTransferPhase` = 「整個傳檔流程現在走到哪裡」
    enum FileTransferPhase: Equatable {
        
        case idle                           // 尚未開始傳輸 => 初始狀態，或重置後的待命狀態。
        case waitingServerHello             // 已送出 `clientHello`，等待接收端回覆 `serverHello` => 這表示傳送端正在等待對方接受此次傳輸會話
        case waitingReady                   // 已完成前半段握手，等待進入正式傳輸狀態 => 接收端剛收到 `clientHello`，準備等待 `ready` / 傳送端剛收到 `serverHello`，即將送出 `ready`
        case sendingData                    // 正在傳送或接收資料片段 => 進入此狀態後，通常會持續處理 `.data` 與 `.ack`，直到所有 chunk 傳輸完成
        case waitingFinishAck               // 所有資料片段都已送出，等待接收端回覆 `finishAck` => 傳送端在送出 `finish` 後，會停留在這個狀態，直到對方確認整個檔案已完整接收
        case receivingData                  // 正在接收資料片段 => 這個狀態通常出現在接收端，表示目前正在累積多個 `data` chunk，等待重組完整檔案
        case completed                      // 傳輸已成功完成 => 傳送端或接收端在整個流程結束後都可以進入此狀態
        case failed(FileTransferError)      // 傳輸失敗 => 會附帶錯誤描述，用來表示此次傳輸失敗的原因
    }
    
    /// 檔案傳輸錯誤
    ///
    /// 表示本次檔案傳輸過程中發生的領域錯誤，
    /// 用於 `WWBluetoothManager.FileTransferController` 的狀態機與回調。
    enum FileTransferError: Error, Equatable {
        
        case writeFailed(String)            // 寫入藍牙 characteristic 失敗
        case updateFailed(String)           // characteristic 資料更新失敗
        case invalidRecord                  // 收到的傳輸記錄格式無法解碼或無效
        case missingChunks                  // 所有資料切片尚未集齊，無法組成完整檔案
        case peerReturnedError              // 對端回傳了錯誤訊號，表示傳輸異常
        case invalidTransferId              // 收到的傳輸 ID 與本端不符，可能為不屬於本次傳輸的封包
        case invalidPhase                   // 傳輸狀態機進入非法狀態，表示內部流程錯誤
        case missingCharacteristic          // 所需的藍牙 characteristic 不存在（例如 data / control characteristic 為 nil）
    }
}

// MARK: - 藍牙週邊
public extension WWBluetoothManager {
    
    /// PeripheralManager 的事件列舉
    ///
    /// 用來把 `CBPeripheralManagerDelegate` 的 callback
    /// 包裝成較容易在外部 ViewController / Controller 層處理的狀態事件。
    enum PeripheralManagerStatus {
        
        case stateUpdated(CBManagerState)               // 藍牙狀態更新 => 例如 `.poweredOn`、`.poweredOff`、`.unauthorized` 等 => 通常只有在 `.poweredOn` 之後，才能安全地 add service 或 start advertising
        case serviceAdded(CBService, error: Error?)     // Service 已加入 PeripheralManager => 呼叫 `add(_:)` 之後會回來這個事件，若 `error == nil`，代表 service 已成功發布到本機 GATT database，通常這之後就可以開始 advertising
        case advertisingStarted(Error?)                 // 開始 advertising 的結果 => 呼叫 `startAdvertising(_:)` 之後會回來這個事件，若 `error == nil`，代表目前 Peripheral 已開始廣播
        case advertisingStopped                         // 停止 advertising => 這不是 CoreBluetooth 原生 delegate callback，而是 wrapper 在 `stopAdvertising()` 時主動發出的自訂事件
        case subscribed(CBCentral, CBCharacteristic)    // 有 Central 訂閱了某條 characteristic => 常見於 characteristic 具有 `.notify` 或 `.indicate` 屬性時，Peripheral 後續可以透過 `updateValue(...)` 主動把資料推給已訂閱的 Central
        case unsubscribed(CBCentral, CBCharacteristic)  // 有 Central 取消訂閱某條 characteristic => 代表該 Central 不再接收這條 characteristic 的 notify / indicate 更新
        case didReceiveReadRequest(CBATTRequest)        // 收到 Central 的讀取請求 => 當 characteristic 支援 `.read` 時，Central 呼叫 read 後會收到這個事件
        case writeRequests([CBATTRequest])              // 收到來自 Central 的寫入請求 => 當 characteristic 具有 `.write` 或 `.writeWithoutResponse` 能力時，Central 寫入資料後，Peripheral 會在這裡收到 `CBATTRequest` 陣列，可在這裡讀取 `request.value` 並進行資料解析或協議處理
        case readyToUpdateSubscribers                   // 傳送 notify 的 queue 再次可用 => 當 `updateValue(...)` 回傳 `false`，表示底層傳送 queue 已滿；之後會透過這個事件通知外部可以繼續傳送剩餘資料
    }
}

// MARK: - FileTransferError
extension WWBluetoothManager.FileTransferError: LocalizedError {
    
    /// 自訂錯誤訊息
    public var errorDescription: String? {
        
        switch self {
        case .writeFailed(let message): return "Write failed: \(message)"
        case .updateFailed(let message): return "Value update failed: \(message)"
        case .invalidRecord: return "Invalid transfer record"
        case .missingChunks: return "Missing chunks"
        case .peerReturnedError: return "Peer returned error"
        case .invalidTransferId: return "Invalid transfer ID"
        case .invalidPhase: return "Invalid transfer phase"
        case .missingCharacteristic: return "Missing characteristic"
        }
    }
}

// MARK: - AdvertisementDataKey
extension WWBluetoothManager {
    
    /// 廣告資料鍵值常數（CoreBluetooth 標準）
    enum AdvertisementDataKey: String {
        
        case localName = "CBAdvertisementDataLocalNameKey"                      // 設備本地名稱（廣告包中最優先的名稱來源）
        case manufacturerData = "CBAdvertisementDataManufacturerDataKey"        // 設備本地名稱（廣告包中最優先的名稱來源）
        case serviceUUIDs = "CBAdvertisementDataServiceUUIDsKey"                // 廣告中宣告的服務 UUID 列表（設備支援的 GATT 服務）
        case isConnectable = "CBAdvertisementDataIsConnectable"                 // 可連線標記（iOS 11+，指示設備是否接受連線）
    }
}

// MARK: - Event 轉換成文字
extension WWBluetoothManager.ClientEvent: @retroactive CustomStringConvertible {
    
    public var description: String {
        
        switch self {
        case .stateChanged(let state): return "State: \(state.rawValue)"
        case .discovered(let device): return "Discovered: \(device.name) (RSSI: \(device.rssi))"
        case .connected: return "Connected ✅"
        case .disconnected(let device, let error): return "Disconnected: \(device?.name ?? "Unknown") \(error.map { "\($0)" } ?? "")"
        case .servicesDiscovered(_, let services): return "Services: \(services.map { $0.uuidString })"
        case .characteristicsDiscovered(let service, let chars): return "Chars \(service.uuidString): \(chars.map { $0.uuidString })"
        case .notificationEnabled(let uuid): return "Notify ON: \(uuid.uuidString)"
        case .valueUpdated(let uuid, let data): return "Notify \(uuid.uuidString): \(data.map { String(format: "%02x", $0) }.joined())"
        case .writeCompleted(let uuid, let error): return "Write \(uuid.uuidString): \(error.map { "\($0)" } ?? "OK")"
        case .failed(let error): return "Failed: \(error)"
        }
    }
}
