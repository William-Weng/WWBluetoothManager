//
//  Extension.swift
//  Example
//
//  Created by iOS on 2026/5/13.
//

import UIKit

extension Data {
    
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
