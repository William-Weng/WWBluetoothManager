//
//  AccessoryViewController.swift
//  Example
//
//  Created by WilliamWeng on 2026/5/6.
//

import UIKit
import CoreBluetooth
import WWPrint
import WWBluetoothManager

final class AccessoryViewController: UIViewController {
    
    @IBOutlet weak var logTextView: LogTextView!
    
    private let accessory = WWBluetoothManager.Accessory()
    
    private let localName = "Accessory"
    private let serviceType: WWBluetoothManager.UUIDType = .service
    private let controlType: WWBluetoothManager.UUIDType = .control
    private let dataType: WWBluetoothManager.UUIDType = .data
    
    private var isAdvertisingStarted = false
    
    private var transferId: UInt32 = 0
    private var expectedTotalChunks: UInt32 = 0
    private var receivedChunks: [UInt32: Data] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
        logTextView.text =  ""
    }
}

// MARK: - 小工具
private extension AccessoryViewController {
    
    func bindAccessory() {
        
        logTextView.configure()
        logTextView.appendLog("bindAccessory()")
        
        accessory.onEvent = { [weak self] event in
            
            guard let this = self else { return }
            
            switch event {
            case .stateUpdated(let state):
                this.logTextView.appendLog("Peripheral state => \(state.rawValue)")
                
            case .advertisingStarted(let error):
                this.logTextView.appendLog("Advertising started, error => \(String(describing: error))")
                
            case .advertisingStopped:
                this.logTextView.appendLog("Advertising stopped.")
                
            case .subscribed(let central, let characteristic):
                this.logTextView.appendLog("Central subscribed => \(central.identifier.uuidString), characteristic => \(characteristic.uuid.uuidString)")
                
            case .unsubscribed(let central, let characteristic):
                this.logTextView.appendLog("Central unsubscribed => \(central.identifier.uuidString), characteristic => \(characteristic.uuid.uuidString)")
                
            case .didReceiveWriteRequests(let requests):
                this.receiveWriteRequests(requests: requests)
                
            case .readyToUpdateSubscribers:
                this.logTextView.appendLog("Ready to update subscribers again.")
                
            case .serviceAdded(let service, let error):
                
                this.logTextView.appendLog("Service added => \(service.uuid.uuidString), error => \(String(describing: error))")
                
                guard error == nil else { return }
                guard !this.isAdvertisingStarted else { return }
                
                this.isAdvertisingStarted = true
                this.accessory.startAdvertising(localName: this.localName, serviceTypes: [this.serviceType])

            case .didReceiveReadRequest:
                break
            }
        }
    }
    
    func receiveWriteRequests(requests: [CBATTRequest]) {
        
        logTextView.appendLog("Receive write requests => \(requests.count)")
        
        for request in requests {
            
            guard let data = request.value else {
                accessory.respond(to: request, withResult: .invalidPdu)
                continue
            }
            
            let uuidString = request.characteristic.uuid.uuidString
            logTextView.appendLog("Write => \(uuidString), \(data.count) bytes")
            logTextView.appendLog("Hex => \(data.hexString)")
            
            guard let uuidType = WWBluetoothManager.UUIDType.find(uuid: request.characteristic.uuid) else {
                accessory.respond(to: request, withResult: .requestNotSupported)
                continue
            }
            
            switch uuidType {
            case .control:
                handleControlRequest(request: request, data: data)
                
            case .data:
                handleDataRequest(request: request, data: data)
                
            default:
                accessory.respond(to: request, withResult: .requestNotSupported)
            }
        }
    }
    
    func handleControlRequest(request: CBATTRequest, data: Data) {
        
        accessory.respond(to: request, withResult: .success)
        
        guard let record = try? WWBluetoothManager.FileTransferRecord.decode(from: data) else {
            logTextView.appendLog("Decode control record failed.")
            sendErrorRecord(transferId: transferId, total: expectedTotalChunks)
            return
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
    }
    
    func handleDataRequest(request: CBATTRequest, data: Data) {
        
        accessory.respond(to: request, withResult: .success)
        
        guard let record = try? WWBluetoothManager.FileTransferRecord.decode(from: data) else {
            logTextView.appendLog("Decode data record failed.")
            sendErrorRecord(transferId: transferId, total: expectedTotalChunks)
            return
        }
        
        switch record.type {
        case .data:
            handleDataRecord(record)
            
        case .finish:
            handleFinishRecord(record)
            
        default:
            logTextView.appendLog("Unexpected data characteristic record => \(record.type)")
        }
    }
    
    func handleClientHello(_ record: WWBluetoothManager.FileTransferRecord) {
        
        transferId = record.transferId
        expectedTotalChunks = record.total
        receivedChunks.removeAll()
        
        logTextView.appendLog("Receive clientHello")
        
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
        
        guard record.transferId == transferId else {
            logTextView.appendLog("Transfer ID mismatch on data.")
            sendErrorRecord(transferId: record.transferId, total: record.total)
            return
        }
        
        receivedChunks[record.index] = record.payload
        logTextView.appendLog("Receive data chunk => \(record.index + 1)/\(record.total), payload => \(record.payload.count) bytes")
        
        let ack = WWBluetoothManager.FileTransferRecord(
            type: .ack,
            transferId: record.transferId,
            index: record.index,
            total: record.total
        )
        
        sendControlRecord(ack, log: "Send ACK => \(record.index)")
    }
    
    func handleFinishRecord(_ record: WWBluetoothManager.FileTransferRecord) {
        
        guard record.transferId == transferId else {
            logTextView.appendLog("Transfer ID mismatch on finish.")
            sendErrorRecord(transferId: record.transferId, total: record.total)
            return
        }
        
        let chunks = (0..<record.total).compactMap { receivedChunks[$0] }
        
        guard chunks.count == Int(record.total) else {
            logTextView.appendLog("Missing chunks => expect \(record.total), actual \(chunks.count)")
            sendErrorRecord(transferId: record.transferId, total: record.total)
            return
        }
        
        let fileData = chunks.reduce(into: Data()) { partialResult, chunk in
            partialResult.append(chunk)
        }
        
        logTextView.appendLog("Receive completed => \(fileData.count) bytes")
        
        let finishAck = WWBluetoothManager.FileTransferRecord(
            type: .finishAck,
            transferId: record.transferId,
            index: record.total,
            total: record.total
        )
        
        sendControlRecord(finishAck, log: "Send finishAck")
        resetTransferState()
    }
    
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
        transferId = 0
        expectedTotalChunks = 0
        receivedChunks.removeAll()
    }
}

private extension Data {
    
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
