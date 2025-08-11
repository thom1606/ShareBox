//
//  UploadViewModel.swift
//  ShareBox.Helper
//
//  Created by Thom van den Broek on 11/08/2025.
//

import SwiftUI

@MainActor
@Observable class UploadViewModel {
    // If the whole window should be off screen
    var hidden: Bool = true
    // How far out the notch should be visible, number between 0 and 1
    var notchPercentage: CGFloat = 0
    // The percentage of items/progress made in the upload, number between 0 and 100
    var uploadProgress: CGFloat = 0
}
