//
//  Model.swift
//  Example
//
//  Created by iOS on 2026/5/13.
//

import Foundation

// MARK: - Models
struct IncomingFileSession {
    
    let transferId: UInt32
    let expectedTotalChunks: UInt32
    let fileName: String
    let typeIdentifier: String
    let fileSize: UInt32
    let chunkSize: UInt16
    
    var chunks: [UInt32: Data] = [:]
    var lastLoggedReceivePercent = -1
    
    var calculatedTotalChunks: Int {
        guard fileSize > 0, chunkSize > 0 else { return 0 }
        return Int((fileSize + UInt32(chunkSize) - 1) / UInt32(chunkSize))
    }
    
    var receivedBytes: Int {
        chunks.values.reduce(0) { $0 + $1.count }
    }
    
    var isComplete: Bool {
        chunks.count == Int(expectedTotalChunks) && (fileSize == 0 || receivedBytes == Int(fileSize))
    }
    
    func mergedData() -> Data? {
        
        guard isComplete else { return nil }
        
        return (0..<expectedTotalChunks).reduce(into: Data()) { result, index in
            guard let chunk = chunks[index] else { return }
            result.append(chunk)
        }
    }
}
