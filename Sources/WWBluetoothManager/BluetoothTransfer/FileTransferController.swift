//
//  FileTransferController.swift
//  WWBluetoothManager
//
//  Created by William.Weng on 2026/5/6.
//
//  狀態機：clientHello → serverHello → ready → data/ack → finish/finishAck

import Foundation
import CoreBluetooth
import WWByteReader

// MARK: - FileTransferController
public extension WWBluetoothManager {
    
    /// 負責管理 BLE 檔案傳輸流程的控制器
    ///
    /// `FileTransferController` 封裝了 sender 與 receiver 兩側的 session 狀態，並提供送檔、收檔、事件分派與封包流程控制等能力
    final class FileTransferController {
        
        public var onReceive: ((Data) -> Void)?                                                     // 當接收端成功重組完整檔案資料後要呼叫的回呼 => 回傳的 `Data` 為依照接收切片順序合併完成的完整資料內容
        
        private var senderSession: SenderSession?                                                   // 傳送端目前使用中的 session
        private var receiverSession: ReceiverSession?                                               // 接收端目前使用中的 session

        public init() {}
    }
}

// MARK: - Public Property
public extension WWBluetoothManager.FileTransferController {
    
    var senderPhase: WWBluetoothManager.FileTransferPhase { senderSession?.phase ?? .idle }         // 目前傳送端的狀態 => 若 sender session 尚未建立，則回傳 `.idle`
    var receiverPhase: WWBluetoothManager.FileTransferPhase { receiverSession?.phase ?? .idle }     // 目前接收端的狀態 => 若 receiver session 尚未建立，則回傳 `.idle`
}

// MARK: - Public API
public extension WWBluetoothManager.FileTransferController {
    
    /// 傳送檔案給指定的藍牙周邊裝置
    ///
    /// 開始送出一筆檔案傳輸流程，此方法會根據目前 peripheral 可寫入的最大長度計算每片 payload 大小與總片數，建立新的 sender session，並先送出 `clientHello` 作為握手起點。實際的資料切片會在後續收到 `serverHello`、`ready` 或 `ack` 後逐步送出。
    ///
    /// - Parameters:
    ///   - peripheral: 目前要寫入資料的遠端裝置
    ///   - fileName: 本次傳輸的檔名
    ///   - typeIdentifier: 本次傳輸檔案的 Uniform Type Identifier，例如 `public.png`
    ///   - data: 要傳送的原始檔案資料
    ///   - controlCharacteristic: 用來傳送控制記錄的 characteristic
    ///   - dataCharacteristic: 用來傳送資料切片的 characteristic
    /// - Throws: 當檔名或型別資訊無法正確寫入握手 payload 時拋出錯誤。
    func sendFile(using peripheral: CBPeripheral, fileName: String, typeIdentifier: String, data: Data, controlCharacteristic: CBCharacteristic, dataCharacteristic: CBCharacteristic) throws {
        
        let chunkSize = maxChunkSize(with: peripheral)
        let helloPayload = try makeHelloPayload(fileName: fileName, typeIdentifier: typeIdentifier, dataSize: data.count, chunkSize: chunkSize)
        
        startSendingHello(with: data, chunkSize: chunkSize, helloPayload: helloPayload, to: peripheral, controlCharacteristic: controlCharacteristic, dataCharacteristic: dataCharacteristic)
    }
    
    /// 準備接收一筆檔案傳輸流程
    ///
    /// 此方法會建立新的 receiver session、保存接收完成後的回呼，並對 control / data characteristics 開啟 notify，讓後續收到的 `clientHello`、`data`、`finish` 等記錄可被處理
    ///
    /// - Parameters:
    ///   - peripheral: 目前要接收資料的遠端裝置
    ///   - controlCharacteristic: 用來接收控制記錄的 characteristic
    ///   - dataCharacteristic: 用來接收資料切片的 characteristic
    ///   - onReceive: 當完整檔案資料重組完成後要呼叫的回呼
    func receiveFile(using peripheral: CBPeripheral, controlCharacteristic: CBCharacteristic, dataCharacteristic: CBCharacteristic, onReceive: @escaping (Data) -> Void) {
        
        self.onReceive = onReceive
        receiverSession = .makeIdle(controlCharacteristic: controlCharacteristic, dataCharacteristic: dataCharacteristic)
        
        peripheral.setNotifyValue(true, for: controlCharacteristic)
        peripheral.setNotifyValue(true, for: dataCharacteristic)
    }
    
