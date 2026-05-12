//
//  LogTextView.swift
//  Example
//
//  Created by WilliamWeng on 2026/5/6.
//

import UIKit

@MainActor
final class LogTextView: UITextView {
    
    private static let dateFormatter: DateFormatter = makeDateFormatter()
    
    func configure() {
        text = ""
        isEditable = false
        isSelectable = true
    }
    
    func appendLog(_ message: String) {
        
        let timestamp = Self.dateFormatter.string(from: Date())
        let line = "[\(timestamp)] \(message)"
        let currentText = text ?? ""
        let prefix = currentText.isEmpty ? "" : "\n"
        
        text = currentText + prefix + line
        scrollLogToBottom()
    }
    
    func clear() {
        text = ""
    }
    
    func scrollLogToBottom() {
        
        let currentText = text ?? ""
        let length = (currentText as NSString).length
        guard length > 0 else { return }
        
        let range = NSRange(location: length - 1, length: 1)
        scrollRangeToVisible(range)
    }
}

private extension LogTextView {
    
    static func makeDateFormatter(_ dateFormat: String = "HH:mm:ss.SSS") -> DateFormatter {
        
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        return formatter
    }
}
