//
//  AccessoryTransfer.swift
//  WWBluetoothManager
//
//  Created by William.Weng on 2026/5/14.
//

import Foundation

public extension WWBluetoothManager {
    
    final class AccessoryTransfer {
        
        private let controller = FileTransferController()
        
        public init() {}
    }
}

public extension WWBluetoothManager.AccessoryTransfer {
    
    enum TransferEvent {
        case didReceiveHello(fileName: String, contentType: String, size: UInt32)
        case didReceiveChunk(index: UInt32, total: UInt32)
        case didFinish(data: Data)
        case didFail(error: Error)
    }
}
