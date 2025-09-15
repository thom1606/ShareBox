//
//  UploaderDropField.swift
//  ShareBox
//
//  Created by Thom van den Broek on 05/09/2025.
//

import SwiftUI

struct UploaderDropField: View {
    var index: Int
    var type: UploaderId
    var image: Image
    var metadata: FileUploaderMetaData?
    var isPlus: Bool = false

    @Environment(User.self) private var user
    @Environment(GlobalContext.self) private var globalContext
    @Environment(UploaderViewModel.self) private var uploader

    @State private var isHovering: Bool = false
    @State private var pickerShowing: Bool = false

    var heightOffset: CGFloat {
        if type == .airdrop { return 10 }
        return 0
    }

    var dropOffset: CGFloat {
        return 0
    }

    var showPlusBadge: Bool {
        return isPlus && (user.subscriptionData?.status ?? .inactive) != .active
    }

    var body: some View {
        @Bindable var state = uploader
        let shouldHover = isHovering || pickerShowing

        ZStack(alignment: .center) {
            GeometryReader { geo in
                Color.black.opacity(0.001)
                    .onDrop(of: [.fileURL], isTargeted: $isHovering, perform: { providers in
                        if showPlusBadge {
                            globalContext.openSettingsTab(.account)
                            return false
                        }
                        state.activateUploader(for: type)
                        // Get the appropriate uploader for this drop field
                        let targetUploader = state.getUploader(for: type)
                        return targetUploader.confirmDrop(providers: providers, metadata: metadata)
                    })
                    .frame(width: geo.size.width, height: geo.size.height + heightOffset)
                    .offset(x: uploader.uiState == .hidden ? 60 : 0, y: dropOffset)
            }
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(shouldHover ? Color.accentColor.opacity(0.3) : Color("Colors/TileBackground"))
                    .stroke(shouldHover ? Color.accentColor : .clear)
                    .frame(width: 44, height: 66)
                    .animation(.spring, value: shouldHover)
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(shouldHover ? Color.accentColor : .white.opacity(0.5))
                    .animation(.spring, value: shouldHover)

                if showPlusBadge {
                    VStack {
                        Spacer()
                        Text("Plus")
                            .foregroundStyle(.accent)
                            .font(.caption.weight(.medium))
                    }
                    .padding(.bottom, 6)
                }
            }
            .onHover { isOver in
                isHovering = isOver
            }
            .onTapGesture {
                if pickerShowing { return }
                if showPlusBadge {
                    globalContext.openSettingsTab(.account)
                    return
                }
                state.activateUploader(for: type)
                // Create and open new NSOpenPanel to select files for uploader
                let openPanel = NSOpenPanel()
                openPanel.allowsMultipleSelection = true
                openPanel.canChooseDirectories = true
                openPanel.canChooseFiles = true
                openPanel.begin { result in
                    state.forceVisible = false
                    pickerShowing = false
                    if result == .OK {
                        let targetUploader = state.getUploader(for: type)
                        targetUploader.confirmDrop(paths: openPanel.urls.map { $0.toFilePath() }, metadata: metadata)
                    }
                    openPanel.close()
                }
                openPanel.center()
                openPanel.makeKey()
                state.forceVisible = true
                pickerShowing = true
            }
        }
        .frame(width: 60, height: 74)
        .frame(maxWidth: 60, maxHeight: 74)
        .onChange(of: isHovering) {
            if state.dropTargets.count <= index {
                state.dropTargets = Array(repeating: false, count: index + 1)
            }
            state.dropTargets[index] = isHovering
        }
    }
}