    /// 處理來自 `WWBluetoothManager.PeripheralStatus` 的事件，並分派到檔案傳輸流程
    ///
    /// 目前會處理 characteristic 寫入完成與 characteristic 值更新兩種事件，其他與檔案傳輸無關的狀態則會直接忽略
    ///
    /// - Parameters:
    ///   - peripheral: 目前互動中的遠端裝置
    ///   - status: 由藍牙層回傳的 peripheral 狀態事件
    func handle(peripheral: CBPeripheral, status: WWBluetoothManager.PeripheralStatus) {
        
        switch status {
        case .characteristicWriteCompleted(_, let error): handleWriteCompletion(error: error)
        case .characteristicValueUpdated(let characteristic, let data, let error): handleUpdatedValue(peripheral: peripheral, characteristic: characteristic, data: data, error: error)
        default: break
        }
    }
}

// MARK: - 小工具
private extension WWBluetoothManager.FileTransferController {
    
    /// 根據目前 peripheral 可接受的單次寫入上限，計算實際可用的資料 chunk 大小
    ///
    /// - Parameter peripheral: 目前連線中的藍牙周邊裝置
    /// - Returns: 扣除封包表頭後，實際每次可傳送的資料大小，最小為 1
    func maxChunkSize(with peripheral: CBPeripheral) -> Int {
        
        let maximumLength = peripheral.maximumWriteValueLength(for: .withResponse)
        let headerSize = WWBluetoothManager.FileTransferRecord.minimumCount
        
        let chunkSize = max(1, maximumLength - headerSize)
        return chunkSize
    }
    
    /// 建立 client hello 封包要附帶的 payload
    ///
    /// - Parameters:
    ///   - fileName: 要傳送的檔名
    ///   - typeIdentifier: 檔案類型識別字串
    ///   - dataSize: 檔案資料大小
    ///   - chunkSize: 此次傳輸使用的 chunk 大小
    /// - Returns: 編碼完成的 hello payload
    /// - Throws: 當字串寫入失敗時拋出錯誤
    func makeHelloPayload(fileName: String, typeIdentifier: String, dataSize: Int, chunkSize: Int) throws -> Data {
        
        var writer = WWByteWriter()
        
        try writer.writeString(fileName)
        try writer.writeString(typeIdentifier)
        writer.writeInteger(UInt32(dataSize))
        writer.writeInteger(UInt16(chunkSize))
        
        return writer.data
    }
    
    /// 建立 SenderSession，並送出 client hello 給藍牙周邊
    ///
    /// - Parameters:
    ///   - data: 準備傳送的完整資料
    ///   - chunkSize: 每個資料分段的大小
    ///   - helloPayload: client hello 要附帶的 payload
    ///   - peripheral: 目前連線中的藍牙周邊裝置
    ///   - controlCharacteristic: 控制訊息使用的 characteristic
    ///   - dataCharacteristic: 資料傳輸使用的 characteristic
    func startSendingHello(with data: Data, chunkSize: Int, helloPayload: Data, to peripheral: CBPeripheral, controlCharacteristic: CBCharacteristic, dataCharacteristic: CBCharacteristic) {
        
        let senderSession = WWBluetoothManager.SenderSession.makeWaitingServerHello(with: data, chunkSize: chunkSize, controlCharacteristic: controlCharacteristic, dataCharacteristic: dataCharacteristic)
        
        self.senderSession = senderSession
        
        let hello = WWBluetoothManager.FileTransferRecord.makeClientHello(from: senderSession, payload: helloPayload)
        peripheral.writeValue(hello.encode(), for: senderSession.controlCharacteristic!, type: .withResponse)
    }
}

// MARK: - Event handling
private extension WWBluetoothManager.FileTransferController {
    
