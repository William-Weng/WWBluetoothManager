//
//  ClientViewController.swift
//  Example
//
//  Created by WilliamWeng on 2026/5/6.
//

import UIKit
import CoreBluetooth
import WWBluetoothManager

final class ClientViewController: UIViewController {
    
    @IBOutlet weak var logTextView: LogTextView!
    
    private let client = WWBluetoothManager.Client()
    private let targetLocalName = "Control for SB1830"
        
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBluetooth()
    }
    
    @IBAction func writeData(_ sender: UIBarButtonItem) {
        let result = client.write(Data([0x01]), uuidType: .write, type: .withResponse)
        logTextView.appendLog("\(result)")
    }
}

private extension ClientViewController {
        
    func setupBluetooth() {
        
        client.onEvent = { [weak self] event in
            
            guard let this = self else { return }
            
            Task { @MainActor in
                
                this.logTextView.appendLog("\(event)")
                
                switch event {
                case .discovered(let device): this.connectDevice(device)
                default: break
                }
            }
        }
        
        Task { @MainActor in
            try await Task.sleep(for: .seconds(1.0))
            client.startScan()
        }
    }
}

private extension ClientViewController {
    
    func connectDevice(_ device: WWBluetoothManager.Device) {
        
        guard device.name == targetLocalName else { return }
        
        logTextView.appendLog(device.jsonString ?? "")
        
        Task { @MainActor in
            
            try await Task.sleep(for: .seconds(1.0))
            
            client.connect(device)
            client.stopScan()
        }
    }
}
