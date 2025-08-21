//
//  Constants.swift
//  Sharebox
//
//  Created by Thom van den Broek on 07/08/2025.
//

import SwiftUI

final class Constants {
    final class Settings {
        static let storagePrefKey = "STORAGE_DURATION"
        static let passwordPrefKey = "GROUPS_PASSWORD"
        static let hiddenFilesPrefKey = "INCLUDE_HIDDEN_FILES"
        static let uploadNotificationsPrefKey = "SHOW_UPLOAD_NOTIFICATIONS"
        static let mouseActivationPrefKey = "MOUSE_ACTIVATION"
        static let keepInDockPrefKey = "KEEP_IN_DOCK"
        static let keepNotchOpenWhileUploadingPrefKey = "KEEP_OPEN_WHILE_UPLOADING"
        static let completedOnboardingPrefKey = "COMPLETED_ONBOARDING"
    }
    final class Uploader {
        static let windowWidth: CGFloat = 120
    }
    final class Mach {
        static let portName = "group.com.thom1606.ShareBox.mach"
    }
}
