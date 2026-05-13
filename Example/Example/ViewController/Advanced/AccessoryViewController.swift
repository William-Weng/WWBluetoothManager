//
//  AccessoryViewController.swift
//  Example
//
//  Created by WilliamWeng on 2026/5/6.
//

import UIKit
import CoreBluetooth
import UniformTypeIdentifiers
import WWPrint
import WWByteReader
import WWBluetoothManager

final class AccessoryViewController: UIViewController {
    
    @IBOutlet weak var logTextView: LogTextView!
    @IBOutlet weak var previewImageView: UIImageView!
    
    private let accessory = WWBluetoothManager.Accessory()
    
    private let localName = "🤣🤣🤣🤣"
    private let serviceType: WWBluetoothManager.UUIDType = .service
    private let controlType: WWBluetoothManager.UUIDType = .control
    private let dataType: WWBluetoothManager.UUIDType = .data
    
    private var isAdvertisingStarted = false
    private var currentSession: IncomingFileSession?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configurePreviewImageView()
        bindAccessory()
    }
    
    @IBAction func startAdvertisingAction(_ sender: UIBarButtonItem) {
        logTextView.appendLog("Publish file transfer service...")
        accessory.publish(serviceType: serviceType, controlType: controlType, dataType: dataType)
    }
    
    @IBAction func stopAdvertisingAction(_ sender: UIBarButtonItem) {
        accessory.stopAdvertising()
        isAdvertisingStarted = false
        resetTransferState()
        logTextView.appendLog("Stop advertising.")
    }
    
    @IBAction func sendTestNotifyAction(_ sender: UIBarButtonItem) {
        
        guard let dataCharacteristic = accessory.peripheral.dataCharacteristic else {
            logTextView.appendLog("No data characteristic.")
            return
        }
        
        let text = "Hello from Peripheral \(Date())"
        
        guard let data = text.data(using: .utf8) else {
            logTextView.appendLog("Build notify data failed.")
            return
        }
        
        let isSuccess = accessory.notifyValue(data, for: dataCharacteristic)
        logTextView.appendLog("Send notify => \(isSuccess ? "success" : "buffer full")")
    }
    
    @IBAction func cleanLogText(_ sender: UIBarButtonItem) {
        logTextView.text = ""
    }
    
    @IBAction func clearPreviewAction(_ sender: UIBarButtonItem) {
        previewImageView.image = nil
        logTextView.appendLog("Preview cleared.")
    }
}

// MARK: - Bluetooth
private extension AccessoryViewController {
    
    func bindAccessory() {
        
        logTextView.configure()
        logTextView.appendLog("bindAccessory()")
        
        accessory.onEvent = { [weak self] event in
            
            guard let self else { return }
            
            switch event {
            case .stateUpdated(let state):
                self.logTextView.appendLog("Peripheral state => \(state.rawValue)")
                
            case .advertisingStarted(let error):
                self.logTextView.appendLog("Advertising started, error => \(String(describing: error))")
                
            case .advertisingStopped:
                self.logTextView.appendLog("Advertising stopped.")
                
            case .subscribed(let central, let characteristic):
                self.logTextView.appendLog("Central subscribed => \(central.identifier.uuidString), characteristic => \(characteristic.uuid.uuidString)")
                
            case .unsubscribed(let central, let characteristic):
                self.logTextView.appendLog("Central unsubscribed => \(central.identifier.uuidString), characteristic => \(characteristic.uuid.uuidString)")
                
            case .didReceiveWriteRequests(let requests):
                self.receiveWriteRequests(requests)
                
            case .readyToUpdateSubscribers:
                self.logTextView.appendLog("Ready to update subscribers again.")
                
            case .serviceAdded(let service, let error):
                
                self.logTextView.appendLog("Service added => \(service.uuid.uuidString), error => \(String(describing: error))")
                
                guard error == nil else { return }
                guard !self.isAdvertisingStarted else { return }
                
                self.isAdvertisingStarted = true
                self.accessory.startAdvertising(localName: self.localName, serviceTypes: [self.serviceType])
                
            case .didReceiveReadRequest:
                break
            }
        }
    }
    
