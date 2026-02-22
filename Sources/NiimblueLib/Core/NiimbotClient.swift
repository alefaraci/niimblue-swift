import Foundation

public enum ConnectionState {
    case disconnected
    case connecting
    case connected
}

public protocol NiimbotClientDelegate: AnyObject {
    @MainActor func client(_ client: NiimbotClient, didConnectTo deviceName: String)
    @MainActor func clientDidDisconnect(_ client: NiimbotClient)
    @MainActor func client(_ client: NiimbotClient, didFailToConnect error: Error)
}

@MainActor
public class NiimbotClient: TransportDelegate {
    private let transport: Transport
    public weak var delegate: NiimbotClientDelegate?

    public private(set) var connectionState: ConnectionState = .disconnected
    private let packetParser = PacketParser()

    private struct PendingRequest {
        let ids: [ResponseCommandId]
        let continuation: CheckedContinuation<NiimbotPacket, Error>
        var timeoutTask: Task<Void, Error>?
    }

    private var pendingRequests: [PendingRequest] = []

    /// Continuation for connect() to wait until initialNegotiate() completes.
    private var connectContinuation: CheckedContinuation<Void, Error>?

    public init(transport: Transport) {
        self.transport = transport
        self.transport.delegate = self
    }

    public func connect() async throws {
        connectionState = .connecting
        try await transport.connect()

        // Wait for initialNegotiate() to complete (triggered by transportDidConnect)
        try await withCheckedThrowingContinuation { continuation in
            self.connectContinuation = continuation
        }
    }

    public func disconnect() async throws {
        try await transport.disconnect()
    }

    public func transportDidConnect(_ transport: Transport) {
        Task {
            do {
                try await initialNegotiate()
                connectionState = .connected

                if let continuation = self.connectContinuation {
                    continuation.resume()
                    self.connectContinuation = nil
                }

                delegate?.client(self, didConnectTo: "Device")
            } catch {
                if let continuation = self.connectContinuation {
                    continuation.resume(throwing: error)
                    self.connectContinuation = nil
                }

                delegate?.client(self, didFailToConnect: error)
                try? await disconnect()
            }
        }
    }

    public func transportDidDisconnect(_ transport: Transport) {
        connectionState = .disconnected

        pendingRequests.forEach {
            $0.timeoutTask?.cancel()
            $0.continuation.resume(throwing: NSError(domain: "NiimbotClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Disconnected"]))
        }
        pendingRequests.removeAll()

        if let continuation = self.connectContinuation {
            continuation.resume(throwing: NSError(domain: "NiimbotClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Disconnected"]))
            self.connectContinuation = nil
        }

        delegate?.clientDidDisconnect(self)
    }

    public func transport(_ transport: Transport, didReceive data: [UInt8]) {
        let packets = packetParser.append(data)

        for packet in packets {
            handlePacket(packet)
        }
    }

    private func handlePacket(_ packet: NiimbotPacket) {
        guard let responseId = ResponseCommandId(rawValue: packet.command) else {
            Swift.print("Unknown response command: \(packet.command)")
            return
        }

        if let index = pendingRequests.firstIndex(where: { $0.ids.contains(responseId) }) {
            let req = pendingRequests.remove(at: index)
            req.timeoutTask?.cancel()
            req.continuation.resume(returning: packet)
        }
    }

    // ...

    private func initialNegotiate() async throws {
        let packet = PacketGenerator.connect()
        _ = try await send(packet)

        let infoPacket = PacketGenerator.printerInfo(type: 1)
        _ = try await send(infoPacket)
    }

    public func print(image: EncodedImage, quantity: Int = 1, density: Int = 2, labelType: Int = 1) async throws {
        // Init
        _ = try await send(PacketGenerator.setDensity(value: UInt8(density)))
        _ = try await send(PacketGenerator.setLabelType(value: UInt8(labelType)))

        // Use printStart7b for B1 compatibility (and likely others)
        _ = try await send(PacketGenerator.printStart7b(total: UInt16(quantity)))

        // Page Start
        _ = try await send(PacketGenerator.pageStart())

        // Use setPageSize6b for B1 compatibility
        _ = try await send(PacketGenerator.setPageSize6b(rows: UInt16(image.rows), cols: UInt16(image.cols), copies: UInt16(quantity)))

        // Image data chunks
        for row in image.rowsData {
            if row.dataType == .pixels, let data = row.rowData {
                let packet = PacketGenerator.printBitmapRow(pos: UInt16(row.rowNumber), repeats: UInt8(row.repeatCount), data: data, printheadPixels: image.cols)
                _ = try await send(packet)
            } else if row.dataType == .void {
                let packet = PacketGenerator.printEmptyRow(pos: UInt16(row.rowNumber), repeats: UInt8(row.repeatCount))
                _ = try await send(packet)
            }
        }

        _ = try await send(PacketGenerator.pageEnd())

        // Poll PrintStatus until the printer reports completion
        for _ in 0..<100 { // Safety cap: 100 iterations × 300ms = 30s max
            try await Task.sleep(nanoseconds: 300_000_000) // 300ms

            if let response = try await send(PacketGenerator.printStatus()) {
                let data = response.data
                if data.count >= 4 {
                    let page = (UInt16(data[0]) << 8) | UInt16(data[1])
                    let printProgress = data[2]
                    let feedProgress = data[3]
                    Swift.print("Print status: page=\(page)/\(quantity), print=\(printProgress)%, feed=\(feedProgress)%")
                    if page >= UInt16(quantity) && printProgress == 100 && feedProgress == 100 {
                        break
                    }
                }
            }
        }

        _ = try await send(PacketGenerator.printEnd())
    }

    @discardableResult
    public func send(_ packet: NiimbotPacket) async throws -> NiimbotPacket? {
        Swift.print("TX: CMD \(packet.command) Data: \(Utils.bufToHex(packet.data))")

        guard let reqId = RequestCommandId(rawValue: packet.command) else {
            throw NSError(domain: "NiimbotClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid command ID"])
        }

        // Throttling: Sleep to prevent flooding the printer (especially for BLE writeWithoutResponse)
        try await Task.sleep(nanoseconds: 20_000_000) // 20ms

        let respIds = CommandsMap.requestToResponse[reqId] ?? nil

        if let respIds = respIds {
            return try await withCheckedThrowingContinuation { continuation in
                var pending = PendingRequest(ids: respIds, continuation: continuation)

                // Timeout task: if no response within 5s, resume with error
                let timeoutTask = Task {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    if let idx = self.pendingRequests.firstIndex(where: { $0.ids == respIds }) {
                        self.pendingRequests.remove(at: idx)
                        continuation.resume(throwing: NSError(domain: "NiimbotClient", code: -3, userInfo: [NSLocalizedDescriptionKey: "Response timeout"]))
                    }
                }

                pending.timeoutTask = timeoutTask
                pendingRequests.append(pending)

                Task {
                    do {
                        try await self.transport.send(data: packet.toBytes())
                    } catch {
                        timeoutTask.cancel()
                        if let idx = self.pendingRequests.firstIndex(where: { $0.ids == respIds }) {
                             self.pendingRequests.remove(at: idx)
                             continuation.resume(throwing: error)
                        }
                    }
                }
            }
        } else {
            try await transport.send(data: packet.toBytes())
            return nil
        }
    }
}
