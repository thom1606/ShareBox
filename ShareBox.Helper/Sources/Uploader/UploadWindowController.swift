//
//  UploadWindowController.swift
//  ShareBox.Helper
//
//  Created by Thom van den Broek on 11/08/2025.
//

import AppKit
import SwiftUI
import UserNotifications

final class UploadWindowController: NSWindowController {
    static let shared = UploadWindowController()
    
    private init() {
        let root = UploadView(items: [])
        let hosting = NSHostingView(rootView: root)

        // Determine the active screen (key window's screen, or main screen as fallback)
        let activeScreen = NSApp.keyWindow?.screen ?? NSScreen.main
        // Default to main screen's frame if activeScreen is nil
        let screenFrame = activeScreen?.visibleFrame ?? NSScreen.main!.visibleFrame

        let windowWidth: CGFloat = SharedValues.uploaderWindowWidth
        let windowHeight: CGFloat = max(600, screenFrame.size.height / 2)
        
        // Center it vertically on the screen
        let y = screenFrame.origin.y + (screenFrame.size.height - windowHeight) / 2

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: y, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.title = "ShareBox Uploader"
        window.contentView = hosting
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(items: [FilePath]) {
        // Ask for notification access once we show the uploader
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
        
        // Re-render the ui with items instead of nothing
        if let window = self.window {
            window.contentView = NSHostingView(rootView: UploadView(items: items))
            window.makeKeyAndOrderFront(nil)
        }
        // Push the app to the foreground
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

