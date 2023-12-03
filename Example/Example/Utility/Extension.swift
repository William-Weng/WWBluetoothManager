//
//  Extension.swift
//  Example
//
//  Created by William.Weng on 2023/11/29.
//

import CoreBluetooth
import WWBluetoothManager

// MARK: - Collection (override function)
extension Collection {

    /// [為Array加上安全取值特性 => nil](https://stackoverflow.com/questions/25329186/safe-bounds-checked-array-lookup-in-swift-through-optional-bindings)
    subscript(safe index: Index) -> Element? { return indices.contains(index) ? self[index] : nil }
}


