//
//  String.swift
//  ShareBox
//
//  Created by Thom van den Broek on 19/08/2025.
//

import Foundation

extension String {
    // Get character at certain position in string
    subscript(offset: Int) -> Character {
        self[index(startIndex, offsetBy: offset)]
    }
}
