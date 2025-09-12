//
//  Data.swift
//  ShareBox
//
//  Created by Thom van den Broek on 12/09/2025.
//

import Foundation

extension Data {
    mutating func appendString(_ string: String) {
        self.append(contentsOf: string.utf8)
    }
}
