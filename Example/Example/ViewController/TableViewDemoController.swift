//
//  TableViewDemoController.swift
//  Example
//
//  Created by William.Weng on 2023/11/29.

import CoreBluetooth
import UIKit
import WWPrint
import WWBluetoothManager

final class TableViewDemoController: UIViewController {

    @IBOutlet weak var myTableView: UITableView!
    
    private let myPeripheral = "AirPods"
    
    private var peripherals: [CBPeripheral] = [] {
        didSet { myTableView.reloadData() }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initSetting()
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
}

// MARK: - WWBluetoothManagerDelegate
extension TableViewDemoController: WWBluetoothManagerDelegate {
        
    func updateState(manager: WWBluetoothManager, state: CBManagerState) {
        updateState(with: manager, state: state)
    }
    
    func discoveredPeripherals(manager: WWBluetoothManager, peripherals: Set<CBPeripheral>, newPeripheralInformation: WWBluetoothManager.PeripheralInformation) {
        discoveredPeripherals(with: manager, peripherals: peripherals, newPeripheralInformation: newPeripheralInformation)
    }
    
    func didConnectPeripheral(manager: WWBluetoothManager, result: Result<UUID, WWBluetoothManager.PeripheralError>) {
        
        switch result {
        case .failure(let error): wwPrint(error)
        case .success(let uuid): wwPrint(uuid)
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
    
    func didUpdatePeripheral(manager: WWBluetoothManager, result: Result<WWBluetoothManager.UpdateType, WWBluetoothManager.PeripheralError>) {
        
        switch result {
        case .failure(let error): wwPrint(error)
        case .success(let updateType):
            
            switch updateType {
            case .value(let info): updatePeripheralValue(with: manager, info: info)
            case .notificationState(let info): updatePeripheralNotificationState(with: manager, info: info)
            }
        }
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
        
        return cell
    }
    
    /// Cell被按到的處理
    /// - Parameters:
    ///   - tableView: UITableView
    ///   - indexPath: IndexPath
    func selectCell(with tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let peripheral = peripherals[safe: indexPath.row] else { fatalError() }
        WWBluetoothManager.shared.connect(peripheral: peripheral)
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
            guard peripheral.name == myPeripheral else { return nil }
            return peripheral
        }
        
        self.peripherals = peripherals
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
              let services = info.services
        else {
            return
        }
        
        services.forEach({ service in
            peripheral.discoverCharacteristics(nil, for: service)
            wwPrint(service)
        })
    }
    
    /// 處理有關搜尋到Characteristics的事務
    /// - Parameters:
    ///   - manager: WWBluetoothManager
    ///   - info: WWBluetoothManager.DiscoverCharacteristics
    func discoverPeripheralCharacteristics(with manager: WWBluetoothManager, info: WWBluetoothManager.DiscoverCharacteristics) {
        
        guard let peripheral = manager.peripheral(UUID: info.UUID),
              let characteristics = info.characteristics
        else {
            return
        }
        
        characteristics.forEach({ characteristic in
            
            let isContains = characteristic.properties.contains([.notify, .read])
            if isContains { peripheral.setNotifyValue(isContains, for: characteristic) }
            
            wwPrint(characteristic.properties._parse())
        })
    }
    
    /// 處理有關搜尋到Descriptors的事務
    /// - Parameters:
    ///   - manager: WWBluetoothManager
    ///   - info: WWBluetoothManager.DiscoverDescriptors
    func discoverPeripheralDescriptors(with manager: WWBluetoothManager, info: WWBluetoothManager.DiscoverDescriptors) {
        wwPrint(info)
    }
}

// MARK: - Update Peripheral Action
private extension TableViewDemoController {
    
    /// 處理設備數值事件
    /// - Parameters:
    ///   - manager: WWBluetoothManager
    ///   - info: WWBluetoothManager.UpdateValueInformation
    func updatePeripheralValue(with manager: WWBluetoothManager, info: WWBluetoothManager.UpdateValueInformation) {
        wwPrint(info)
    }
    
    /// 處理設備通知事件
    /// - Parameters:
    ///   - manager: WWBluetoothManager
    ///   - info: WWBluetoothManager.UpdateNotificationStateInformation
    func updatePeripheralNotificationState(with manager: WWBluetoothManager, info: WWBluetoothManager.UpdateNotificationStateInformation) {
        
        let value = info.data?.withUnsafeBytes { $0.load(as: UTF8.self) }
        wwPrint(value)
    }
}
