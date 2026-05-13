//
//  FileTransferController.swift
//  WWBluetoothManager
//
//  Created by WilliamWeng on 2026/5/6.
//
//  狀態機：clientHello → serverHello → ready → data/ack → finish/finishAck

import Foundation
import CoreBluetooth
import WWByteReader

// MARK: - FileTransferController
public extension WWBluetoothManager {
    
    /// 檔案傳輸協議的流程控制器 => 它的角色是「協議狀態機」，不是 BLE manager 本身，使用上通常會由使用者自行決定何時呼叫 `sendFile(...)` 或 `receiveFile(...)`
    final class FileTransferController {
        
        public var onReceive: ((Data) -> Void)?                     // 當完整檔案接收完成時呼叫的回呼，回傳組裝完成的 `Data`
        
        public private(set) var phase: FileTransferPhase = .idle    // 目前檔案傳輸流程的狀態 => 可用來判斷目前是待命、握手中、傳輸中、等待完成確認，或是已完成 / 已失敗
        public private(set) var transferId: UInt32 = 0              // 本次檔案傳輸的識別碼 => 同一次傳輸中的所有 record 都會共用相同的 `transferId`
        public private(set) var totalChunks: UInt32 = 0             // 本次傳輸預計的總片數 => 傳送端用它控制送出進度；接收端用它判斷是否已收齊所有片段
        public private(set) var chunkSize: Int = 20                 // 本次傳輸實際採用的單片資料大小 => 一般會根據 BLE `maximumWriteValueLength` 扣掉 header 後計算而得
        
        private var controlCharacteristic: CBCharacteristic?        // 用來傳送握手與控制訊息的 characteristic
        private var dataCharacteristic: CBCharacteristic?           // 用來傳送資料片段的 characteristic
        private var sendingData = Data()                            // 準備傳送的完整檔案資料
        private var sendingIndex: UInt32 = 0                        // 本次傳輸中，下一個要送出的資料切片索引（0 起始）
        private var receivedChunks: [UInt32: Data] = [:]            // 本次傳輸中，接收端已收到的資料切片，key 為索引，用於重組檔案
        private var expectedTotalChunks: UInt32 = 0                 // 本次傳輸預期的資料切片總數
        
        /// 建立一個新的檔案傳輸控制器 => 一般情況下，一個連線流程可持有一個 controller 實例，由使用者在 delegate 中決定是否啟用它。
        public init() {}
    }
}

// MARK: - 公開 API
public extension WWBluetoothManager.FileTransferController {
    
