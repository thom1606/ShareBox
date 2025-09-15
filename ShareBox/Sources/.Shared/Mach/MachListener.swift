//
//  MachListener.swift
//  ShareBox
//
//  Created by Thom van den Broek on 17/08/2025.
//

import Foundation

class MachMessageListener {
    private var localPort: CFMessagePort?
    private var runLoopSource: CFRunLoopSource?

    public var state: UploaderViewModel

    init(state: UploaderViewModel) {
        self.state = state

        var context = CFMessagePortContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        localPort = CFMessagePortCreateLocal(nil, Constants.Mach.portName as CFString, { (_, _, data, info) -> Unmanaged<CFData>? in
            guard let data = data else { return nil }
            let receivedData = data as Data
            do {
                let decoder = JSONDecoder()
                let machMessage = try decoder.decode(MachMessage.self, from: receivedData)

                if let info = info {
                    let listener = Unmanaged<MachMessageListener>.fromOpaque(info).takeUnretainedValue()
                    listener.handleMessage(message: machMessage)
                }
            } catch {
                generalLogger.error("Failed to decode MachMessage: \(error)")
            }

            return Unmanaged.passRetained(data)
        }, &context, nil)

        if let localPort = localPort {
            runLoopSource = CFMessagePortCreateRunLoopSource(nil, localPort, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
    }

    deinit {
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
    }

    private func handleMessage(message: MachMessage) {
        let decoder = JSONDecoder()
        switch message.type {
        case .openSettings:
            generalLogger.debug("Got requested to open settings...")
            self.state.openSettings?(nil)
        case .peek:
            self.state.forcePreviewVisible = true
        }
    }
}
