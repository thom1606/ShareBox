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

class MachMessageListener {
    private var localPort: CFMessagePort?
    private var runLoopSource: CFRunLoopSource?

    public var onUpload: ([FilePath]) -> Void

    init(onUpload: @escaping ([FilePath]) -> Void) {
        self.onUpload = onUpload

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
                        listener.onUpload(res.items)
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

class MachMessage: Codable {
    var type: MessageType
    var data: Data?

    init(type: MessageType, data: Data? = nil) {
        self.type = type
        self.data = data
    }

    enum MessageType: String, Codable {
        case fileUploadRequest
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