    /// 啟動檔案傳輸流程，並送出第一個 `clientHello` 封包 => `clientHello` 的 payload 格式目前為：`[fileSize: UInt32 | preferredChunkSize: UInt16]`
    /// 這個方法會：
    /// - 保存本次傳輸所需的 characteristic 與檔案資料
    /// - 根據目前 peripheral 可接受的最大寫入長度，計算單片資料大小
    /// - 計算總片數並建立新的 `transferId`
    /// - 組出握手所需的 `clientHello` payload
    /// - 透過 control characteristic 送出第一筆握手封包
    /// - Parameters:
    ///   - peripheral: 目前已連線的遠端裝置
    ///   - data: 準備傳送的完整檔案資料
    ///   - controlCharacteristic: 用來傳送握手與控制訊息的 characteristic
    ///   - dataCharacteristic: 用來傳送資料片段的 characteristic
    func sendFile(using peripheral: CBPeripheral, fileName: String, typeIdentifier: String, data: Data, controlCharacteristic: CBCharacteristic, dataCharacteristic: CBCharacteristic) {
        
        let maximumLength = peripheral.maximumWriteValueLength(for: .withResponse)
        let headerSize = WWBluetoothManager.FileTransferRecord.minimumCount
        
        var writer = WWByteWriter()

        self.controlCharacteristic = controlCharacteristic
        self.dataCharacteristic = dataCharacteristic
        self.sendingData = data
        self.sendingIndex = 0
        self.transferId = UInt32.random(in: .min ... .max)
        self.chunkSize = max(1, maximumLength - headerSize)
        self.totalChunks = UInt32((data.count + chunkSize - 1) / chunkSize)
        self.phase = .waitingServerHello
        
        try! writer.writeString(fileName)
        try! writer.writeString(typeIdentifier)
        writer.writeInteger(UInt32(data.count))
        writer.writeInteger(UInt16(chunkSize))
        
        let hello = WWBluetoothManager.FileTransferRecord(
            type: .clientHello,
            transferId: transferId,
            index: 0,
            total: totalChunks,
            payload: writer.data
        )
        
        let encoded = hello.encode()
        
        print("encoded data record head => \(encoded.prefix(24).map { String(format: "%02X", $0) }.joined(separator: " "))")
        print("sendFile => generated transferId: \(self.transferId)")
        print("sendFile => hello hex: \(encoded.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        peripheral.writeValue(encoded, for: controlCharacteristic, type: .withResponse)
    }
    
    /// 初始化檔案接收流程，並開始監聽控制與資料 characteristic 的通知 => 開啟通知後，後續收到的封包資料會透過 `CBPeripheralDelegate` 回傳，並由外部流程再進一步解析成 `FileTransferRecord`
    /// 這個方法會：
    /// - 保存本次接收流程所需的 characteristic 與完成回呼
    /// - 重設目前接收狀態與暫存資料
    /// - 對 control characteristic 與 data characteristic 開啟通知訂閱
    /// - Parameters:
    ///   - peripheral: 目前已連線的遠端裝置
    ///   - controlCharacteristic: 用來接收握手與控制訊息的 characteristic
    ///   - dataCharacteristic: 用來接收資料片段的 characteristic
    ///   - onReceive: 當完整檔案接收完成時呼叫的回呼，回傳組裝完成的 `Data`
    func receiveFile(using peripheral: CBPeripheral, controlCharacteristic: CBCharacteristic, dataCharacteristic: CBCharacteristic, onReceive: @escaping (Data) -> Void) {
        
        self.controlCharacteristic = controlCharacteristic
        self.dataCharacteristic = dataCharacteristic
        self.onReceive = onReceive
        self.phase = .idle
        self.receivedChunks.removeAll()
        self.expectedTotalChunks = 0
        
        peripheral.setNotifyValue(true, for: controlCharacteristic)
        peripheral.setNotifyValue(true, for: dataCharacteristic)
    }
    
    /// 處理藍牙周邊裝置回傳的狀態事件。
    /// - Parameters:
    ///   - peripheral: 目前互動中的藍牙周邊裝置
    ///   - status: 周邊裝置回傳的狀態
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
    
    /// 處理 characteristic 寫入完成事件
    /// - Parameter error: 寫入失敗時的錯誤資訊
    func handleWriteCompletion(error: Error?) {
        guard let error else { return }
        phase = .failed(.writeFailed(error.localizedDescription))
    }
    
    /// 處理 characteristic 資料更新事件
    /// - Parameters:
    ///   - peripheral: 目前互動中的藍牙周邊裝置
    ///   - characteristic: 回傳資料的 characteristic
    ///   - data: characteristic 回傳的原始資料
    ///   - error: 更新失敗時的錯誤資訊
    func handleUpdatedValue(peripheral: CBPeripheral, characteristic: CBCharacteristic, data: Data?, error: Error?) {
        
        if let error { phase = .failed(.updateFailed(error.localizedDescription)); return }
        
        guard let data,
              let record = try? WWBluetoothManager.FileTransferRecord.decode(from: data)
        else {
            return
        }
        
        handleRecord(peripheral: peripheral, characteristic: characteristic, record: record)
    }
    
    /// 根據收到的傳輸記錄類型分派對應處理流程。
    /// - Parameters:
    ///   - peripheral: 目前互動中的藍牙周邊裝置
    ///   - characteristic: 回傳資料的 characteristic
    ///   - record: 已解碼的傳輸記錄
    func handleRecord(peripheral: CBPeripheral, characteristic: CBCharacteristic, record: WWBluetoothManager.FileTransferRecord) {
        
        switch record.type {
        case .clientHello: handleClientHello(peripheral: peripheral, record: record)
        case .serverHello: handleServerHello(peripheral: peripheral, record: record)
        case .ready: handleReady(peripheral: peripheral, record: record)
        case .data: handleDataRecord(peripheral: peripheral, characteristic: characteristic, record: record)
        case .ack: handleAck(peripheral: peripheral, record: record)
        case .finish: handleFinish(peripheral: peripheral, record: record)
        case .finishAck: handleFinishAck(record: record)
        case .error: handleErrorRecord()
        }
    }
}

// MARK: - 小工具
private extension WWBluetoothManager.FileTransferController {
    
