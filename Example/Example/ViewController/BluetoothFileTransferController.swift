import Foundation
import CoreBluetooth
import WWBluetoothManager

/// 藍牙檔案接收範例。
///
/// 此控制器會在接收到完整檔案後，將資料寫入 App 的 Documents 目錄。
final class BluetoothFileTransferReceiver {
    
    private let controller = WWBluetoothManager.FileTransferController()
    
    /// 開始設定檔案接收流程。
    ///
    /// 收到完整檔案後，會將資料儲存成 `received-file.bin`。
    func startReceiving() {
        
        controller.onReceive = { [weak self] data in
            self?.saveToDocuments(data, fileName: "received-file.bin")
        }
    }
    
    /// 將接收到的檔案資料寫入 Documents 目錄。
    /// - Parameters:
    ///   - data: 接收到的完整檔案資料
    ///   - fileName: 要儲存的檔名
    func saveToDocuments(_ data: Data, fileName: String) {
        
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            print("檔案已儲存：\(fileURL.path)")
        } catch {
            print("檔案儲存失敗：\(error.localizedDescription)")
        }
    }
}
