//
//  MouseListener.swift
//  Test
//
//  Created by Thom van den Broek on 14/08/2025.
//

import SwiftUI

class MouseListener {
    private var mouseMonitor: Any?
    private var window: NSWindow?
    private var timer: Timer?
    private var timedPaused: Bool = false

    public var paused: Bool = false {
        didSet {
            if paused {
                self.timer?.invalidate()
                timedPaused = true
            } else {
                self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                    self.timedPaused = false
                }
            }
        }
    }

    func startTrackingMouse(window: NSWindow) {
        self.window = window
        self.updateWindowPosition()
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.updateWindowPosition()
        }
    }

    private func updateWindowPosition() {
        guard let window = window else { return }
        if timedPaused { return }
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            let screenFrame = screen.visibleFrame
            let windowHeight = screenFrame.size.height
            window.setFrame(NSRect(x: screenFrame.minX, y: screenFrame.minY, width: Constants.Uploader.windowWidth, height: windowHeight), display: true)
        }
    }

}