    func receiveWriteRequests(_ requests: [CBATTRequest]) {
        
        guard let firstRequest = requests.first else { return }
        
        logTextView.appendLog("Receive write requests => \(requests.count)")
        
        var responseResult: CBATTError.Code = .success
        
        defer {
            accessory.respond(to: firstRequest, withResult: responseResult)
        }
        
        for request in requests {
            
            guard let data = request.value else {
                responseResult = .invalidPdu
                continue
            }
            
            let uuidString = request.characteristic.uuid.uuidString
            logTextView.appendLog("Write => \(uuidString), \(data.count) bytes")
            logTextView.appendLog("Hex => \(data.hexString)")
            
            guard let uuidType = WWBluetoothManager.UUIDType.find(uuid: request.characteristic.uuid) else {
                responseResult = .requestNotSupported
                continue
            }
            
            switch uuidType {
            case .control:
                if !handleControlRequest(data: data) { responseResult = .invalidPdu }
            case .data:
                if !handleDataRequest(data: data) { responseResult = .invalidPdu }
            default:
                responseResult = .requestNotSupported
            }
        }
    }
    
    @discardableResult
    func handleControlRequest(data: Data) -> Bool {
        
        guard let record = try? WWBluetoothManager.FileTransferRecord.decode(from: data) else {
            logTextView.appendLog("Decode control record failed.")
            sendErrorRecord(transferId: currentSession?.transferId ?? 0, total: currentSession?.expectedTotalChunks ?? 0)
            return false
        }
        
        logTextView.appendLog("Control type => \(record.type)")
        logTextView.appendLog("Transfer ID => \(record.transferId)")
        logTextView.appendLog("Index => \(record.index), total => \(record.total)")
        
        switch record.type {
        case .clientHello:
            handleClientHello(record)
        case .ready:
            handleReady(record)
        case .ack:
            logTextView.appendLog("Receive ACK => \(record.index)")
        case .finishAck:
            logTextView.appendLog("Receive finishAck.")
            resetTransferState()
        case .error:
            logTextView.appendLog("Receive error record.")
            resetTransferState()
        case .serverHello:
            logTextView.appendLog("Unexpected serverHello from central.")
        case .data, .finish:
            logTextView.appendLog("Unexpected control record => \(record.type)")
        }
        
        return true
    }
    
    @discardableResult
    func handleDataRequest(data: Data) -> Bool {
        
        guard let record = try? WWBluetoothManager.FileTransferRecord.decode(from: data) else {
            logTextView.appendLog("Decode data record failed.")
            sendErrorRecord(transferId: currentSession?.transferId ?? 0, total: currentSession?.expectedTotalChunks ?? 0)
            return false
        }
        
        switch record.type {
        case .data:
            handleDataRecord(record)
        case .finish:
            handleFinishRecord(record)
        default:
            logTextView.appendLog("Unexpected data characteristic record => \(record.type)")
        }
        
        return true
    }
}

// MARK: - Record handlers
private extension AccessoryViewController {
    
    func handleClientHello(_ record: WWBluetoothManager.FileTransferRecord) {
        
        let metadata = decodeClientHelloPayload(record.payload)
        
        let session = IncomingFileSession(
            transferId: record.transferId,
            expectedTotalChunks: record.total,
            fileName: metadata?.fileName ?? "received-file",
            typeIdentifier: metadata?.typeIdentifier ?? "public.data",
            fileSize: metadata?.fileSize ?? 0,
            chunkSize: metadata?.chunkSize ?? 0
        )
        
        if session.fileSize > 0, session.chunkSize > 0 {
            let calculatedTotal = session.calculatedTotalChunks
            if calculatedTotal != Int(record.total) {
                logTextView.appendLog("Warning => total mismatch, record.total => \(record.total), calculated => \(calculatedTotal)")
            }
        }
        
        currentSession = session
        
        logTextView.appendLog(
            "Start receiving => \(session.fileName), " +
            "type => \(session.typeIdentifier), " +
            "size => \(session.fileSize), " +
            "chunk => \(session.chunkSize), " +
            "total => \(session.expectedTotalChunks)"
        )
        
        let serverHello = WWBluetoothManager.FileTransferRecord(
            type: .serverHello,
            transferId: record.transferId,
            index: 0,
            total: record.total
        )
        
        sendControlRecord(serverHello, log: "Send serverHello")
    }
    
    func handleReady(_ record: WWBluetoothManager.FileTransferRecord) {
        logTextView.appendLog("Receive ready => transferId: \(record.transferId)")
    }
    
