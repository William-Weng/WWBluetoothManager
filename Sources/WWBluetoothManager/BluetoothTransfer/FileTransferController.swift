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
        
        senderSession = SenderSession(
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
        
        receiverSession = ReceiverSession(
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
    
    func handleClientHello(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        record: WWBluetoothManager.FileTransferRecord
    ) {
        
        guard var session = receiverSession else { return }
        guard characteristic.uuid == session.controlCharacteristic?.uuid else { return }
        
        session = ReceiverSession(
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
    
    func handleDataRecord(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        record: WWBluetoothManager.FileTransferRecord
    ) {
        
        guard var session = receiverSession else { return }
        guard characteristic.uuid == session.dataCharacteristic?.uuid else { return }
        guard record.transferId == session.transferId else { return }
        
        print("handleDataRecord => index: \(record.index), total: \(record.total)")
        print("handleDataRecord => payload.count: \(record.payload.count)")
        print("handleDataRecord => payload.head: \(record.payload.prefix(16).hexString())")
        
        if let oldChunk = session.receivedChunks[record.index] {
            print("handleDataRecord => overwrite index \(record.index)")
            print("old.count => \(oldChunk.count)")
            print("old.head => \(oldChunk.prefix(16).hexString())")
        }
        
        session.phase = .receivingData
        session.receivedChunks[record.index] = record.payload
        
        print("stored chunk[\(record.index)].count => \(session.receivedChunks[record.index]?.count ?? -1)")
        print("stored chunk[\(record.index)].head => \(session.receivedChunks[record.index]?.prefix(16).hexString() ?? "nil")")
        print("receivedChunks.keys => \(session.receivedChunks.keys.sorted())")
        
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
    
    func handleFinish(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        record: WWBluetoothManager.FileTransferRecord
    ) {
        
        guard var session = receiverSession else { return }
        guard characteristic.uuid == session.dataCharacteristic?.uuid else { return }
        guard record.transferId == session.transferId else { return }
        guard let controlCharacteristic = session.controlCharacteristic else { return }
        
        let chunks = (0..<record.total).compactMap { session.receivedChunks[$0] }
        
        print("receivedChunks.keys => \(session.receivedChunks.keys.sorted())")
        print("chunk[0].count => \(session.receivedChunks[0]?.count ?? -1)")
        print("chunk[0].head => \(session.receivedChunks[0]?.prefix(16).hexString() ?? "nil")")
        
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
        
        let fileData = chunks.reduce(into: Data()) { result, chunk in
            result.append(chunk)
        }
        
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
    
    func handleServerHello(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        record: WWBluetoothManager.FileTransferRecord
    ) {
        
        guard var session = senderSession else { return }
        guard characteristic.uuid == session.controlCharacteristic?.uuid else { return }
        guard session.phase == .waitingServerHello else { return }
        guard record.transferId == session.transferId else { return }
        guard let controlCharacteristic = session.controlCharacteristic else { return }
        
        let ready = WWBluetoothManager.FileTransferRecord(
            type: .ready,
            transferId: record.transferId,
            index: 0,
            total: record.total
        )
        
        peripheral.writeValue(ready.encode(), for: controlCharacteristic, type: .withResponse)
        
        session.phase = .sendingData
        senderSession = session
        
        sendNextChunk(using: peripheral)
    }
    
    func handleReady(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        record: WWBluetoothManager.FileTransferRecord
    ) {
        
        guard var session = senderSession else { return }
        guard characteristic.uuid == session.controlCharacteristic?.uuid else { return }
        guard record.transferId == session.transferId else { return }
        
        session.phase = .sendingData
        senderSession = session
        
        sendNextChunk(using: peripheral)
    }
    
    func handleAck(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        record: WWBluetoothManager.FileTransferRecord
    ) {
        
        guard var session = senderSession else { return }
        guard characteristic.uuid == session.controlCharacteristic?.uuid else { return }
        guard session.phase == .sendingData else { return }
        guard record.transferId == session.transferId else { return }
        
        session.sendingIndex = record.index + 1
        senderSession = session
        
        sendNextChunk(using: peripheral)
    }
    
    func handleFinishAck(record: WWBluetoothManager.FileTransferRecord) {
        
        guard var session = senderSession else { return }
        guard record.transferId == session.transferId else { return }
        
        session.phase = .completed
        senderSession = session
    }
    
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
    
    func sendNextChunk(using peripheral: CBPeripheral) {
        
        guard let session = senderSession,
              let dataCharacteristic = session.dataCharacteristic
        else {
            return
        }
        
        guard session.phase == .sendingData else { return }
        
        guard session.sendingIndex < session.totalChunks else {
            sendFinishRecord(using: peripheral, for: dataCharacteristic)
            return
        }
        
        sendCurrentDataChunk(using: peripheral, for: dataCharacteristic)
    }
    
    func sendFinishRecord(using peripheral: CBPeripheral, for dataCharacteristic: CBCharacteristic) {
        
        guard var session = senderSession else { return }
        
        session.phase = .waitingFinishAck
        senderSession = session
        
        let record = WWBluetoothManager.FileTransferRecord(
            type: .finish,
            transferId: session.transferId,
            index: session.totalChunks,
            total: session.totalChunks
        )
        
        peripheral.writeValue(record.encode(), for: dataCharacteristic, type: .withResponse)
    }
    
    func sendCurrentDataChunk(using peripheral: CBPeripheral, for dataCharacteristic: CBCharacteristic) {
        
        let record = makeCurrentDataChunkRecord()
        
        print("sendCurrentDataChunk => index: \(record.index), total: \(record.total)")
        print("sendCurrentDataChunk => payload.count: \(record.payload.count)")
        print("sendCurrentDataChunk => payload.head: \(record.payload.prefix(16).hexString())")
        
        let encoded = record.encode()
        print("sendCurrentDataChunk => encoded.count: \(encoded.count)")
        print("sendCurrentDataChunk => encoded.head: \(encoded.prefix(32).hexString())")
        
        peripheral.writeValue(encoded, for: dataCharacteristic, type: .withResponse)
    }
    
    func makeCurrentDataChunkRecord() -> WWBluetoothManager.FileTransferRecord {
        
        guard let session = senderSession else {
            return WWBluetoothManager.FileTransferRecord(type: .data, transferId: 0, index: 0, total: 0)
        }
        
        let payload = currentChunkPayload()
        
        return WWBluetoothManager.FileTransferRecord(
            type: .data,
            transferId: session.transferId,
            index: session.sendingIndex,
            total: session.totalChunks,
            payload: payload
        )
    }
    
    func currentChunkPayload() -> Data {
        
        guard let session = senderSession else { return Data() }
        
        let startIndex = Int(session.sendingIndex) * session.chunkSize
        let endIndex = min(startIndex + session.chunkSize, session.sendingData.count)
        
        guard startIndex < endIndex, startIndex < session.sendingData.count else {
            return Data()
        }
        
        return session.sendingData.subdata(in: startIndex..<endIndex)
    }
}

// MARK: - Models
private extension WWBluetoothManager.FileTransferController {
    
    struct SenderSession {
        var phase: WWBluetoothManager.FileTransferPhase = .idle
        var transferId: UInt32 = 0
        var totalChunks: UInt32 = 0
        var chunkSize: Int = 20
        var controlCharacteristic: CBCharacteristic?
        var dataCharacteristic: CBCharacteristic?
        var sendingData = Data()
        var sendingIndex: UInt32 = 0
    }
    
    struct ReceiverSession {
        var phase: WWBluetoothManager.FileTransferPhase = .idle
        var transferId: UInt32 = 0
        var expectedTotalChunks: UInt32 = 0
        var controlCharacteristic: CBCharacteristic?
        var dataCharacteristic: CBCharacteristic?
        var receivedChunks: [UInt32: Data] = [:]
    }
}
