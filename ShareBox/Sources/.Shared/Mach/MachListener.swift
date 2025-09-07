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
        do {
            switch message.type {
            case .fileUploadRequest:
                generalLogger.debug("Received file upload request...")
                let res = try decoder.decode(MachFileUploadBody.self, from: message.data!)
                // Make sure no other active uploader is active
                if self.state.activeUploader != nil {
                    if self.state.activeUploader!.getId() != .sharebox {
                        Utilities.showNotification(
                            title: String(localized: "Another upload in progress"),
                            body: String(localized: "Another upload progress outside of ShareBox is currently in progress. Please wait for it to complete before attempting to upload again.")
                        )
                        return
                    }
                }
                // If ShareBox is currently active, append these files to the queue
                Task {
                    let uploader = self.state.getUploader(for: .sharebox)
                    uploader.confirmDrop(paths: res.items)
                }
            case .openSettings:
                generalLogger.debug("Got requested to open settings...")
                self.state.openSettings?(nil)
            case .peek:
                self.state.forcePreviewVisible = true
            }
        } catch {
            generalLogger.error("Failed to handle MachMessage: \(error)")
        }
    }
}
