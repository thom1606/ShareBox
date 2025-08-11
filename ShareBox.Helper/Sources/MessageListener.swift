//
//  MessageListener.swift
//  Helper
//
//  Created by Thom van den Broek on 09/08/2025.
//

import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

class MessageListener {
    private var localPort: CFMessagePort?
    private var runLoopSource: CFRunLoopSource?
    
    init() {
        var context = CFMessagePortContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        localPort = CFMessagePortCreateLocal(nil, Constants.Mach.portName as CFString, { (port, msgid, data, info) -> Unmanaged<CFData>? in
            guard let data = data else { return nil }
            let receivedData = data as Data
            do {
                let decoder = JSONDecoder()
                let machMessage = try decoder.decode(MachMessage.self, from: receivedData)
                
                let myBuildNumber = Int((Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1") ?? 1
                if myBuildNumber != machMessage.buildNumber {
                    generalLogger.error("Invalid version of Helper running for this instance, killing this helper")
                    let response = try? JSONEncoder().encode(["success": "false", "error": "INVALID_HELPER_VERSION"])
                    NSApp.terminate(nil)
                    return response.map { Unmanaged.passRetained($0 as CFData) }
                }
                
                switch (machMessage.type) {
                case .requestNotifications:
                    Notifications.requestAccess()
                    break
                case .notify:
                    do {
                        let msg = try decoder.decode(NotificationBody.self, from: machMessage.data!)
                        Notifications.show(title: msg.title, body: msg.message)
                    } catch {
                        generalLogger.warning("Failed to send out notification: \(error.localizedDescription)")
                    }
                    break
                case .fileUploadRequest:
                    generalLogger.debug("Received file upload request...")
                    // Check if already processing
                    if SharedValues.isProcessing {
                        generalLogger.error("Another upload process is already in progress!")
                        let response = try? JSONEncoder().encode(["success": "false", "status": "busy"])
                        return response.map { Unmanaged.passRetained($0 as CFData) }
                    } else {
                        // Initiate file upload
                        MessageListener.handleFileUpload(payload: try decoder.decode(FileUploadBody.self, from: machMessage.data!))
                    }
                    break
                }
            } catch {
                print("Failed to decode MachMessage: \(error)")
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
    
    private static func handleFileUpload(payload: FileUploadBody) {
        DispatchQueue.main.async {
            UploadWindowController.shared.show(items: payload.items)
        }
    }
}
