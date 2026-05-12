//
//  AccessoryViewController.swift
//  Example
//
//  Created by WilliamWeng on 2026/5/6.
//

import UIKit
import CoreBluetooth
import WWBluetoothManager

final class AccessoryViewController: UIViewController {
    
    @IBOutlet weak var logTextView: LogTextView!
    
    private let accessory = WWBluetoothManager.Accessory()
    
    private let localName = "WWFileTransfer"
    private let serviceType: WWBluetoothManager.UUIDType = .service
    private let controlType: WWBluetoothManager.UUIDType = .control
    private let dataType: WWBluetoothManager.UUIDType = .data
    
    private var isAdvertisingStarted = false
    
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
}

// MARK: - 小工具
private extension AccessoryViewController {
    
    func bindAccessory() {
        
        logTextView.configure()
        logTextView.appendLog("bindAccessory()")
        
        accessory.onEvent = { [weak self] event in
            
            guard let this = self else { return }
            
            switch event {
            case .stateUpdated(let state): this.logTextView.appendLog("Peripheral state => \(state.rawValue)")
            case .advertisingStarted(let error): this.logTextView.appendLog("Advertising started, error => \(String(describing: error))")
            case .advertisingStopped: this.logTextView.appendLog("Advertising stopped.")
            case .subscribed(let central, let characteristic): this.logTextView.appendLog("Central subscribed => \(central.identifier.uuidString), characteristic => \(characteristic.uuid.uuidString)")
            case .unsubscribed(let central, let characteristic): this.logTextView.appendLog("Central unsubscribed => \(central.identifier.uuidString), characteristic => \(characteristic.uuid.uuidString)")
            case .didReceiveWriteRequests(let requests): this.logTextView.appendLog("Receive write requests => \(requests.count)")
            case .readyToUpdateSubscribers: this.logTextView.appendLog("Ready to update subscribers again.")
                
            case .serviceAdded(let service, let error):
                this.logTextView.appendLog("Service added => \(service.uuid.uuidString), error => \(String(describing: error))")
                
                guard error == nil else { return }
                guard !this.isAdvertisingStarted else { return }
                
                this.isAdvertisingStarted = true
                this.accessory.startAdvertising(localName: this.localName, serviceTypes: [this.serviceType])

            case .didReceiveReadRequest: break
            }
        }
    }
}

