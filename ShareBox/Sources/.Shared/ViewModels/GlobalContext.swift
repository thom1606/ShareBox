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
    }

    public func openSettingsTab(_ tab: SettingsTab) {
        self.settingsTab = tab
        _openSettingsAction?()
    }
}
