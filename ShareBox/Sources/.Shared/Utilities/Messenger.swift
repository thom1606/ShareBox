//
//  Messenger.swift
//  ShareBox
//
//  Created by Thom van den Broek on 11/08/2025.
//

import Foundation

class Messenger {
    static let shared = Messenger()

    private var remote: CFMessagePort?

    init() {
        try? self.setup()
    }

    public func send(_ message: MachMessage) throws -> Data? {
        guard let remote = remote else {
            do {
                try self.setup()
                return try self.send(message)
            } catch {
                // TODO: maybe retry the setup or creating helper
                throw ShareBoxError.helperNotRunning
            }
        }

        let messageID: Int32 = 0x1111
        let timeout: CFTimeInterval = 1.0

        var returnData: Unmanaged<CFData>?
        let status = CFMessagePortSendRequest(remote, messageID, message.encode(), timeout, timeout, CFRunLoopMode.defaultMode.rawValue, &returnData)
        if status == kCFMessagePortSuccess, let data = returnData?.takeRetainedValue() as Data? {
            if let response = try? JSONDecoder().decode([String: String].self, from: data),
               response["error"] == "INVALID_HELPER_VERSION" {
                throw ShareBoxError.helperNotRunning
            }

            return data
        } else {
            return nil
        }

    }

    private func setup() throws {
        guard let remotePort = CFMessagePortCreateRemote(nil, Constants.Mach.portName as CFString) else {
            generalLogger.error("Failed to connect to ShareBox Helper")
            self.remote = nil
            throw ShareBoxError.helperNotRunning
        }
        self.remote = remotePort
    }
}
