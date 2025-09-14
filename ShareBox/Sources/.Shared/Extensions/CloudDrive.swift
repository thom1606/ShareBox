//
//  CloudDrive.swift
//  ShareBox
//
//  Created by Thom van den Broek on 12/09/2025.
//

import Foundation

extension CloudDrive {
    func getUploaderType() -> UploaderId? {
        switch self.provider {
        case .GOOGLE:
            return .googleDrive
        case .DROPBOX:
            return .dropBox
        case .ONEDRIVE:
            return .oneDrive
//        case "ICLOUD":
//            return .iCloud
        default:
            return nil
        }
    }
}