    func handleDataRecord(_ record: WWBluetoothManager.FileTransferRecord) {
        
        guard var session = currentSession else {
            logTextView.appendLog("No active transfer session.")
            sendErrorRecord(transferId: record.transferId, total: record.total)
            return
        }
        
        guard record.transferId == session.transferId else {
            logTextView.appendLog("Transfer ID mismatch on data.")
            sendErrorRecord(transferId: record.transferId, total: record.total)
            return
        }
        
        guard record.index < session.expectedTotalChunks else {
            logTextView.appendLog("Chunk index out of range => \(record.index)")
            sendErrorRecord(transferId: record.transferId, total: record.total)
            return
        }
        
        if session.chunkSize > 0, record.payload.count > Int(session.chunkSize) {
            logTextView.appendLog("Chunk payload too large => index \(record.index), size \(record.payload.count)")
            sendErrorRecord(transferId: record.transferId, total: record.total)
            return
        }
        
        if record.index == 0 {
            logTextView.appendLog("RECV payload.count => \(record.payload.count)")
            logTextView.appendLog("RECV payload.head => \(record.payload.prefix(16).hexString())")
            logTextView.appendLog("RECV payload.tail => \(record.payload.suffix(16).hexString())")
        }
        
        if session.chunks[record.index] != nil {
            logTextView.appendLog("Duplicate chunk => \(record.index), overwrite")
        }
        
        session.chunks[record.index] = record.payload
        currentSession = session
        
        let receivedCount = session.chunks.count
        let total = Int(session.expectedTotalChunks)
        let percent = total > 0 ? Int((Double(receivedCount) / Double(total)) * 100.0) : 0
        
        if percent != session.lastLoggedReceivePercent {
            currentSession?.lastLoggedReceivePercent = percent
            logTextView.appendLog("Receiving progress => \(percent)% (\(receivedCount)/\(total))")
        }
        
        let ack = WWBluetoothManager.FileTransferRecord(
            type: .ack,
            transferId: record.transferId,
            index: record.index,
            total: record.total
        )
        
        sendControlRecord(ack, log: "ACK \(record.index)")
    }
    
    func handleFinishRecord(_ record: WWBluetoothManager.FileTransferRecord) {
        
        guard let session = currentSession else {
            logTextView.appendLog("No active transfer session on finish.")
            sendErrorRecord(transferId: record.transferId, total: record.total)
            return
        }
        
        guard record.transferId == session.transferId else {
            logTextView.appendLog("Transfer ID mismatch on finish.")
            sendErrorRecord(transferId: record.transferId, total: record.total)
            return
        }
        
        guard let fileData = session.mergedData() else {
            logTextView.appendLog("Missing chunks => expect \(session.expectedTotalChunks), actual \(session.chunks.count)")
            sendErrorRecord(transferId: record.transferId, total: session.expectedTotalChunks)
            return
        }
        
        if session.fileSize > 0, fileData.count != Int(session.fileSize) {
            logTextView.appendLog("File size mismatch => expect \(session.fileSize), actual \(fileData.count)")
            sendErrorRecord(transferId: record.transferId, total: session.expectedTotalChunks)
            return
        }
        
        do {
            let fileURL = try saveReceivedFile(data: fileData, filename: session.fileName, typeIdentifier: session.typeIdentifier)
            
            logTextView.appendLog("Receive completed => 100%")
            logTextView.appendLog("Saved file => \(fileURL.lastPathComponent)")
            logTextView.appendLog("File size => \(fileData.count) bytes")
            logTextView.appendLog("Path => \(fileURL.path)")
            
            updatePreviewIfPossible(with: fileData, filename: fileURL.lastPathComponent)
            
        } catch {
            logTextView.appendLog("Save file failed => \(error.localizedDescription)")
            sendErrorRecord(transferId: record.transferId, total: session.expectedTotalChunks)
            return
        }
        
        let finishAck = WWBluetoothManager.FileTransferRecord(
            type: .finishAck,
            transferId: record.transferId,
            index: record.total,
            total: record.total
        )
        
        logTextView.appendLog("Merged bytes => \(fileData.count)")
        logTextView.appendLog("Merged head => \(fileData.prefix(16).hexString)")
        logTextView.appendLog("Merged tail => \(fileData.suffix(16).hexString)")
        
        sendControlRecord(finishAck, log: "Send finishAck")
        resetTransferState()
    }
}

// MARK: - Preview
private extension AccessoryViewController {
    