    /// 處理接收端發來的 clientHello
    /// - Parameters:
    ///   - peripheral: 目前互動中的藍牙周邊裝置
    ///   - record: clientHello 記錄
    func handleClientHello(peripheral: CBPeripheral, record: WWBluetoothManager.FileTransferRecord) {
        
        guard phase == .idle || phase == .receivingData || phase == .waitingReady else {
            print("handleClientHello => ignore, current phase: \(phase)")
            return
        }
        
        transferId = record.transferId
        expectedTotalChunks = record.total
        receivedChunks.removeAll()
        phase = .waitingReady
        
        guard let controlCharacteristic else { return }
        
        let serverHello = WWBluetoothManager.FileTransferRecord(
            type: .serverHello,
            transferId: record.transferId,
            index: 0,
            total: record.total
        )
        
        peripheral.writeValue(serverHello.encode(), for: controlCharacteristic, type: .withResponse)
    }
    
    /// 處理傳送端收到的 serverHello
    /// - Parameters:
    ///   - peripheral: 目前互動中的藍牙周邊裝置
    ///   - record: serverHello 記錄
    func handleServerHello(peripheral: CBPeripheral, record: WWBluetoothManager.FileTransferRecord) {
        
        print("handleServerHello => phase: \(phase)")
        print("handleServerHello => record.transferId: \(record.transferId)")
        print("handleServerHello => self.transferId: \(transferId)")
        print("handleServerHello => hasControlCharacteristic: \(controlCharacteristic != nil)")
        
        guard phase == .waitingServerHello,
              record.transferId == transferId,
              let controlCharacteristic
        else {
            print("handleServerHello => guard failed")
            return
        }
        
        let ready = WWBluetoothManager.FileTransferRecord(
            type: .ready,
            transferId: record.transferId,
            index: 0,
            total: record.total
        )
        
        print("handleServerHello => transferId: \(record.transferId), phase: \(phase)")
        peripheral.writeValue(ready.encode(), for: controlCharacteristic, type: .withResponse)
        
        phase = .sendingData
        print("phase after serverHello => \(phase)")
        print("start sendNextChunk after ready")
        
        sendNextChunk(using: peripheral)
    }
    
    /// 處理 ready 記錄，開始送出資料切片
    /// - Parameters:
    ///   - peripheral: 目前互動中的藍牙周邊裝置
    ///   - record: ready 記錄
    func handleReady(peripheral: CBPeripheral, record: WWBluetoothManager.FileTransferRecord) {
        
        guard record.transferId == transferId else { return }
        
        print("handleReady => transferId: \(record.transferId), phase: \(phase)")
        print("start sendNextChunk")
        
        phase = .sendingData
        sendNextChunk(using: peripheral)
    }
    
    /// 處理資料切片記錄，並回送 ACK
    /// - Parameters:
    ///   - peripheral: 目前互動中的藍牙周邊裝置
    ///   - characteristic: 收到資料的 characteristic
    ///   - record: data 記錄
    func handleDataRecord(peripheral: CBPeripheral, characteristic: CBCharacteristic, record: WWBluetoothManager.FileTransferRecord) {
        
        guard characteristic.uuid == dataCharacteristic?.uuid else { return }
        
        phase = .receivingData
        receivedChunks[record.index] = record.payload
        
        guard let controlCharacteristic else { return }
        
        let ack = WWBluetoothManager.FileTransferRecord(type: .ack, transferId: record.transferId, index: record.index, total: record.total)
        peripheral.writeValue(ack.encode(), for: controlCharacteristic, type: .withResponse)
    }
    
    /// 處理資料切片 ACK，更新傳送索引後繼續送下一筆
    /// - Parameters:
    ///   - peripheral: 目前互動中的藍牙周邊裝置
    ///   - record: ack 記錄
    func handleAck(peripheral: CBPeripheral, record: WWBluetoothManager.FileTransferRecord) {
        
        guard record.transferId == transferId, phase == .sendingData else { return }
        
        sendingIndex = record.index + 1
        sendNextChunk(using: peripheral)
    }
    