    /// 處理 characteristic 寫入完成事件
    ///
    /// 若寫入成功，這個方法不會額外推進流程；若寫入失敗，則會將目前存在的 sender 與 receiver session 都標記為 `.failed(.writeFailed(...))`，讓上層可感知本次傳輸失敗
    ///
    /// - Parameter error: BLE 寫入完成時回傳的錯誤資訊
    func handleWriteCompletion(error: Error?) {
        
        guard let error else { return }
        handleErrorAction(.writeFailed(error.localizedDescription))
    }

    /// 處理 characteristic 值更新事件
    ///
    /// 若更新過程發生錯誤，會將目前 sender 與 receiver session 標記為 `.failed(.updateFailed(...))`；若成功收到資料，則會嘗試將原始 Data 解碼為 `FileTransferRecord`，並交由 `handleRecord(...)` 繼續分派到對應的流程處理方法
    ///
    /// - Parameters:
    ///   - peripheral: 目前互動中的遠端裝置
    ///   - characteristic: 觸發值更新事件的 characteristic
    ///   - data: characteristic 目前收到的原始資料
    ///   - error: 值更新時回傳的錯誤資訊
    func handleUpdatedValue(peripheral: CBPeripheral, characteristic: CBCharacteristic, data: Data?, error: Error?) {
        
        if let error { handleErrorAction(.updateFailed(error.localizedDescription)); return }
        
        // 只有在成功取得資料且能解碼成 record 時，才繼續後續流程。
        guard let data,
              let record = try? WWBluetoothManager.FileTransferRecord.decode(from: data)
        else {
            return
        }
        
        handleRecord(peripheral: peripheral, characteristic: characteristic, record: record)
    }
    
    /// 根據 record 類型分派到對應的 sender / receiver 處理流程
    ///
    /// 這個方法是檔案傳輸狀態機的事件分流入口，會依照 `record.type` 將事件轉交給對應的 handler，例如握手流程、資料接收、ACK 推進、完成通知或錯誤處理
    ///
    /// - Parameters:
    ///   - peripheral: 目前互動中的遠端裝置
    ///   - characteristic: 收到此 record 的 characteristic
    ///   - record: 已解碼完成的檔案傳輸記錄
    func handleRecord(peripheral: CBPeripheral, characteristic: CBCharacteristic, record: WWBluetoothManager.FileTransferRecord) {
        
        switch record.type {
        case .clientHello: handleClientHello(peripheral: peripheral, characteristic: characteristic, record: record)
        case .serverHello: handleServerHello(peripheral: peripheral, characteristic: characteristic, record: record)
        case .ready: handleReady(peripheral: peripheral, characteristic: characteristic, record: record)
        case .data: handleDataRecord(peripheral: peripheral, characteristic: characteristic, record: record)
        case .ack: handleAck(peripheral: peripheral, characteristic: characteristic, record: record)
        case .finish: handleFinish(peripheral: peripheral, characteristic: characteristic, record: record)
        case .finishAck: handleFinishAck(record: record)
        case .error: handleErrorRecord(record: record)
        }
    }
    
    /// 將目前存在的 sender 與 receiver session 標記為失敗狀態
    ///
    /// 這個方法用於集中處理共用的錯誤收斂邏輯，避免在不同事件入口重複撰寫 sender / receiver session 的 phase 更新程式碼
    ///
    /// - Parameter error: 本次傳輸要標記的失敗原因
    func handleErrorAction(_ error: WWBluetoothManager.FileTransferError) {
        
        let phase = WWBluetoothManager.FileTransferPhase.failed(error)
        
        if var senderSession {
            senderSession.phase = phase
            self.senderSession = senderSession
        }
        
        if var receiverSession {
            receiverSession.phase = phase
            self.receiverSession = receiverSession
        }
    }
}

// MARK: - Receiver flow
private extension WWBluetoothManager.FileTransferController {
    
