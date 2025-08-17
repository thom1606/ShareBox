//
//  Mach.swift
//  ShareBox
//
//  Created by Thom van den Broek on 16/08/2025.
//

import Foundation

class MachMessenger {
    static let shared = MachMessenger()

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
                throw ShareBoxError.appNotRunning
            }
        }

        let messageID: Int32 = 0x1111
        let timeout: CFTimeInterval = 1.0

        var returnData: Unmanaged<CFData>?
        let status = CFMessagePortSendRequest(remote, messageID, message.encode(), timeout, timeout, CFRunLoopMode.defaultMode.rawValue, &returnData)
        if status == kCFMessagePortSuccess, let data = returnData?.takeRetainedValue() as Data? {
            return data
        } else {
            return nil
        }

    }

    private func setup() throws {
        guard let remotePort = CFMessagePortCreateRemote(nil, Constants.Mach.portName as CFString) else {
            generalLogger.error("Failed to connect to the ShareBox Uploader")
            self.remote = nil
            throw ShareBoxError.appNotRunning
        }
        self.remote = remotePort
    }
}

class MachMessage: Codable {
    var type: MessageType
    var data: Data?

    init(type: MessageType, data: Data? = nil) {
        self.type = type
        self.data = data
    }

    enum MessageType: String, Codable {
        case fileUploadRequest
        case peek
    }
}

extension MachMessage {
    public func encode() -> CFData? {
        let encoder = JSONEncoder()
        guard let encodedMessage = try? encoder.encode(self) else {
            return nil
        }
        return encodedMessage as CFData
    }
}

protocol MachData: Codable {}

extension MachData {
    public func encode() -> Data? {
        let encoder = JSONEncoder()
        guard let encodedMessage = try? encoder.encode(self) else {
            return nil
        }
        return encodedMessage
    }
}

struct MachFileUploadBody: MachData {
    var items: [FilePath]
}
