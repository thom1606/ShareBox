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
                    switch machMessage.type {
                    case .fileUploadRequest:
                        generalLogger.debug("Received file upload request...")
                        let res = try decoder.decode(MachFileUploadBody.self, from: machMessage.data!)
                        Task {
                            await listener.state.appendFiles(res.items)
                        }
                    case .peek:
                        listener.state.forcePreviewVisible = true
                    }
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
}