    /// 處理傳送端送來的 `clientHello` 記錄
    ///
    /// 當接收端收到新的 `clientHello` 時，代表一輪新的檔案傳輸即將開始。此時會使用 record 內的 `transferId` 與 `total` 重建 receiver session，清空先前已接收的切片資料，並回送 `serverHello` 告知對端可進入下一階段
    ///
    /// - Parameters:
    ///   - peripheral: 目前互動中的遠端裝置
    ///   - characteristic: 收到 `clientHello` 的 characteristic
    ///   - record: 已解碼的 `clientHello` 記錄
    func handleClientHello(peripheral: CBPeripheral, characteristic: CBCharacteristic, record: WWBluetoothManager.FileTransferRecord) {
        
        guard var session = receiverSession,
              characteristic.uuid == session.controlCharacteristic?.uuid
        else {
            return
        }
                
        session = .makeWaitingReady(from: session, record: record)
        receiverSession = session
        
        guard let controlCharacteristic = session.controlCharacteristic else { return }
        
        let serverHello = WWBluetoothManager.FileTransferRecord.makeServerHello(from: record)
        peripheral.writeValue(serverHello.encode(), for: controlCharacteristic, type: .withResponse)
    }
    
    /// 處理傳送端送來的資料切片 `data` 記錄
    ///
    /// 接收端會依照 `record.index` 將 payload 暫存到 `receivedChunks` 中，並在成功接收該片後回送對應的 `ack`，通知 sender 可繼續傳送下一片
    ///
    /// - Parameters:
    ///   - peripheral: 目前互動中的遠端裝置
    ///   - characteristic: 收到資料切片的 characteristic
    ///   - record: 已解碼的 `data` 記錄
    func handleDataRecord(peripheral: CBPeripheral, characteristic: CBCharacteristic, record: WWBluetoothManager.FileTransferRecord) {
        
        guard var session = receiverSession,
              characteristic.uuid == session.dataCharacteristic?.uuid,
              record.transferId == session.transferId
        else {
            return
        }
        
        session.phase = .receivingData
        session.receivedChunks[record.index] = record.payload
        
        receiverSession = session
        
        guard let controlCharacteristic = session.controlCharacteristic else { return }
        
        let ack = WWBluetoothManager.FileTransferRecord.makeAck(from: record)
        peripheral.writeValue(ack.encode(), for: controlCharacteristic, type: .withResponse)
    }
    
    /// 處理傳送端送來的 `finish` 記錄
    ///
    /// 當接收端收到 `finish`，表示 sender 已宣告所有資料片段都已送完。接收端會先檢查目前收到的切片數量是否完整，若有缺片則回送 `error`；若切片完整，則依 index 順序合併成完整資料，透過 `onReceive` 回傳給上層，最後再回送 `finishAck` 表示本次接收完成
    ///
    /// - Parameters:
    ///   - peripheral: 目前互動中的遠端裝置
    ///   - characteristic: 收到 `finish` 的 characteristic
    ///   - record: 已解碼的 `finish` 記錄
    func handleFinish(peripheral: CBPeripheral, characteristic: CBCharacteristic, record: WWBluetoothManager.FileTransferRecord) {
        
        guard var session = receiverSession,
              characteristic.uuid == session.dataCharacteristic?.uuid,
              record.transferId == session.transferId,
              let controlCharacteristic = session.controlCharacteristic
        else {
            return
        }
                
        let chunks = (0..<record.total).compactMap { session.receivedChunks[$0] }
        
        guard chunks.count == Int(record.total) else {

            let errorRecord = WWBluetoothManager.FileTransferRecord.makeError(from: record)
            
            peripheral.writeValue(errorRecord.encode(), for: controlCharacteristic, type: .withResponse)
            session.phase = .failed(.missingChunks)
            receiverSession = session
            return
        }
        
        let fileData = chunks.reduce(into: Data()) { $0.append($1) }
        onReceive?(fileData)
        
        session.phase = .completed
        receiverSession = session
        
        let finishAck = WWBluetoothManager.FileTransferRecord.makeFinishAck(from: record)
        peripheral.writeValue(finishAck.encode(), for: controlCharacteristic, type: .withResponse)
    }
}

// MARK: - Sender flow
private extension WWBluetoothManager.FileTransferController {
    
