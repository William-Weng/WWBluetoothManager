# WWBluetoothManager

[![Swift-5.7](https://img.shields.io/badge/Swift-5.6-orange.svg?style=flat)](https://developer.apple.com/swift/) [![iOS-15.0](https://img.shields.io/badge/iOS-15.0-pink.svg?style=flat)](https://developer.apple.com/swift/) ![TAG](https://img.shields.io/github/v/tag/William-Weng/WWBluetoothManager) [![Swift Package Manager-SUCCESS](https://img.shields.io/badge/Swift_Package_Manager-SUCCESS-blue.svg?style=flat)](https://developer.apple.com/swift/) [![LICENSE](https://img.shields.io/badge/LICENSE-MIT-yellow.svg?style=flat)](https://developer.apple.com/swift/)

### [Introduction - 簡介](https://swiftpackageindex.com/William-Weng)
- Simple integration of official CoreBluetooth suite functions allows developers to develop Bluetooth devices more easily.
- 簡單整合官方的CoreBluetooth套件功能，讓開發者能更簡單的開發藍牙設備。

https://github.com/user-attachments/assets/20f6da9f-28c5-4c38-8bbf-e4470157127b

### [Installation with Swift Package Manager](https://medium.com/彼得潘的-swift-ios-app-開發問題解答集/使用-spm-安裝第三方套件-xcode-11-新功能-2c4ffcf85b4b)
```bash
dependencies: [
    .package(url: "https://github.com/William-Weng/WWBluetoothManager.git", .upToNextMajor(from: "0.8.4"))
]
```

### Function - 可用函式 (WWBluetoothManager)
|函式|功能|
|-|-|
|build()|建立新BluetoothManager|
|startScan(queue:delegate:)|開始掃瞄|
|stopScan()|停止掃瞄|
|restartScan(queue:delegate:)|重新開始掃瞄|
|connect(peripheral:options:)|連接藍牙設備|
|disconnect(peripheral:)|藍牙設備斷開連接|
|peripheral(_:)|搜尋設備|
|connect(_:options:)|連接藍牙設備|
|disconnect(_:)|藍牙設備斷開連接|

### Function - 可用函式 (WWBluetoothPeripheralManager)
|函式|功能|
|-|-|
|build(managerDelegate:peripheralName:queue:)|建立新WWBluetoothPeripheralManager|
|sendText(_:BOM:EOM:using:isLossyConversion:)|發送文字|
|sendData(_:BOM:EOM:using:)|發送資料|

### WWBluetoothManagerDelegate
|函式|功能|
|-|-|
|updateState(manager:state:)|手機藍牙的更新狀態|
|discoveredPeripherals(manager:peripherals:newPeripheralInformation:)|搜尋到的週邊設備 (不重複)|
|didConnectPeripheral(manager:result:)|取得剛連上設備的資訊|
|didDiscoverPeripheral(manager:result:)|處理已經連上設備的Services / Characteristics / Descriptors|
|didUpdatePeripheral(manager:result:)|週邊設備數值相關的功能|
|didModifyServices(manager:information:)|週邊設備服務更動的功能|

### WWBluetoothPeripheralManagerDelegate
|函式|功能|
|-|-|
|managerIsReady(manager:MTU:)|裝置準備完成|
|receiveValue(manager:value:)|接到的資訊|
|errorMessage(manager:error:)|錯誤訊息|

### Example
```swift
import CoreBluetooth
import UIKit
import WWPrint
import WWBluetoothManager
import WWHUD
import WWOrderedSet

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

private extension TableViewDemoController {
    
    func initSetting() {
        
        myLabel.text = "----"
        myTableView.delegate = self
        myTableView.dataSource = self
        
        bluetoothPeripheralManager = WWBluetoothPeripheralManager.build(managerDelegate: self)
        WWBluetoothManager.shared.startScan(delegate: self)
    }
    
    func cellMaker(with tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let peripheral = peripherals[safe: indexPath.row] else { fatalError() }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "MyTableViewCell", for: indexPath)
        
        cell.textLabel?.text = "\(peripheral.name ?? "<NONE>")"
        cell.detailTextLabel?.text = "\(peripheral.identifier)"
        cell.backgroundColor = (peripheral.state == .connected) ? .green : .white
        
        return cell
    }
    
    func selectCell(with tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        guard let peripheral = peripherals[safe: indexPath.row] else { fatalError() }
        
        if (!isConnented) {
            isConnented = true
            loading()
            WWBluetoothManager.shared.connect(peripheral: peripheral)
        }
    }
    
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

private extension TableViewDemoController {
    
    func updateState(with manager: WWBluetoothManager, state: CBManagerState) {
        
        switch state {
        case .poweredOn: wwPrint("藍牙已開啟，開始掃描設備")
        case .poweredOff: wwPrint("藍牙已關閉")
        case .resetting, .unauthorized, .unknown, .unsupported: wwPrint("就是這樣 => \(state)")
        @unknown default: break
        }
    }
    
    func discoveredPeripherals(with manager: WWBluetoothManager, peripherals: WWOrderedSet<CBPeripheral>, newPeripheralInformation: WWBluetoothManager.PeripheralInformation) {
        
        let peripherals = peripherals.array.compactMap { peripheral -> CBPeripheral? in
            guard peripheral.name != nil else { return nil }
            return peripheral
        }
                        
        self.peripherals = peripherals
    }
    
    func loading() {
        
        guard let gifUrl = Bundle.main.url(forResource: "Loading", withExtension: ".gif") else { return }
        
        WWHUD.shared.updateProgess(text: "")
        WWHUD.shared.display(effect: .gif(url: gifUrl, options: nil), height: 512.0, backgroundColor: .black.withAlphaComponent(0.3))
    }
    
    func unloading() {
        
        WWHUD.shared.updateProgess(text: "")
        WWHUD.shared.dismiss() { _ in }
    }
}

// MARK: - Discover Peripheral Action
private extension TableViewDemoController {
    
    func discoverPeripheralServices(with manager: WWBluetoothManager, info: WWBluetoothManager.DiscoverServicesInformation) {
        
        guard let peripheral = manager.peripheral(.UUID(info.UUID)),
              let services = info.peripheral.services
        else {
            return
        }
        
        services.forEach({ peripheral.discoverCharacteristics(nil, for: $0) })
    }
    
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
    
    func discoverPeripheralDescriptors(with manager: WWBluetoothManager, info: WWBluetoothManager.DiscoverDescriptors) {
        wwPrint(info.characteristic.properties._parse())
    }
}
```
