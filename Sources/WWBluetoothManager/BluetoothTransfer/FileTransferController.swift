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
    
    final class FileTransferController {
        
        public var onReceive: ((Data) -> Void)?
        
        public var senderPhase: FileTransferPhase {
            senderSession?.phase ?? .idle
        }
        
        public var receiverPhase: FileTransferPhase {
            receiverSession?.phase ?? .idle
        }
        
        private var senderSession: SenderSession?
        private var receiverSession: ReceiverSession?
        
        public init() {}
    }
}

// MARK: - Public API
public extension WWBluetoothManager.FileTransferController {
    
    func sendFile(
        using peripheral: CBPeripheral,
        fileName: String,
        typeIdentifier: String,
        data: Data,
        controlCharacteristic: CBCharacteristic,
        dataCharacteristic: CBCharacteristic
    ) {
        
        let maximumLength = peripheral.maximumWriteValueLength(for: .withResponse)
        let headerSize = WWBluetoothManager.FileTransferRecord.minimumCount
        let chunkSize = max(1, maximumLength - headerSize)
        let totalChunks = UInt32((data.count + chunkSize - 1) / chunkSize)
        let transferId = UInt32.random(in: .min ... .max)
        
        var writer = WWByteWriter()
        try! writer.writeString(fileName)
        try! writer.writeString(typeIdentifier)
        writer.writeInteger(UInt32(data.count))
        writer.writeInteger(UInt16(chunkSize))
        
        senderSession = WWBluetoothManager.SenderSession(
            phase: .waitingServerHello,
            transferId: transferId,
            totalChunks: totalChunks,
            chunkSize: chunkSize,
            controlCharacteristic: controlCharacteristic,
            dataCharacteristic: dataCharacteristic,
            sendingData: data,
            sendingIndex: 0
        )
        
        let hello = WWBluetoothManager.FileTransferRecord(
            type: .clientHello,
            transferId: transferId,
            index: 0,
            total: totalChunks,
            payload: writer.data
        )
        
        peripheral.writeValue(hello.encode(), for: controlCharacteristic, type: .withResponse)
    }
    
    func receiveFile(
        using peripheral: CBPeripheral,
        controlCharacteristic: CBCharacteristic,
        dataCharacteristic: CBCharacteristic,
        onReceive: @escaping (Data) -> Void
    ) {
        
        self.onReceive = onReceive
        
        receiverSession = WWBluetoothManager.ReceiverSession(
            phase: .idle,
            transferId: 0,
            expectedTotalChunks: 0,
            controlCharacteristic: controlCharacteristic,
            dataCharacteristic: dataCharacteristic,
            receivedChunks: [:]
        )
        
        peripheral.setNotifyValue(true, for: controlCharacteristic)
        peripheral.setNotifyValue(true, for: dataCharacteristic)
    }
    
    func handle(peripheral: CBPeripheral, status: WWBluetoothManager.PeripheralStatus) {
        
        switch status {
        case .characteristicWriteCompleted(_, let error):
            handleWriteCompletion(error: error)
            
        case .characteristicValueUpdated(let characteristic, let data, let error):
            handleUpdatedValue(peripheral: peripheral, characteristic: characteristic, data: data, error: error)
            
        default:
            break
        }
    }
}

// MARK: - Event handling
private extension WWBluetoothManager.FileTransferController {
    
    func handleWriteCompletion(error: Error?) {
        
        guard let error else { return }
        
        if var senderSession {
            senderSession.phase = .failed(.writeFailed(error.localizedDescription))
            self.senderSession = senderSession
        }
        
        if var receiverSession {
            receiverSession.phase = .failed(.writeFailed(error.localizedDescription))
            self.receiverSession = receiverSession
        }
    }
    
    func handleUpdatedValue(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        data: Data?,
        error: Error?
    ) {
        
        if let error {
            
            if var senderSession {
                senderSession.phase = .failed(.updateFailed(error.localizedDescription))
                self.senderSession = senderSession
            }
            
            if var receiverSession {
                receiverSession.phase = .failed(.updateFailed(error.localizedDescription))
                self.receiverSession = receiverSession
            }
            
            return
        }
        
        guard let data,
              let record = try? WWBluetoothManager.FileTransferRecord.decode(from: data)
        else {
            return
        }
        
        handleRecord(peripheral: peripheral, characteristic: characteristic, record: record)
    }
    
    func handleRecord(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        record: WWBluetoothManager.FileTransferRecord
    ) {
        
        switch record.type {
        case .clientHello:
            handleClientHello(peripheral: peripheral, characteristic: characteristic, record: record)
            
        case .serverHello:
            handleServerHello(peripheral: peripheral, characteristic: characteristic, record: record)
            
        case .ready:
            handleReady(peripheral: peripheral, characteristic: characteristic, record: record)
            
        case .data:
            handleDataRecord(peripheral: peripheral, characteristic: characteristic, record: record)
            
        case .ack:
            handleAck(peripheral: peripheral, characteristic: characteristic, record: record)
            
        case .finish:
            handleFinish(peripheral: peripheral, characteristic: characteristic, record: record)
            
        case .finishAck:
            handleFinishAck(record: record)
            
        case .error:
            handleErrorRecord(record: record)
        }
    }
}

// MARK: - Receiver flow
private extension WWBluetoothManager.FileTransferController {
    
