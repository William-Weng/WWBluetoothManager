//
//  TableViewDemoController.swift
//  Example
//
//  Created by William.Weng on 2023/11/29.

import CoreBluetooth
import UIKit
import WWPrint
import WWBluetoothManager
import WWHUD
import WWProgressMaskView

final class TableViewDemoController: UIViewController {

    @IBOutlet weak var myLabel: UILabel!
    @IBOutlet weak var myTableView: UITableView!
    @IBOutlet weak var myProgressMaskView: WWProgressMaskView!
    
    private var isConnent = false
    
    private var peripherals: [CBPeripheral] = [] {
        didSet { myTableView.reloadData() }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initSetting()
    }
    
    @IBAction func restartScan(_ sender: UIBarButtonItem) {
        isConnent = false
        WWBluetoothManager.shared.restartScan(delegate: self)
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension TableViewDemoController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripherals.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cellMaker(with: tableView, cellForRowAt: indexPath)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectCell(with: tableView, didSelectRowAt: indexPath)
    }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        
        guard let peripheral = self.peripherals[safe: indexPath.row] else { return }
        
        loading()
        WWBluetoothManager.shared.disconnect(peripheral: peripheral)
        isConnent = false
    }
}

// MARK: - WWBluetoothManagerDelegate
extension TableViewDemoController: WWBluetoothManagerDelegate {
        
    func updateState(manager: WWBluetoothManager, state: CBManagerState) {
        updateState(with: manager, state: state)
    }
    
    func discoveredPeripherals(manager: WWBluetoothManager, peripherals: Set<CBPeripheral>, newPeripheralInformation: WWBluetoothManager.PeripheralInformation) {
        discoveredPeripherals(with: manager, peripherals: peripherals, newPeripheralInformation: newPeripheralInformation)
    }
    
    func didConnectPeripheral(manager: WWBluetoothManager, result: Result<WWBluetoothManager.PeripheralConnectType, WWBluetoothManager.PeripheralError>) {
        
        unloading()
        
        switch result {
        case .failure(let error): wwPrint(error)
        case .success(let connentType):
            
            switch connentType {
            case .didConnect(let UUID): wwPrint("didConnect => \(UUID)")
            case .didDisconnect(let UUID): wwPrint("didDisconnect => \(UUID)")
            }
            
            myTableView.reloadData()
        }
    }
    
    func didDiscoverPeripheral(manager: WWBluetoothManager, result: Result<WWBluetoothManager.DiscoverValueType, WWBluetoothManager.PeripheralError>) {
        
        switch result {
        case .failure(let error): wwPrint(error)
        case .success(let discoverValueType):
            
            switch discoverValueType {
            case .services(let info): discoverPeripheralServices(with: manager, info: info)
            case .characteristics(let info): discoverPeripheralCharacteristics(with: manager, info: info)
            case .descriptors(let info): discoverPeripheralDescriptors(with: manager, info: info)
            }
        }
    }
    
    func didUpdatePeripheral(manager: WWBluetoothManager, result: Result<WWBluetoothManager.PeripheralValueInformation, WWBluetoothManager.PeripheralError>) {
        
        switch result {
        case .failure(let error): wwPrint(error)
        case .success(let info): updatePeripheralAction(info: info)
        }
    }
    
    func didModifyServices(manager: WWBluetoothManager, information: WWBluetoothManager.ModifyServicesInformation) {
        wwPrint(information)
    }
}

// MARK: - 小工具
private extension TableViewDemoController {
    
    /// 初始化設定
    /// >> info.plist => NSBluetoothAlwaysUsageDescription / NSBluetoothPeripheralUsageDescription
    func initSetting() {
        
        myLabel.text = "----"
        myTableView.delegate = self
        myTableView.dataSource = self
        
        myProgressMaskView.setting(originalAngle: 0, lineWidth: 20, clockwise: false, lineCap: .round, innerImage: nil, outerImage: nil)
        WWBluetoothManager.shared.startScan(delegate: self)
    }
    
    /// 產生UITableViewCell
    /// - Parameters:
    ///   - tableView: UITableView
    ///   - indexPath: IndexPath
    /// - Returns: UITableViewCell
    func cellMaker(with tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let peripheral = peripherals[safe: indexPath.row] else { fatalError() }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "MyTableViewCell", for: indexPath)
        
        cell.textLabel?.text = "\(peripheral.name ?? "<NONE>")"
        cell.detailTextLabel?.text = "\(peripheral.identifier)"
        cell.backgroundColor = (peripheral.state == .connected) ? .green : .white
        
        return cell
    }
    
    /// Cell被按到的處理
    /// - Parameters:
    ///   - tableView: UITableView
    ///   - indexPath: IndexPath
    func selectCell(with tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        guard let peripheral = peripherals[safe: indexPath.row] else { fatalError() }
        
        if (!isConnent) {
            isConnent = true
            loading()
            WWBluetoothManager.shared.connect(peripheral: peripheral)
        }
    }
    
    /// 處理藍牙傳來的數值
    /// - Parameter info:  WWBluetoothManager.PeripheralValueInformation
    func updatePeripheralAction(info: WWBluetoothManager.PeripheralValueInformation) {
        
        guard let data = info.characteristicValue,
              !data.isEmpty,
              let hexString = Optional.some(data._hexString()),
              let number = hexString._UInt64()
        else {
            return
        }
        
        let volume = number & 0xFF
        let note = (number >> 8) & 0xFF
        let press = (number >> 16) & 0xFF
        
        title = "0x\(hexString)"
        noteReading(press: press, note: note, volume: volume)
    }
}