    /// 處理接收端回傳的 `serverHello` 記錄
    ///
    /// 當 sender 在送出 `clientHello` 後收到對端的 `serverHello`，代表握手流程已進入下一階段。此時 sender 會先回送 `ready`，再將狀態切換為 `.sendingData`，並開始送出第一片資料
    ///
    /// - Parameters:
    ///   - peripheral: 目前互動中的遠端裝置
    ///   - characteristic: 收到 `serverHello` 的 characteristic
    ///   - record: 已解碼的 `serverHello` 記錄
    func handleServerHello(peripheral: CBPeripheral, characteristic: CBCharacteristic, record: WWBluetoothManager.FileTransferRecord) {
        
        guard var session = senderSession,
              characteristic.uuid == session.controlCharacteristic?.uuid,
              session.phase == .waitingServerHello,
              record.transferId == session.transferId,
              let controlCharacteristic = session.controlCharacteristic
        else {
            return
        }
        
        let ready = WWBluetoothManager.FileTransferRecord.makeReady(from: record)
        peripheral.writeValue(ready.encode(), for: controlCharacteristic, type: .withResponse)
        
        session.phase = .sendingData
        senderSession = session
        
        sendNextChunk(using: peripheral)
    }
    
    /// 處理 `ready` 記錄，表示接收端已準備好接收資料
    ///
    /// 在某些傳輸流程下，sender 會在收到 `ready` 後正式進入 `.sendingData`，並開始推進資料片段的傳送
    ///
    /// - Parameters:
    ///   - peripheral: 目前互動中的遠端裝置
    ///   - characteristic: 收到 `ready` 的 characteristic
    ///   - record: 已解碼的 `ready` 記錄
    func handleReady(peripheral: CBPeripheral, characteristic: CBCharacteristic, record: WWBluetoothManager.FileTransferRecord) {
        
        guard var session = senderSession,
              characteristic.uuid == session.controlCharacteristic?.uuid,
              record.transferId == session.transferId
        else {
            return
        }
        
        session.phase = .sendingData
        senderSession = session
        
        sendNextChunk(using: peripheral)
    }
    
    /// 處理接收端回傳的 `ack` 記錄
    ///
    /// 每收到一筆 ACK，表示目前索引對應的資料片段已被對端接受 => sender 會將 `sendingIndex` 往後遞增，並繼續送出下一片資料。
    ///
    /// - Parameters:
    ///   - peripheral: 目前互動中的遠端裝置
    ///   - characteristic: 收到 ACK 的 characteristic
    ///   - record: 已解碼的 ACK 記錄
    func handleAck(peripheral: CBPeripheral, characteristic: CBCharacteristic, record: WWBluetoothManager.FileTransferRecord) {
        
        guard var session = senderSession,
              characteristic.uuid == session.controlCharacteristic?.uuid,
              session.phase == .sendingData,
              record.transferId == session.transferId
        else {
            return
        }
        
        session.sendingIndex = record.index + 1
        senderSession = session
        
        sendNextChunk(using: peripheral)
    }
    
    /// 處理接收端回傳的 `finishAck` 記錄
    ///
    /// 當 sender 收到 `finishAck`，表示對端已完成本次傳輸的接收與處理，sender 可將本次傳輸狀態標記為 `.completed`
    ///
    /// - Parameter record: 已解碼的 `finishAck` 記錄
    func handleFinishAck(record: WWBluetoothManager.FileTransferRecord) {
        
        guard var session = senderSession,
              record.transferId == session.transferId
        else {
            return
        }
                
        session.phase = .completed
        senderSession = session
    }
    
    /// 處理對端回傳的錯誤記錄
    ///
    /// 若錯誤記錄的 `transferId` 與目前 sender 或 receiver session 相符，則將對應 session 的狀態標記為 `.failed(.peerReturnedError)`，表示本次傳輸已由對端主動宣告失敗
    ///
    /// - Parameter record: 已解碼的錯誤記錄
    func handleErrorRecord(record: WWBluetoothManager.FileTransferRecord) {
        
        if var session = senderSession, record.transferId == session.transferId {
            session.phase = .failed(.peerReturnedError)
            senderSession = session
        }
        
        if var session = receiverSession, record.transferId == session.transferId {
            session.phase = .failed(.peerReturnedError)
            receiverSession = session
        }
    }
}

