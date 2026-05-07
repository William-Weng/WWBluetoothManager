//
//  BluetoothFileTransferPeripheralViewController.swift
//  Example
//
//  Created by WilliamWeng on 2026/5/6.
//

import UIKit
import CoreBluetooth
import WWBluetoothManager

final class BluetoothFileTransferPeripheralViewController: UIViewController {
    
    @IBOutlet weak var logTextView: LogTextView!
    
    private let peripheral = WWBluetoothManager.Peripheral()
    
    private let localName = "WWFileTransfer"
    private let serviceType: WWBluetoothManager.UUIDType = .service
    private let controlType: WWBluetoothManager.UUIDType = .control
    private let dataType: WWBluetoothManager.UUIDType = .data

    private var isAdvertisingStarted = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bindPeripheral()
    }
    
    @IBAction func startAdvertisingAction(_ sender: UIBarButtonItem) {
        logTextView.appendLog("Publish file transfer service...")
        peripheral.publish(serviceType: serviceType, controlType: controlType, dataType: dataType)
    }
    
    @IBAction func stopAdvertisingAction(_ sender: UIBarButtonItem) {
        peripheral.stopAdvertising()
        isAdvertisingStarted = false
        logTextView.appendLog("Stop advertising.")
    }
    
    @IBAction func sendTestNotifyAction(_ sender: UIBarButtonItem) {
        
        guard let dataCharacteristic = peripheral.dataCharacteristic else {
            logTextView.appendLog("No data characteristic.")
            return
        }
        
        let text = "Hello from Peripheral \(Date())"
        
        guard let data = text.data(using: .utf8) else {
            logTextView.appendLog("Build notify data failed.")
            return
        }
        
        let isSuccess = peripheral.notifyValue(data, for: dataCharacteristic)
        logTextView.appendLog("Send notify => \(isSuccess ? "success" : "buffer full")")
    }
}

extension BluetoothFileTransferPeripheralViewController: WWBluetoothManager.PeripheralDelegate {
    
    func peripheralManager(_ peripheral: WWBluetoothManager.Peripheral, status: WWBluetoothManager.PeripheralManagerStatus) {
        
        switch status {
        case .stateUpdated(let state):
            logTextView.appendLog("Peripheral state => \(state.rawValue)")
            
        case .serviceAdded(let service, let error):
            
            logTextView.appendLog("Service added => \(service.uuid.uuidString), error => \(String(describing: error))")
            
            guard error == nil else { return }
            guard !isAdvertisingStarted else { return }
            
            isAdvertisingStarted = true
            self.peripheral.startAdvertising(localName: localName, serviceTypes: [serviceType])
            
        case .advertisingStarted(let error):
            logTextView.appendLog("Advertising started, error => \(String(describing: error))")
            
        case .subscribed(let central, let characteristic):
            logTextView.appendLog("Central subscribed => \(central.identifier.uuidString), characteristic => \(characteristic.uuid.uuidString)")
            
        case .unsubscribed(let central, let characteristic):
            logTextView.appendLog("Central unsubscribed => \(central.identifier.uuidString), characteristic => \(characteristic.uuid.uuidString)")
            
        case .writeRequests(let requests):
            logTextView.appendLog("Receive write requests => \(requests.count)")
            
        case .readyToUpdateSubscribers:
            logTextView.appendLog("Ready to update subscribers again.")
        case .advertisingStopped: break
        case .didReceiveReadRequest(_): break
        }
    }
}

private extension BluetoothFileTransferPeripheralViewController {
    
    func bindPeripheral() {
        peripheral.delegate = self
        logTextView.configure()
        logTextView.appendLog("bindPeripheral()")
    }
}

