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
        static let keepInMenuBarPrefKey = "KEEP_IN_MENUBAR"
        static let keepNotchOpenWhileUploadingPrefKey = "KEEP_OPEN_WHILE_UPLOADING"
        static let overMonthlyLimitStoragePrefKey = "CAN_GO_OVER_LIMIT"
        static let completedOnboardingPrefKey = "COMPLETED_ONBOARDING"
        static let completedCloudDriveOnboardingPrefKey = "COMPLETED_CLOUD_DRIVE_ONBOARDING"
    }
    final class Uploader {
        static let windowWidth: CGFloat = 140
    }
    final class Mach {
#if DEBUG
        static let portName = "group.com.thom1606.ShareBox.Dev.mach"
#else
        static let portName = "group.com.thom1606.ShareBox.mach"
#endif
    }
}