    /// 處理 finish 記錄，重組資料並回送 finishAck
    /// - Parameters:
    ///   - peripheral: 目前互動中的藍牙周邊裝置
    ///   - record: finish 記錄
    func handleFinish(peripheral: CBPeripheral, record: WWBluetoothManager.FileTransferRecord) {
        
        guard let controlCharacteristic else { return }
        
        let chunks = (0..<record.total).compactMap { receivedChunks[$0] }
        
        guard chunks.count == Int(record.total) else {
            
            let errorRecord = WWBluetoothManager.FileTransferRecord(type: .error, transferId: record.transferId, index: 0, total: record.total)
            
            peripheral.writeValue(errorRecord.encode(), for: controlCharacteristic, type: .withResponse)
            phase = .failed(.missingChunks)
            
            return
        }
        
        let fileData = chunks.reduce(into: Data()) { partialResult, chunk in
            partialResult.append(chunk)
        }
        
        onReceive?(fileData)
        phase = .completed
        
        let finishAck = WWBluetoothManager.FileTransferRecord(type: .finishAck, transferId: record.transferId, index: record.total, total: record.total)
        peripheral.writeValue(finishAck.encode(), for: controlCharacteristic, type: .withResponse)
    }
    
    /// 處理 finishAck 記錄，表示本次傳輸完成
    /// - Parameter record: finishAck 記錄
    func handleFinishAck(record: WWBluetoothManager.FileTransferRecord) {
        
        guard record.transferId == transferId else { return }
        phase = .completed
    }
    
    /// 處理對端回傳的錯誤記錄
    func handleErrorRecord() {
        phase = .failed(.peerReturnedError)
    }
}

// MARK: - 小工具
private extension WWBluetoothManager.FileTransferController {
    
    /// 傳送下一筆傳輸記錄 => 若尚有資料切片未送出，會送出目前索引對應的資料封包；若所有切片皆已送出，則改送完成封包並進入等待 ACK 階段。
    /// - Parameter peripheral: 目前要寫入資料的藍牙周邊裝置
    func sendNextChunk(using peripheral: CBPeripheral) {
        
        guard let dataCharacteristic else { return }
        guard sendingIndex < totalChunks else { sendFinishRecord(using: peripheral, for: dataCharacteristic); return }
        
        sendCurrentDataChunk(using: peripheral, for: dataCharacteristic)
    }
    
    /// 送出完成封包，並切換到等待完成確認的階段
    /// - Parameters:
    ///   - peripheral: 目前要寫入資料的藍牙周邊裝置
    ///   - dataCharacteristic: 資料傳輸用的 characteristic
    func sendFinishRecord(using peripheral: CBPeripheral, for dataCharacteristic: CBCharacteristic) {
        
        phase = .waitingFinishAck
        
        let record = WWBluetoothManager.FileTransferRecord(type: .finish, transferId: transferId, index: totalChunks, total: totalChunks)
        peripheral.writeValue(record.encode(), for: dataCharacteristic, type: .withResponse)
    }
    
    /// 送出目前索引對應的資料切片
    /// - Parameters:
    ///   - peripheral: 目前要寫入資料的藍牙周邊裝置
    ///   - dataCharacteristic: 資料傳輸用的 characteristic
    func sendCurrentDataChunk(using peripheral: CBPeripheral, for dataCharacteristic: CBCharacteristic) {
        
        let record = makeCurrentDataChunkRecord()
        peripheral.writeValue(record.encode(), for: dataCharacteristic, type: .withResponse)
        
        print("send data chunk => index: \(sendingIndex), total: \(totalChunks), payload: \(currentChunkPayload().count)")
    }
    
    /// 建立目前索引對應的資料封包
    /// - Returns: 可直接送出的資料切片封包
    func makeCurrentDataChunkRecord() -> WWBluetoothManager.FileTransferRecord {
        
        let payload = currentChunkPayload()
        return WWBluetoothManager.FileTransferRecord(type: .data, transferId: transferId, index: sendingIndex, total: totalChunks, payload: payload)
    }
    
    /// 取得目前索引對應的資料切片內容
    /// - Returns: 本次要傳送的 payload 資料
    func currentChunkPayload() -> Data {
        
        let startIndex = Int(sendingIndex) * chunkSize
        let endIndex = min(startIndex + chunkSize, sendingData.count)
        
        return sendingData.subdata(in: startIndex..<endIndex)
    }
}