// MARK: - Sender helpers
private extension WWBluetoothManager.FileTransferController {
    
    /// 根據目前 sender session 的狀態送出下一筆資料 => 只有在正式送資料階段才允許推進下一片，避免握手或完成階段誤送資料
    ///
    /// 這個方法是傳送端的主要推進點：
    /// - 若目前不在 `.sendingData` 階段，則不進行任何動作
    /// - 若尚有資料片段未送完，則送出目前索引對應的 data record
    /// - 若所有片段都已送完，則改送 finish record，通知對端資料傳輸完成
    ///
    /// - Parameter peripheral: 目前要寫入資料的遠端裝置。
    func sendNextChunk(using peripheral: CBPeripheral) {
        
        guard let session = senderSession,
              let dataCharacteristic = session.dataCharacteristic,
              session.phase == .sendingData
        else {
            return
        }
        
        guard session.sendingIndex < session.totalChunks else { sendFinishRecord(using: peripheral, for: dataCharacteristic); return }
        sendCurrentDataChunk(using: peripheral, for: dataCharacteristic)
    }
    
    /// 送出 finish record，通知接收端本次資料切片已全部傳送完成。
    ///
    /// 傳送 finish 後，sender 會切換到 `.waitingFinishAck`，表示不再送出新的 data record，而是等待接收端回傳 finishAck，finish 只代表 sender 已送完，不代表 receiver 已成功重組完成
    ///
    /// - Parameters:
    ///   - peripheral: 目前要寫入資料的遠端裝置
    ///   - dataCharacteristic: 用來送出完成通知的資料 characteristic
    func sendFinishRecord(using peripheral: CBPeripheral, for dataCharacteristic: CBCharacteristic) {
        
        guard var session = senderSession else { return }
        
        session.phase = .waitingFinishAck
        senderSession = session
        
        let record = WWBluetoothManager.FileTransferRecord.makeFinish(from: session)
        peripheral.writeValue(record.encode(), for: dataCharacteristic, type: .withResponse)
    }
    
    /// 送出目前索引對應的 data record
    ///
    /// 這個方法會先建立目前切片的資料 record，再編碼成可寫入 characteristic 的 Data，最後透過 BLE 寫入對端
    ///
    /// - Parameters:
    ///   - peripheral: 目前要寫入資料的遠端裝置
    ///   - dataCharacteristic: 用來送出資料切片的 characteristic
    func sendCurrentDataChunk(using peripheral: CBPeripheral, for dataCharacteristic: CBCharacteristic) {
        
        let record = makeCurrentDataChunkRecord()
        let encoded = record.encode()
        
        peripheral.writeValue(encoded, for: dataCharacteristic, type: .withResponse)
    }
    
    /// 建立目前 `sendingIndex` 對應的資料封包
    ///
    /// record 的 payload 內容來自 `currentChunkPayload(session:)`，並帶入本次傳輸所使用的 `transferId`、目前切片索引與總片數
    ///
    /// - Returns: 可直接送出的資料 record
    func makeCurrentDataChunkRecord() -> WWBluetoothManager.FileTransferRecord {
        
        guard let session = senderSession else { return .emptyData }
        
        let payload = currentChunkPayload(session: session)
        return .makeData(from: session, payload: payload)
    }

    /// 取出目前 `sendingIndex` 所對應的原始 payload 資料。
    ///
    /// 此方法會根據 `chunkSize` 將 `sendingData` 切成固定大小的片段，並回傳目前索引所對應的那一片內容。若計算出的範圍無效，表示目前沒有可送出的資料片段，此時會回傳空的 `Data`
    ///
    /// - Parameter session: 本次傳輸使用中的 sender session
    /// - Returns: 本次應送出的 payload 內容
    func currentChunkPayload(session: WWBluetoothManager.SenderSession) -> Data {
        
        let startIndex = Int(session.sendingIndex) * session.chunkSize
        let endIndex = min(startIndex + session.chunkSize, session.sendingData.count)
        
        guard startIndex < endIndex, startIndex < session.sendingData.count else { return .init() }
        return session.sendingData.subdata(in: startIndex..<endIndex)
    }
}

