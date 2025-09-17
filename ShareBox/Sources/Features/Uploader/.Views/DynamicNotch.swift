//
//  DynamicNotch.swift
//  ShareBox
//
//  Created by Thom van den Broek on 16/09/2025.
//

import SwiftUI

struct DynamicNotch<CompactContent: View, SlimContent: View, ExpandedContent: View>: View {
    @ViewBuilder var compact: () -> CompactContent
    @ViewBuilder var slim: () -> SlimContent
    @ViewBuilder var expanded: () -> ExpandedContent

    @Environment(UploaderViewModel.self) private var state

    @State private var compactSize: CGSize = .zero
    @State private var slimSize: CGSize = .zero
    @State private var expandedSize: CGSize = .zero

    @State private var cornerRadii: CGFloat = 15
    @State private var uiSize: CGSize = .zero
    @State private var compactOpacity: CGFloat = 1
    @State private var slimOpacity: CGFloat = 0
    @State private var expandedOpacity: CGFloat = 0
    @State private var globalMonitor: Any?
    @State private var localMonitor: Any?

    private func updateUI() {
        withAnimation(.smooth) {
            compactOpacity = 0
            slimOpacity = 0
            expandedOpacity = 0
            if state.uiState == .hidden {
                cornerRadii = 1
                uiSize = .init(width: 0, height: compactSize.height / 1.2)
            } else if state.uiState == .small {
                cornerRadii = 15
                uiSize = compactSize
            } else if state.uiState == .peeking {
                cornerRadii = 15
                uiSize = slimSize
            } else if state.uiState == .visible {
                cornerRadii = 24
                uiSize = expandedSize
            }
        }
        withAnimation(.smooth.delay(0.1)) {
            if state.uiState == .small {
                compactOpacity = 1
            } else if state.uiState == .peeking {
                slimOpacity = 1
            } else if state.uiState == .visible {
                expandedOpacity = 1
            }
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            NotchShape(
                cornerRadii: cornerRadii
            )
            .fill(.blue)
            .frame(width: uiSize.width, height: uiSize.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            ZStack(alignment: .leading) {
                slim()
                    .opacity(slimOpacity)
                    .allowsHitTesting(state.uiState == .peeking)
                    .measureSize { size in
                        slimSize = size
                    }
                expanded()
                    .opacity(expandedOpacity)
                    .allowsHitTesting(state.uiState == .visible)
                    .measureSize { size in
                        expandedSize = size
                    }
                compact()
                    .opacity(compactOpacity)
                    .allowsHitTesting(state.uiState == .small)
                    .measureSize { size in
                        compactSize = size
                    }
            }
            .onChange(of: state.uiState, updateUI)
            .onAppear(perform: updateUI)
            .background {
                Rectangle()
                    .foregroundStyle(.black)
                    .padding(-50)
                    .allowsHitTesting(false)
            }
            .mask {
                NotchShape(
                    cornerRadii: cornerRadii
                )
                .frame(width: uiSize.width, height: uiSize.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            if localMonitor != nil { NSEvent.removeMonitor(localMonitor!) }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .mouseExited], handler: { event in
                if !NSApp.isActive { return event }
                let mouseLocation = NSEvent.mouseLocation
                if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
                    let screenFrame = screen.visibleFrame
                    let relativeX = mouseLocation.x - screenFrame.origin.x
                    let relativeY = mouseLocation.y - screenFrame.origin.y
                    handleRelativeOffset(x: relativeX, y: relativeY)
                }
                return event
            })

            if globalMonitor != nil { NSEvent.removeMonitor(globalMonitor!) }
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { _ in
                if NSApp.isActive { return }
                let mouseLocation = NSEvent.mouseLocation
                if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
                    let screenFrame = screen.visibleFrame
                    let relativeX = mouseLocation.x - screenFrame.origin.x
                    let relativeY = mouseLocation.y - screenFrame.origin.y
                    handleRelativeOffset(x: relativeX, y: relativeY)
                }
            }
        }
        .onDisappear {
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
                localMonitor = nil
            }
            if let gMonitor = globalMonitor {
                NSEvent.removeMonitor(gMonitor)
                globalMonitor = nil
            }
        }
    }

    private func handleRelativeOffset(x posX: CGFloat, y posY: CGFloat) {
        func isInFrame(size: CGSize) -> Bool {
            guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }),
                  let contentView = window.contentView else { return false }
            let topY = contentView.bounds.height / 2 - size.height / 2
            // To allow some extra play in vertically, we add an buffer area of 20 pixels
            let yOverflow: CGFloat = 20
//            print(posX)
            if posX >= 0, posY >= topY - yOverflow, posX <= size.width, posY <= size.height + topY + yOverflow {
                return true
            }
            return false
        }

        if state.uiState == .hidden && isInFrame(size: .init(width: 13, height: compactSize.height)) {
            state.isUserHovering = true
        } else if state.uiState == .small && !isInFrame(size: compactSize) {
            state.isUserHovering = false
        } else if state.uiState == .visible && !isInFrame(size: expandedSize) {
            state.isUserHovering = false
        } else if state.uiState == .peeking && isInFrame(size: slimSize) {
            state.isUserHovering = true
        }
    }
}