// MARK: - Connect Action
private extension TableViewDemoController {
    
    /// 處理藍牙連線狀態
    /// - Parameters:
    ///   - manager: WWBluetoothManager
    ///   - state: CBManagerState
    func updateState(with manager: WWBluetoothManager, state: CBManagerState) {
        
        switch state {
        case .poweredOn: wwPrint("藍牙已開啟，開始掃描設備")
        case .poweredOff: wwPrint("藍牙已關閉")
        case .resetting, .unauthorized, .unknown, .unsupported: wwPrint("就是這樣 => \(state)")
        @unknown default: break
        }
    }
    
    /// 處理藍牙搜尋到的設備
    /// - Parameters:
    ///   - manager: WWBluetoothManager
    ///   - peripherals: Set<CBPeripheral>
    ///   - newPeripheralInformation: WWBluetoothManager.PeripheralInformation
    func discoveredPeripherals(with manager: WWBluetoothManager, peripherals: Set<CBPeripheral>, newPeripheralInformation: WWBluetoothManager.PeripheralInformation) {
        
        let peripherals = peripherals.compactMap { peripheral -> CBPeripheral? in
            guard peripheral.name != nil else { return nil }
            return peripheral
        }
        
        self.peripherals = peripherals
    }
    
    /// 讀取動畫
    func loading() {
        
        guard let gifUrl = Bundle.main.url(forResource: "Loading", withExtension: ".gif") else { return }
        
        WWHUD.shared.updateProgess(text: "")
        WWHUD.shared.display(effect: .gif(url: gifUrl, options: nil), height: 512.0, backgroundColor: .black.withAlphaComponent(0.3))
    }
    
    /// 結束讀取動畫
    func unloading() {
        
        WWHUD.shared.updateProgess(text: "")
        WWHUD.shared.dismiss() { _ in }
    }
    
    /// 讀取音符 (for 電鋼琴88鍵 => 0x8080_80_3C_65)
    /// - Parameters:
    ///   - press: 是否按下的數值 (0x80 - false / 0x90 - true)
    ///   - note: 音符的數值 (0x15 ~ 0x6C)
    ///   - volume: 音量大小 (0x00 ~ 0x7F)
    func noteReading(press: UInt64, note: UInt64, volume: UInt64) {
        
        var noteString = "----"
        var percent = 0.0
        
        defer {
            myLabel.text = noteString
            myProgressMaskView.progressCircle(progressUnit: .percent(Int(percent * 100)))
        }
        
        guard press == 0x90,
              note > 0x14
        else {
            return
        }
        
        noteString = equalTemperament(note: note)
        percent = Double(volume) / Double(0x7F)
    }
    
    /// [十二平均律 - 唱名](https://zh.wikipedia.org/zh-tw/十二平均律)
    func equalTemperament(note: UInt64) -> String {
        
        let singingName = note % 12
        var noteString = "Do"
        
        switch singingName {
        case 0: noteString = "Do"
        case 1: noteString = "Do#"
        case 2: noteString = "Re"
        case 3: noteString = "Re#"
        case 4: noteString = "Mi"
        case 5: noteString = "Fa"
        case 6: noteString = "Fa#"
        case 7: noteString = "So"
        case 8: noteString = "So#"
        case 9: noteString = "La"
        case 10: noteString = "La#"
        case 11: noteString = "Si"
        default: break
        }
        
        return noteString
    }
}

// MARK: - Discover Peripheral Action
private extension TableViewDemoController {
    
    /// 處理有關搜尋到Services的事務
    /// - Parameters:
    ///   - manager: WWBluetoothManager
    ///   - info: WWBluetoothManager.DiscoverServicesInformation
    func discoverPeripheralServices(with manager: WWBluetoothManager, info: WWBluetoothManager.DiscoverServicesInformation) {
        
        guard let peripheral = manager.peripheral(.UUID(info.UUID)),
              let services = info.peripheral.services
        else {
            return
        }
        
        services.forEach({ service in
            peripheral.discoverCharacteristics(nil, for: service)
        })
    }
    
    /// 處理有關搜尋到Characteristics的事務
    /// - Parameters:
    ///   - manager: WWBluetoothManager
    ///   - info: WWBluetoothManager.DiscoverCharacteristics
    func discoverPeripheralCharacteristics(with manager: WWBluetoothManager, info: WWBluetoothManager.DiscoverCharacteristics) {
        
        guard let peripheral = manager.peripheral(.UUID(info.UUID)),
              let service = Optional.some(info.service),
              let characteristics = service.characteristics
        else {
            return
        }
        
        if (service.uuid === .bluMidi) {
            
            characteristics.forEach { characteristic in
                
                let pairUUID = characteristic.uuid
                
                if (peripheral._readValue(pairUUIDString: "\(pairUUID.uuidString)", characteristic: characteristic)) {}
                if (peripheral._notifyValue(pairUUIDString: "\(pairUUID.uuidString)", characteristic: characteristic)) {}
                
                wwPrint("pairUUID => \(pairUUID), properties => \(characteristic.properties._parse())")
            }
        }
    }
    
    /// 處理有關搜尋到Descriptors的事務
    /// - Parameters:
    ///   - manager: WWBluetoothManager
    ///   - info: WWBluetoothManager.DiscoverDescriptors
    func discoverPeripheralDescriptors(with manager: WWBluetoothManager, info: WWBluetoothManager.DiscoverDescriptors) {
        wwPrint(info.characteristic.properties._parse())
    }
}


