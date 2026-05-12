//
//  TransferFile.swift
//  Example
//
//  Created by iOS on 2026/5/12.
//

import Foundation
import UniformTypeIdentifiers

struct TransferFileHeader: Codable {
    let fileName: String
    let typeIdentifier: String
}

struct TransferFile {
    
    let fileName: String
    let typeIdentifier: String
    let data: Data
    
    func encoded() throws -> Data {
        
        let header = TransferFileHeader(
            fileName: fileName,
            typeIdentifier: typeIdentifier
        )
        
        let headerData = try JSONEncoder().encode(header)
        var headerLength = UInt32(headerData.count).bigEndian
        
        let lengthData = withUnsafeBytes(of: &headerLength) { Data($0) }
        
        var container = Data()
        container.append(lengthData)
        container.append(headerData)
        container.append(data)
        
        return container
    }
    
    static func decode(from container: Data) throws -> TransferFile {
        
        let headerLengthSize = MemoryLayout<UInt32>.size
        guard container.count >= headerLengthSize else {
            throw TransferError.invalidHeaderLength
        }
        
        let lengthData = container.prefix(headerLengthSize)
        let headerLength = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        
        let headerStart = headerLengthSize
        let headerEnd = headerStart + Int(headerLength)
        
        guard container.count >= headerEnd else {
            throw TransferError.invalidHeaderData
        }
        
        let headerData = container.subdata(in: headerStart..<headerEnd)
        let payloadData = container.subdata(in: headerEnd..<container.count)
        
        let header = try JSONDecoder().decode(TransferFileHeader.self, from: headerData)
        
        return TransferFile(
            fileName: header.fileName,
            typeIdentifier: header.typeIdentifier,
            data: payloadData
        )
    }
    
    var contentType: UTType? {
        UTType(typeIdentifier)
    }
    
    var isImage: Bool {
        contentType?.conforms(to: .image) == true
    }
    
    var preferredFileExtension: String? {
        contentType?.preferredFilenameExtension
    }
    
    var normalizedFileName: String {
        
        guard let preferredFileExtension else { return fileName }
        
        let url = URL(fileURLWithPath: fileName)
        let currentExtension = url.pathExtension.lowercased()
        
        guard currentExtension != preferredFileExtension.lowercased() else {
            return fileName
        }
        
        let baseName = url.deletingPathExtension().lastPathComponent
        return "\(baseName).\(preferredFileExtension)"
    }
}

enum TransferError: Error {
    case invalidHeaderLength
    case invalidHeaderData
}
