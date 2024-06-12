//
//  BluetoothManager+Delegate.swift
//  WWBluetoothManager
//
//  Created by William.Weng on 2023/11/29.
//

import CoreBluetooth

// 藍牙管理的Delegate
public protocol WWBluetoothManagerDelegate {
    
    /// 手機藍牙的更新狀態
    /// - Parameters:
    ///   - manager: WWBluetoothManager
    ///   - state: CBManagerState
    func updateState(manager: WWBluetoothManager, state: CBManagerState)
    
    /// 搜尋到的週邊設備 (不重複)
    /// - Parameters:
    ///   - manager: WWBluetoothManager
    ///   - peripherals: Set<CBPeripheral>
    ///   - newPeripheralInformation: WWBluetoothManager.PeripheralInformation
    func discoveredPeripherals(manager: WWBluetoothManager, peripherals: Set<CBPeripheral>, newPeripheralInformation: WWBluetoothManager.PeripheralInformation)
        
    /// 取得剛連上設備的資訊
    /// - Parameters:
    ///   - manager: WWBluetoothManager
    ///   - result: Result<WWBluetoothManager.ConnectType, WWBluetoothManager.PeripheralError>
    func didConnectPeripheral(manager: WWBluetoothManager, result: Result<WWBluetoothManager.PeripheralConnectType, WWBluetoothManager.PeripheralError>)
    
    /// 處理已經連上設備的Services / Characteristics / Descriptors
    /// - Parameters:
    ///   - manager: WWBluetoothManager
    ///   - result: Result<WWBluetoothManager.DiscoverValueType, WWBluetoothManager.PeripheralError>
    func didDiscoverPeripheral(manager: WWBluetoothManager, result: Result<WWBluetoothManager.DiscoverValueType, WWBluetoothManager.PeripheralError>)
    
    /// 週邊設備數值相關的功能
    /// - Parameters:
    ///   - manager: WWBluetoothManager
    ///   - result: Result<WWBluetoothManager.PeripheralValueInformation, WWBluetoothManager.PeripheralError>
    func didUpdatePeripheral(manager: WWBluetoothManager, result: Result<WWBluetoothManager.PeripheralValueInformation, WWBluetoothManager.PeripheralError>)
    
    /// 週邊設備服務更動的功能
    /// - Parameters:
    ///   - manager: WWBluetoothManager
    ///   - information: WWBluetoothManager.ModifyServicesInformation
    func didModifyServices(manager: WWBluetoothManager, information: WWBluetoothManager.ModifyServicesInformation)
}
