//
//  GlobalContext.swift
//  ShareBox
//
//  Created by Thom van den Broek on 15/09/2025.
//

import SwiftUI

@Observable class GlobalContext {
    public var settingsTab: SettingsTab = .preferences
    public var forcePreviewUploader: Bool = false

    private(set) var settingsRequestID = UUID()
    private var _openSettingsAction: OpenSettingsAction?

    public func initialize(openSettings: OpenSettingsAction) {
        self._openSettingsAction = openSettings

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.thom1606.ShareBox.openSettings"),
            object: nil,
            queue: .main
        ) { _ in
            self.settingsRequestID = UUID()
            self._openSettingsAction!()
        }

        #if RELEASE
        if isAnotherInstanceRunning() {
            DistributedNotificationCenter.default().post(
                name: NSNotification.Name("com.thom1606.ShareBox.openSettings"),
                object: nil
            )
            Task {
                try? await Task.sleep(for: .seconds(0.1))
                exit(0)
            }
        }
        #endif
    }

    public func openSettingsTab(_ tab: SettingsTab) {
        self.settingsTab = tab
        _openSettingsAction?()
    }

    private func isAnotherInstanceRunning() -> Bool {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
        return runningApps.count > 1
    }
}
