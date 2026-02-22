import Foundation

/// Base client event
public protocol NiimbotEvent: Sendable {
    var type: String { get }
}

/// Fired when client connected to printer
public struct ConnectEvent: NiimbotEvent {
    public let type = "connect"
    public let info: ConnectionInfo

    public init(info: ConnectionInfo) {
        self.info = info
    }
}

/// Fired when client disconnected
public struct DisconnectEvent: NiimbotEvent {
    public let type = "disconnect"
    public init() {}
}

/// Fired when packet received
public struct PacketReceivedEvent: NiimbotEvent {
    public let type = "packetreceived"
    public let packet: NiimbotPacket

    public init(packet: NiimbotPacket) {
        self.packet = packet
    }
}

/// Fired when packet sent
public struct PacketSentEvent: NiimbotEvent {
    public let type = "packetsent"
    public let packet: NiimbotPacket

    public init(packet: NiimbotPacket) {
        self.packet = packet
    }
}

/// Fired when raw packet sent
public struct RawPacketSentEvent: NiimbotEvent {
    public let type = "rawpacketsent"
    public let data: [UInt8]

    public init(data: [UInt8]) {
        self.data = data
    }
}

/// Fired when raw packet received
public struct RawPacketReceivedEvent: NiimbotEvent {
    public let type = "rawpacketreceived"
    public let data: [UInt8]

    public init(data: [UInt8]) {
        self.data = data
    }
}

/// Fired on heartbeat
public struct HeartbeatEvent: NiimbotEvent {
    public let type = "heartbeat"
    public let data: HeartbeatData

    public init(data: HeartbeatData) {
        self.data = data
    }
}

/// Fired when heartbeat fails
public struct HeartbeatFailedEvent: NiimbotEvent {
    public let type = "heartbeatfailed"
    public let failedAttempts: Int

    public init(failedAttempts: Int) {
        self.failedAttempts = failedAttempts
    }
}

/// Fired when printer info fetched
public struct PrinterInfoFetchedEvent: NiimbotEvent {
    public let type = "printerinfofetched"
    public let info: PrinterInfo

    public init(info: PrinterInfo) {
        self.info = info
    }
}

/// Fired on print progress
public struct PrintProgressEvent: NiimbotEvent {
    public let type = "printprogress"
    public let page: Int
    public let pagesTotal: Int
    public let pagePrintProgress: Int
    public let pageFeedProgress: Int

    public init(page: Int, pagesTotal: Int, pagePrintProgress: Int, pageFeedProgress: Int) {
        self.page = page
        self.pagesTotal = pagesTotal
        self.pagePrintProgress = pagePrintProgress
        self.pageFeedProgress = pageFeedProgress
    }
}

/// Fired on firmware progress
public struct FirmwareProgressEvent: NiimbotEvent {
    public let type = "firmwareprogress"
    public let currentChunk: Int
    public let totalChunks: Int

    public init(currentChunk: Int, totalChunks: Int) {
        self.currentChunk = currentChunk
        self.totalChunks = totalChunks
    }
}
