//
//  BluetoothManager+Delegate.swift
//  WWBluetoothManager
//
//  Created by William.Weng on 2023/11/29.
//

import CoreBluetooth
import WWOrderedSet

// MARK: - WWBluetoothManager.Delegate
extension WWBluetoothManager {
    
    // 藍牙管理的Delegate
    public protocol Delegate {
        
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
        func discoveredPeripherals(manager: WWBluetoothManager, peripherals: WWOrderedSet<CBPeripheral>, newPeripheralInformation: WWBluetoothManager.PeripheralInformation)
        
        /// 處理設備的事件資訊 (整合)
        /// - Parameters:
        ///   - manager: WWBluetoothManager
        ///   - eventType: PeripheralEventType
        func peripheralEvent(manager: WWBluetoothManager, eventType: PeripheralEventType)
        
        /// 處理設備的資訊取得 (整合)
        /// - Parameters:
        ///   - manager: WWBluetoothManager
        ///   - actionType: PeripheralActionType
        func peripheralAction(manager: WWBluetoothManager, actionType: PeripheralActionType)
    }
}

// MARK: - WWBluetoothPeripheralManager.Delegate
extension WWBluetoothPeripheralManager {
    
    public protocol Delegate: AnyObject {
        
        func managerIsReady(manager: WWBluetoothPeripheralManager, MTU: Int)    // 裝置準備完成
        func receiveValue(manager: WWBluetoothPeripheralManager, value: Data)   // 接到的資訊
        func errorMessage(manager: WWBluetoothPeripheralManager, error: Error)  // 錯誤訊息
    }
}
