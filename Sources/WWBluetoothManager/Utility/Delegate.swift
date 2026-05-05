//
//  Delegate.swift
//  WWBluetoothManager
//
//  Created by WilliamWeng on 2026/5/4.
//

import CoreBluetooth

// MARK: - Delegate
public extension WWBluetoothManager {
    
    /// 藍牙中心的Delegate
    protocol CentralDelegate: AnyObject {
        
        /// **CentralManager 事件**：狀態更新、掃描發現、連線狀態變化
        /// - Parameters:
        ///   - central: Central 管理器實例
        ///   - status: CentralStatus enum，包含所有中央管理器事件
        func centralManager(_ central: Central, status: CentralStatus)
        
        /// **Peripheral 事件**：服務發現、特性操作、資料通訊
        /// - Parameters:
        ///   - central: Central 管理器實例
        ///   - peripheral: 觸發事件的具體周邊設備
        ///   - status: PeripheralStatus enum，包含所有外設操作事件
        func centralManager(_ central: Central, peripheral: CBPeripheral, status: PeripheralStatus)
    }
}

