//
//  File.swift
//  ThomKit
//
//  Created by Thom van den Broek on 04/08/2025.
//

import SwiftUI

extension EnvironmentValues {
    @Entry var isLoading: Bool = false
    @Entry var settingsTab: Binding<SettingsTab> = .constant(.preferences)
}

extension View {
    func isLoading(_ loading: Bool) -> any View {
        self.environment(\.isLoading, loading)
    }
}
