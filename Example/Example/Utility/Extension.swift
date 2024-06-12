//
//  Extension.swift
//  Example
//
//  Created by William.Weng on 2023/11/29.
//

import CoreBluetooth
import WWBluetoothManager

// MARK: - Data (function)
extension Data {
    
    /// Data => 字串
    /// - Parameter encoding: 字元編碼
    /// - Returns: String?
    func _string(using encoding: String.Encoding = .utf8) -> String? {
        return String(bytes: self, encoding: encoding)
    }
}

// MARK: - Collection (override function)
extension Collection {

    /// [為Array加上安全取值特性 => nil](https://stackoverflow.com/questions/25329186/safe-bounds-checked-array-lookup-in-swift-through-optional-bindings)
    subscript(safe index: Index) -> Element? { return indices.contains(index) ? self[index] : nil }
}

// MARK: - DispatchQueue (function)
extension DispatchQueue {
    
    /// 時間延遲
    /// - Parameters:
    ///   - second: TimeInterval
    ///   - qos: DispatchQoS
    ///   - flags: DispatchWorkItemFlags
    ///   - block: () -> ()
    func _delayAfter(second: TimeInterval, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [], block: @escaping () -> ()) {
        asyncAfter(deadline: .now() + second, qos: qos, flags: flags) { block() }
    }
}
