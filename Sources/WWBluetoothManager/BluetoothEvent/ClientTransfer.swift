//
//  ClientTransfer.swift
//  WWBluetoothManager
//
//  Created by William.Weng on 2026/5/14.
//

import Foundation
import CoreBluetooth
import UniformTypeIdentifiers

public extension WWBluetoothManager {
    
    /// Client 端的檔案傳輸模組。
    ///
    /// 這個型別負責包裝內部的 `FileTransferController`，
    /// 對外提供較單純的送檔入口與事件回呼介面。
    final class ClientTransfer {
        
        /// 內部實際執行檔案傳輸流程的控制器。
        private let controller = FileTransferController()
        
        /// 傳輸過程中的事件回呼。
        public var onEvent: ((WWBluetoothManager.ClientTransferEvent) -> Void)?
        
        public init() {
            
            controller.onClientTransferEvent = { [weak self] event in
                switch event {
                case .didStart(let transferId): self?.onEvent?(.didStart(transferId: transferId))
                case .didSendHello(let transferId): self?.onEvent?(.didSendHello(transferId: transferId))
                case .didSendChunk(let index, let total): self?.onEvent?(.didSendChunk(index: index, total: total))
                case .didFinish(let transferId): self?.onEvent?(.didFinish(transferId: transferId))
                case .didFail(let error): self?.onEvent?(.didFail(error: error))
                }
            }
        }
    }
}

// MARK: - Public API
public extension WWBluetoothManager.ClientTransfer {
    
    /// 傳送檔案給指定的藍牙周邊裝置。
    ///
    /// 這個版本將檔案資訊與傳輸使用的 characteristics 分別包裝成型別，
    /// 讓呼叫端不必個別傳入檔名、型別字串、資料內容與 control / data characteristics，
    /// 可降低漏填或傳錯參數的機率。`UTType` 可透過 `identifier` 轉成對應的 type identifier 字串。[web:125][web:131]
    ///
    /// - Parameters:
    ///   - peripheral: 目前要寫入資料的遠端裝置。
    ///   - fileInfo: 本次傳輸的檔案資訊，包含檔名、內容型別與原始資料。
    ///   - characteristics: 本次檔案傳輸使用的 control / data characteristics。
    /// - Throws: 當檔名或型別資訊無法正確寫入握手 payload 時拋出錯誤。
    func sendFile(using peripheral: CBPeripheral, fileInfo: WWBluetoothManager.FileInformation, characteristics: WWBluetoothManager.TransferCharacteristics) throws {
        
        do {
            try controller.sendFile(using: peripheral, fileName: fileInfo.name, typeIdentifier: fileInfo.contentType.identifier, data: fileInfo.data, controlCharacteristic: characteristics.control, dataCharacteristic: characteristics.data)
        } catch {
            onEvent?(.didFail(error: error))
            throw error
        }
    }
    
    /// 處理來自藍牙層的 peripheral 狀態事件，並轉交給檔案傳輸控制器
    ///
    /// - Parameters:
    ///   - peripheral: 目前互動中的遠端裝置
    ///   - status: 由藍牙層回傳的 peripheral 狀態事件
    func handle(peripheral: CBPeripheral, status: WWBluetoothManager.PeripheralStatus) {
        controller.handle(peripheral: peripheral, status: status)
    }
}
