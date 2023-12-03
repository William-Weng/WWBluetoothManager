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

final class TableViewDemoController: UIViewController {

    @IBOutlet weak var myTableView: UITableView!
    
    private var isConnent = false
    
    private var peripherals: [CBPeripheral] = [] {
        didSet { myTableView.reloadData() }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initSetting()
    }
    
    @IBAction func restartScan(_ sender: UIBarButtonItem) {
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
        case .success(let info):
            
            guard let data = info.characteristicValue,
                  !data.isEmpty,
                  let hexString = Optional.some(data._hexString()),
                  let number = hexString._UInt64()
            else {
                return
            }
            
            let note = ((number >> 8) - 215590) % 1000
            title = "0x\(hexString)"
            noteReading(note: note)
        }
    }
    
    func didModifyServices(manager: WWBluetoothManager, information: WWBluetoothManager.ModifyServicesInformation) {
        
        guard let peripheral = manager.peripheral(UUID: information.UUID),
              let index = peripherals.firstIndex(of: peripheral)
        else {
            return
        }
        
        peripherals.remove(at: index)
        myTableView.reloadData()
    }
}

// MARK: - 小工具
private extension TableViewDemoController {
    
    /// 初始化設定
    /// >> info.plist => NSBluetoothAlwaysUsageDescription / NSBluetoothPeripheralUsageDescription
    func initSetting() {
        myTableView.delegate = self
        myTableView.dataSource = self
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
        WWHUD.shared.display(effect: .gif(url: gifUrl, options: nil), height: 512.0, backgroundColor: .black.withAlphaComponent(0.3))
    }
    
    /// 結束讀取動畫
    func unloading() {
        WWHUD.shared.dismiss() {_ in }
    }
    
    /// 讀取音符
    func noteReading(note: UInt64) {
        
        guard let gifUrl = Bundle.main.url(forResource: "Note", withExtension: ".gif"),
              note > 589
        else {
            return
        }
        
        var noteString = "DO"
        
        switch note {
        case 590: noteString = "DO"
        case 592: noteString = "RE"
        case 594: noteString = "MI"
        case 595: noteString = "FA"
        case 597: noteString = "SO"
        case 599: noteString = "LA"
        case 601: noteString = "SI"
        case 602: noteString = "DO"
        default: break
        }
        
        WWHUD.shared.updateProgess(text: noteString)
        WWHUD.shared.flash(effect: .gif(url: gifUrl, options: nil), height: 512.0, backgroundColor: .black.withAlphaComponent(0.3)) {_ in }
    }
}

// MARK: - Discover Peripheral Action
private extension TableViewDemoController {
    
    /// 處理有關搜尋到Services的事務
    /// - Parameters:
    ///   - manager: WWBluetoothManager
    ///   - info: WWBluetoothManager.DiscoverServicesInformation
    func discoverPeripheralServices(with manager: WWBluetoothManager, info: WWBluetoothManager.DiscoverServicesInformation) {
        
        guard let peripheral = manager.peripheral(UUID: info.UUID),
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
        
        guard let peripheral = manager.peripheral(UUID: info.UUID),
              let service = Optional.some(info.service),
              let characteristics = service.characteristics
        else {
            return
        }
        
        if (service.uuid === .bluMidi) {
            characteristics.forEach { characteristic in
                let pairUUID = characteristic.uuid
                if (peripheral._notifyValue(pairUUIDString: "\(pairUUID.uuidString)", characteristic: characteristic)) {}
                wwPrint("pairUUID => \(pairUUID) , properties => \(characteristic.properties._parse())")
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


