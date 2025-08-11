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
    
    var completedPaths: [String] = []
    var failedPaths: [String: String] = [:]
    
    public func handleAppear(_ items: [FilePath]) async {
        SharedValues.isProcessing = true
        uploadProgress = 0

        do {
            try await Task.sleep(for: .milliseconds(100))
            
            withAnimation(.spring(duration: 0.3)) {
                self.hidden = false
                // TODO: check if we want to fully extend the notch at the start or not
                self.notchPercentage = 1
            }
            
            try await Task.sleep(for: .milliseconds(2000))
            completedPaths.append(items[0].absolute)
            uploadProgress = 50
            try await Task.sleep(for: .milliseconds(2000))
            failedPaths["\(items[1].absolute)"] = "Something went wrong"
            completedPaths.append(items[1].absolute)
            uploadProgress = 100
            
            SharedValues.isProcessing = false
        } catch {
            SharedValues.isProcessing = false
        }
    }
}
