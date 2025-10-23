//
//  TableViewDemoController.swift
//  Example
//
//  Created by William.Weng on 2023/11/29.

import UIKit
import CoreBluetooth
import WWPrint
import WWBluetoothManager
import WWHUD
import WWOrderedSet

// MARK: - TableViewDemoController
final class TableViewDemoController: UIViewController {
    
    @IBOutlet weak var myLabel: UILabel!
    @IBOutlet weak var myImageView: UIImageView!
    @IBOutlet weak var myTableView: UITableView!
    
    private let BOM = "<BOM>"
    private let EOM = "<EOM>"
    
    private var isSwitch = false
    private var isConnented = false
    private var bluetoothPeripheralManager: WWBluetoothPeripheralManager?
    private var receiveData = Data()
    
    private var peripherals: [CBPeripheral] = [] {
        didSet { myTableView.reloadData() }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initSetting()
    }
    
    @IBAction func restartScan(_ sender: UIBarButtonItem) {
        isConnented = false
        WWBluetoothManager.shared.restartScan(delegate: self)
    }
    
    @IBAction func sendData(_ sender: UIBarButtonItem) {
        
        let imageName = !isSwitch ? "Red.jpg" : "Green.png"
        let imageUrl = Bundle.main.url(forResource: imageName, withExtension: nil)
        let result = FileManager.default._readData(from: imageUrl)

        isSwitch.toggle()
        
        switch result {
        case .failure(let error): wwPrint(error)
        case .success(let data):
             
            if let data = data {
                wwPrint(data.count)
                _ = bluetoothPeripheralManager?.sendData(data, BOM: BOM, EOM: EOM)
            }
        }
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
        isConnented = false
    }
}

// MARK: - WWBluetoothManager.Delegate
extension TableViewDemoController: WWBluetoothManager.Delegate {
    
    func updateState(manager: WWBluetoothManager, state: CBManagerState) {
        updateState(with: manager, state: state)
    }
    
    func discoveredPeripherals(manager: WWBluetoothManager, peripherals: WWOrderedSet<CBPeripheral>, newPeripheralInformation: WWBluetoothManager.PeripheralInformation) {
        discoveredPeripherals(with: manager, peripherals: peripherals, newPeripheralInformation: newPeripheralInformation)
    }
    
    func didConnectPeripheral(manager: WWBluetoothManager, result: Result<WWBluetoothManager.PeripheralConnectType, WWBluetoothManager.PeripheralError>) {
        
        unloading()
        
        switch result {
        case .failure(let error): wwPrint(error)
        case .success(let connentType):
            
            switch connentType {
            case .didConnect(_): isConnented = true
            case .didDisconnect(_): isConnented = false
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

// MARK: - WWBluetoothPeripheralManager.Delegate
extension TableViewDemoController: WWBluetoothPeripheralManager.Delegate {
    
    func managerIsReady(manager: WWBluetoothPeripheralManager, MTU: Int) {
        wwPrint("MTU => \(MTU)")
    }
    
    func receiveValue(manager: WWBluetoothPeripheralManager, value: Data) {
        wwPrint("value => \(value._string()!)")
    }
    
    func errorMessage(manager: WWBluetoothPeripheralManager, error: Error) {
        wwPrint("error => \(error)")
    }
}

// MARK: - 小工具
private extension TableViewDemoController {
    
    /// 初始化設定
    /// info.plist => NSBluetoothAlwaysUsageDescription / NSBluetoothPeripheralUsageDescription
    func initSetting() {
        
        myLabel.text = "----"
        myTableView.delegate = self
        myTableView.dataSource = self
        
        bluetoothPeripheralManager = WWBluetoothPeripheralManager.build(managerDelegate: self)
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
        
        if (!isConnented) {
            isConnented = true
            loading()
            WWBluetoothManager.shared.connect(peripheral: peripheral)
        }
    }
    
    /// 處理藍牙傳來的數值
    /// - Parameter info: WWBluetoothManager.PeripheralValueInformation
    func updatePeripheralAction(info: WWBluetoothManager.PeripheralValueInformation) {
                
        guard let data = info.characteristicValue else { return }
                
        if let string = data._string() {
                        
            if (string == BOM) { receiveData = Data(); loading(); return }
            if (string == EOM) { myImageView.image = UIImage(data: receiveData); unloading(); return }
            
            myLabel.text = string
            
        } else {
            receiveData.append(data)
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
    func discoveredPeripherals(with manager: WWBluetoothManager, peripherals: WWOrderedSet<CBPeripheral>, newPeripheralInformation: WWBluetoothManager.PeripheralInformation) {
        
        let peripherals = peripherals.array.compactMap { peripheral -> CBPeripheral? in
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
        
        services.forEach({ peripheral.discoverCharacteristics(nil, for: $0) })
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
        
        if (service.uuid !== .read) {
            
            characteristics.forEach { characteristic in
                
                let pairUUID = characteristic.uuid
                
                if (peripheral._notifyValue(pairUUIDString: "\(pairUUID.uuidString)", characteristic: characteristic)) {}
                if (peripheral._readValue(pairUUIDString: "\(pairUUID.uuidString)", characteristic: characteristic)) {}
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
