//
//  NotchIntroScene.swift
//  ShareBox
//
//  Created by Thom van den Broek on 06/09/2025.
//

import SwiftUI

struct NotchIntroScene: View {
    private let api = ApiService()
    @Environment(UploaderViewModel.self) private var uploader
    @Environment(User.self) private var user
    @Environment(\.settingsTab) private var settingsTab
    @Environment(\.openSettings) private var openSettings

    @AppStorage(Constants.Settings.completedCloudDriveOnboardingPrefKey) private var completedCloudDriveOnboarding = false

    private var showCloudStorageOption: Bool {
        if uploader.uiState != .small { return false }
        if !uploader.droppedItems.isEmpty {
            completedCloudDriveOnboarding = true
            return false
        }
        if !completedCloudDriveOnboarding { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            UploaderDropField(index: 0, type: .sharebox, image: Image("Images/CloudLink"), isPlus: true)
            UploaderDropField(index: 1, type: .airdrop, image: Image("Images/Airdrop"))
            Rectangle()
                .fill(Color("Colors/TileBackground"))
                .frame(width: 44, height: 2)
                .padding(.vertical, 4)
            if !user.drivesData.isEmpty {
                ForEach(Array(user.drivesData.enumerated()), id: \.element.id) { index, drive in
                    if let type = drive.getUploaderType() {
                        UploaderDropField(
                            index: index + 2,
                            type: type,
                            image: Image("Images/Drives/\(drive.provider)"),
                            metadata: .init(providerId: drive.id)
                        )
                    }
                }
            } else {
                UploaderButtonField(image: Image(systemName: "plus.circle"), onTap: {
                    completedCloudDriveOnboarding = true
                    if user.authenticated {
                        settingsTab.wrappedValue = .drives
                    } else {
                        settingsTab.wrappedValue = .account
                    }
                    openSettings()
                })
                .popover(isPresented: .constant(showCloudStorageOption), attachmentAnchor: .point(.trailing), arrowEdge: .leading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Got cloud storage?")
                            .font(.headline)
                        Text("Upload files straight to your personal drive of choice for later access.")
                            .font(.body)
                            .padding(.top, 3)
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 200, idealWidth: 200, maxWidth: 200)
                    .padding(10)
                }
            }
        }
    }
}