    /// 處理傳送端送來的 `clientHello` 記錄。
    ///
    /// 當接收端收到新的 `clientHello` 時，代表一輪新的檔案傳輸即將開始。
    /// 此時會使用 record 內的 `transferId` 與 `total` 重建 receiver session，
    /// 清空先前已接收的切片資料，並回送 `serverHello` 告知對端可進入下一階段。
    ///
    /// - Parameters:
    ///   - peripheral: 目前互動中的遠端裝置。
    ///   - characteristic: 收到 `clientHello` 的 characteristic。
    ///   - record: 已解碼的 `clientHello` 記錄。
    func handleClientHello(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        record: WWBluetoothManager.FileTransferRecord
    ) {
        
        guard var session = receiverSession else { return }
        guard characteristic.uuid == session.controlCharacteristic?.uuid else { return }
        
        // 收到新的 clientHello 時，建立新的 receiver session，
        // 避免前一輪傳輸殘留的狀態污染本次接收流程。
        session = WWBluetoothManager.ReceiverSession(
            phase: .waitingReady,
            transferId: record.transferId,
            expectedTotalChunks: record.total,
            controlCharacteristic: session.controlCharacteristic,
            dataCharacteristic: session.dataCharacteristic,
            receivedChunks: [:]
        )
        
        receiverSession = session
        
        guard let controlCharacteristic = session.controlCharacteristic else { return }
        
        let serverHello = WWBluetoothManager.FileTransferRecord(
            type: .serverHello,
            transferId: record.transferId,
            index: 0,
            total: record.total
        )
        
        peripheral.writeValue(serverHello.encode(), for: controlCharacteristic, type: .withResponse)
    }
    
    /// 處理傳送端送來的資料切片 `data` 記錄。
    ///
    /// 接收端會依照 `record.index` 將 payload 暫存到 `receivedChunks` 中，
    /// 並在成功接收該片後回送對應的 `ack`，通知 sender 可繼續傳送下一片。
    ///
    /// - Parameters:
    ///   - peripheral: 目前互動中的遠端裝置。
    ///   - characteristic: 收到資料切片的 characteristic。
    ///   - record: 已解碼的 `data` 記錄。
    func handleDataRecord(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        record: WWBluetoothManager.FileTransferRecord
    ) {
        
        guard var session = receiverSession else { return }
        guard characteristic.uuid == session.dataCharacteristic?.uuid else { return }
        guard record.transferId == session.transferId else { return }
        
        // 將收到的 payload 依 index 暫存，支援之後依序重組完整資料。
        session.phase = .receivingData
        session.receivedChunks[record.index] = record.payload
        
        receiverSession = session
        
        guard let controlCharacteristic = session.controlCharacteristic else { return }
        
        let ack = WWBluetoothManager.FileTransferRecord(
            type: .ack,
            transferId: record.transferId,
            index: record.index,
            total: record.total
        )
        
        peripheral.writeValue(ack.encode(), for: controlCharacteristic, type: .withResponse)
    }
    
    /// 處理傳送端送來的 `finish` 記錄。
    ///
    /// 當接收端收到 `finish`，表示 sender 已宣告所有資料片段都已送完。接收端會先檢查目前收到的切片數量是否完整，若有缺片則回送 `error`；若切片完整，則依 index 順序合併成完整資料，透過 `onReceive` 回傳給上層，最後再回送 `finishAck` 表示本次接收完成。
    ///
    /// - Parameters:
    ///   - peripheral: 目前互動中的遠端裝置。
    ///   - characteristic: 收到 `finish` 的 characteristic。
    ///   - record: 已解碼的 `finish` 記錄。
    func handleFinish(peripheral: CBPeripheral, characteristic: CBCharacteristic, record: WWBluetoothManager.FileTransferRecord) {
        
        guard var session = receiverSession,
              characteristic.uuid == session.dataCharacteristic?.uuid,
              record.transferId == session.transferId,
              let controlCharacteristic = session.controlCharacteristic
        else {
            return
        }
        
        // 依照 0..<total 的順序取出所有已接收的 chunk，
        // 確保最終合併的資料順序與原始傳輸順序一致。
        let chunks = (0..<record.total).compactMap { session.receivedChunks[$0] }
        
        // 若實際收齊的 chunk 數量不足，表示本次傳輸資料不完整，
        // 回送 error 並將 receiver 狀態標記為失敗。
        guard chunks.count == Int(record.total) else {
            
            let errorRecord = WWBluetoothManager.FileTransferRecord(
                type: .error,
                transferId: record.transferId,
                index: 0,
                total: record.total
            )
            
            peripheral.writeValue(errorRecord.encode(), for: controlCharacteristic, type: .withResponse)
            session.phase = .failed(.missingChunks)
            receiverSession = session
            return
        }
        
        // 將所有切片依序合併回完整資料。
        let fileData = chunks.reduce(into: Data()) { $0.append($1) }
        
        onReceive?(fileData)
        
        session.phase = .completed
        receiverSession = session
        
        let finishAck = WWBluetoothManager.FileTransferRecord(
            type: .finishAck,
            transferId: record.transferId,
            index: record.total,
            total: record.total
        )
        
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
        
        let ready = WWBluetoothManager.FileTransferRecord(type: .ready, transferId: record.transferId, index: 0, total: record.total)
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
    /// - Parameter record: 已解碼的 `finishAck` 記錄。
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
    /// 若錯誤記錄的 `transferId` 與目前 sender 或 receiver session 相符，則將對應 session 的狀態標記為 `.failed(.peerReturnedError)`，表示本次傳輸已由對端主動宣告失敗。
    ///
    /// - Parameter record: 已解碼的錯誤記錄。
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
        
        let record = WWBluetoothManager.FileTransferRecord(type: .finish, transferId: session.transferId, index: session.totalChunks, total: session.totalChunks)
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
        return .init(type: .data, transferId: session.transferId, index: session.sendingIndex, total: session.totalChunks, payload: payload)
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

