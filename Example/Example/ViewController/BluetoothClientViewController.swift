//
//  BluetoothClientViewController.swift
//  Example
//
//  Created by WilliamWeng on 2026/5/6.
//

import UIKit
import CoreBluetooth
import WWBluetoothManager

final class BluetoothClientViewController: UIViewController {
    
    @IBOutlet weak var logTextView: UITextView!
    
    private let client = WWBluetoothManager.Client()
    private let targetLocalName = "Control for SB1830"
        
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBluetooth()
    }
    
    @IBAction func writeData(_ sender: UIBarButtonItem) {
        let result = client.write(Data([0x01]), uuidType: .write, type: .withResponse)
        appendLog("\(result)")
    }
}

private extension BluetoothClientViewController {
        
    func setupBluetooth() {
        
        client.onEvent = { [weak self] event in
            
            guard let this = self else { return }
            
            DispatchQueue.main.async {
                
                this.appendLog("\(event)")
                
                switch event {
                case .discovered(let device): this.connectDevice(device)
                default: break
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.client.startScan()
        }
    }
}

private extension BluetoothClientViewController {
    
    func connectDevice(_ device: WWBluetoothManager.Device) {
        
        guard device.name == targetLocalName else { return }
        
        appendLog(device.jsonString ?? "")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            
            guard let this = self else { return }
            
            this.client.connect(device)
            this.client.stopScan()
        }
    }
    
    func appendLog(_ text: String) {
        
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let bottom = NSMakeRange(logTextView.text.count - 1, 1)
        
        logTextView.text += "[\(timestamp)] \(text)\n\n"
        logTextView.scrollRangeToVisible(bottom)
    }
}
