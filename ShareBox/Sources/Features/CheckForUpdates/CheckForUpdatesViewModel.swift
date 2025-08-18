//
//  CheckForUpdatesViewModel.swift
//  ShareBox
//
//  Created by Thom van den Broek on 18/08/2025.
//

import SwiftUI
import Sparkle

class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}
