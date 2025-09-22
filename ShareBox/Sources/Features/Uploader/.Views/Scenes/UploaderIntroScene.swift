//
//  UploaderIntroScene.swift
//  ShareBox
//
//  Created by Thom van den Broek on 06/09/2025.
//

import SwiftUI

struct UploaderIntroScene: View {
    private let api = ApiService()
    @Environment(User.self) private var user
    @Environment(GlobalContext.self) private var globalContext
    @Environment(UploaderViewModel.self) private var uploader

    @AppStorage(Constants.Settings.completedCloudDriveOnboardingPrefKey) private var completedCloudDriveOnboarding = false
    @AppStorage(Constants.Settings.keepInMenuBarPrefKey) private var keepInMenuBar = true
    @State private var showCloudPopover = false

    private var shouldShowCloudPopover: Bool {
        // Only show when in small UI state and no items have been dropped yet
        guard uploader.uiState == .small else { return false }
        if !uploader.droppedItems.isEmpty {
            completedCloudDriveOnboarding = true
            return false
        }
        return !completedCloudDriveOnboarding
    }

    var body: some View {
        VStack(spacing: 8) {
            UploaderDropField(type: .sharebox, image: Image("Images/CloudLink"), isPlus: true)
            UploaderDropField(type: .airdrop, image: Image("Images/Airdrop"))
            Rectangle()
                .fill(Color("Colors/TileBackground"))
                .frame(width: 44, height: 2)
            if !user.drivesData.isEmpty {
                ForEach(user.drivesData, id: \.id) { drive in
                    if let type = drive.getUploaderType() {
                        UploaderDropField(
                            type: type,
                            image: Image("Images/Drives/\(drive.provider)"),
                            metadata: .init(providerId: drive.id)
                        )
                    }
                }
            } else {
                UploaderButtonField(image: Image(systemName: "plus.circle"), onTap: {
                    completedCloudDriveOnboarding = true
                    globalContext.openSettingsTab(.drives)
                })
                .onHover { isOver in
                    if !isOver { completedCloudDriveOnboarding = true }
                }
                .popover(isPresented: .constant(shouldShowCloudPopover), attachmentAnchor: .point(.trailing), arrowEdge: .leading) {
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
            if !keepInMenuBar {
                Rectangle()
                    .fill(Color("Colors/TileBackground"))
                    .frame(width: 44, height: 2)
                UploaderButtonField(image: Image(systemName: "gearshape"), onTap: {
                    globalContext.openSettingsTab(.preferences)
                })
            }
        }
        .padding(8)
    }
}