    func configurePreviewImageView() {
        previewImageView.contentMode = .scaleAspectFit
        previewImageView.clipsToBounds = true
        previewImageView.backgroundColor = .secondarySystemBackground
        previewImageView.image = nil
    }
    
    func updatePreviewIfPossible(with data: Data, filename: String) {
        
        do {
            let transferFile = try TransferFile.decode(from: data)
            
            print("decoded fileName => \(transferFile.fileName)")
            print("decoded typeIdentifier => \(transferFile.typeIdentifier)")
            print("decoded data.count => \(transferFile.data.count)")
            print("decoded data.head => \(transferFile.data.prefix(16).hexString())")
            
            guard transferFile.isImage else {
                logTextView.appendLog("Preview skipped => not an image")
                return
            }
            
            guard let image = UIImage(data: transferFile.data) else {
                logTextView.appendLog("Image validation => failed")
                print("image decode => failed")
                return
            }
            
            DispatchQueue.main.async {
                self.previewImageView.image = image
                self.logTextView.appendLog("Image validation => success")
                self.logTextView.appendLog("Preview updated => \(transferFile.normalizedFileName)")
            }
            
            print("image decode => success")
            
        } catch {
            logTextView.appendLog("TransferFile decode => failed")
            print("TransferFile decode failed => \(error)")
        }
    }
}

// MARK: - Helpers
private extension AccessoryViewController {
    
    func sendControlRecord(_ record: WWBluetoothManager.FileTransferRecord, log: String) {
        
        guard let controlCharacteristic = accessory.peripheral.controlCharacteristic else {
            logTextView.appendLog("No control characteristic.")
            return
        }
        
        let data = record.encode()
        let isSuccess = accessory.notifyValue(data, for: controlCharacteristic)
        
        logTextView.appendLog("\(log) => \(isSuccess ? "success" : "buffer full")")
        logTextView.appendLog("Send hex => \(data.hexString)")
    }
    
    func sendErrorRecord(transferId: UInt32, total: UInt32) {
        
        let errorRecord = WWBluetoothManager.FileTransferRecord(
            type: .error,
            transferId: transferId,
            index: 0,
            total: total
        )
        
        sendControlRecord(errorRecord, log: "Send error")
    }
    
    func resetTransferState() {
        currentSession = nil
    }
    
    func saveReceivedFile(data: Data, filename: String, typeIdentifier: String) throws -> URL {
        
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ReceivedFiles", isDirectory: true)
        
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        var safeFilename = filename.isEmpty ? "received-file" : filename
        let hasExtension = !URL(fileURLWithPath: safeFilename).pathExtension.isEmpty
        
        if !hasExtension,
           let type = UTType(typeIdentifier),
           let ext = type.preferredFilenameExtension {
            safeFilename += ".\(ext)"
        }
        
        let fileURL = uniqueFileURL(for: safeFilename, in: directory)
        try data.write(to: fileURL, options: .atomic)
        
        return fileURL
    }
    
    func uniqueFileURL(for filename: String, in directory: URL) -> URL {
        
        let baseURL = directory.appendingPathComponent(filename)
        
        guard FileManager.default.fileExists(atPath: baseURL.path) else {
            return baseURL
        }
        
        let ext = baseURL.pathExtension
        let name = baseURL.deletingPathExtension().lastPathComponent
        
        for index in 1...9999 {
            let candidateName = ext.isEmpty ? "\(name)-\(index)" : "\(name)-\(index).\(ext)"
            let candidateURL = directory.appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
        }
        
        return directory.appendingPathComponent(UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)"))
    }
    
    func decodeClientHelloPayload(_ data: Data) -> (fileName: String, typeIdentifier: String, fileSize: UInt32, chunkSize: UInt16)? {
        
        do {
            var reader = WWByteReader(data: data)
            
            let fileName = try reader.readLengthPrefixedString()
            let typeIdentifier = try reader.readLengthPrefixedString()
            let fileSize: UInt32 = try reader.readUIntValue()
            let chunkSize: UInt16 = try reader.readUIntValue()
            
            guard !fileName.isEmpty else { return nil }
            guard fileSize > 0 else { return nil }
            guard chunkSize > 0 else { return nil }
            
            wwPrint("\(fileName) => \(typeIdentifier), \(fileSize), \(chunkSize)")
            return (fileName, typeIdentifier, fileSize, chunkSize)
            
        } catch {
            return nil
        }
    }
}


