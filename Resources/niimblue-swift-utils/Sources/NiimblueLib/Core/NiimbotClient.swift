import Foundation

/// Abstract client for communicating with Niimbot printers
public actor NiimbotAbstractClient {
    public let abstraction: Abstraction
    private var info: PrinterInfo = PrinterInfo()
    private var heartbeatTimer: Task<Void, Error>?
    private var heartbeatFails: Int = 0
    private var heartbeatIntervalMs: Int = 2000
    private var debug: Bool = false
    private var packetBuf: [UInt8] = []
    private var packetIntervalMs: Int = 10

    private var eventContinuation: AsyncStream<any NiimbotEvent>.Continuation?
    public lazy var eventStream: AsyncStream<any NiimbotEvent> = {
        AsyncStream { continuation in
            eventContinuation = continuation
        }
    }()

    private var waitingPackets: [WaitingPacket] = []

    // Transport closure - set by subclasses
    public var sendRawImpl: (@Sendable ([UInt8]) async throws -> Void)?
    public var isConnectedImpl: (@Sendable () async -> Bool)?

    public init() {
        self.abstraction = Abstraction()
    }

    /// Called after init to set up the bidirectional reference
    public func initialize() async {
        await abstraction.setClient(self)
    }

    /// Check if connected
    public var isConnected: Bool {
        get async {
            await isConnectedImpl?() ?? false
        }
    }

    /// Send raw data
    public func sendRaw(_ data: [UInt8]) async throws {
        guard let impl = sendRawImpl else {
            throw PrintError(message: "Transport not configured", reasonId: 0)
        }

        // Add packet interval delay (matching Node.js behavior - prevents flooding printer)
        try await Task.sleep(nanoseconds: UInt64(packetIntervalMs) * 1_000_000)

        try await impl(data)
    }

    /// Connect to printer
    public func connect() async throws -> ConnectionInfo {
        fatalError("Must be implemented by subclass")
    }

    /// Disconnect from printer
    public func disconnect() async throws {
        stopHeartbeat()
        packetBuf = []
    }

    /// Emit event
    public func emit(_ event: any NiimbotEvent) {
        eventContinuation?.yield(event)
    }

    /// Send packet and wait for response
    public func sendPacketWaitResponse(_ packet: NiimbotPacket, timeoutMs: Int = 1000) async throws -> NiimbotPacket {
        try await sendPacket(packet, force: true)

        if packet.oneWay {
            return NiimbotPacket(command: ResponseCommandId.inInvalid.rawValue, data: [])
        }

        let ids = packet.validResponseIds?.map { $0.rawValue } ?? []
        return try await waitForPacket(ids: ids, catchErrorPackets: true, timeoutMs: timeoutMs)
    }

    /// Wait for packet with specific command IDs
    public func waitForPacket(ids: [Int] = [], catchErrorPackets: Bool = true, timeoutMs: Int = 1000) async throws -> NiimbotPacket {
        let waitingPacket = WaitingPacket(ids: ids, catchErrorPackets: catchErrorPackets)
        waitingPackets.append(waitingPacket)

        // Set up timeout
        Task { @Sendable [weak self, packetId = waitingPacket.id] in
            try? await Task.sleep(nanoseconds: UInt64(timeoutMs) * 1_000_000)
            await self?.handleTimeout(for: packetId)
        }

        return try await waitingPacket.wait()
    }

    private func handleTimeout(for packetId: UUID) async {
        if let idx = waitingPackets.firstIndex(where: { $0.id == packetId }) {
            let packet = waitingPackets.remove(at: idx)
            packet.fail(PrintError(message: "Timeout waiting response", reasonId: 0))
        }
    }

    /// Process raw packet data
    public func processRawPacket(_ data: [UInt8]) {
        guard !data.isEmpty else { return }

        packetBuf.append(contentsOf: data)

        // Check for valid head
        if packetBuf.count > 1 && !Utils.hasSubarrayAtPos(packetBuf, NiimbotPacket.head, 0) {
            if debug { print("Dropping invalid buffer: \(Utils.bufToHex(packetBuf))") }
            packetBuf = []
            return
        }

        do {
            let packets = try PacketParser.parsePacketBundle(packetBuf)
            if !packets.isEmpty {
                emit(RawPacketReceivedEvent(data: packetBuf))

                for p in packets {
                    emit(PacketReceivedEvent(packet: p))
                    handleReceivedPacket(p)
                }

                packetBuf = []
            }
        } catch {
            if debug { print("Incomplete packet, ignoring: \(Utils.bufToHex(packetBuf))") }
        }
    }

    private func handleReceivedPacket(_ packet: NiimbotPacket) {
        let cmd = packet.command

        // Check for error packets
        if cmd == ResponseCommandId.inPrintError.rawValue {
            let errorId = packet.data.first ?? 0
            let errorMsg = PrinterErrorCode(rawValue: errorId)?.description ?? "unknown"
            let error = PrintError(message: "Print error \(errorId): \(errorMsg)", reasonId: errorId)

            // Fail all waiting packets that catch errors
            for waiting in waitingPackets where waiting.catchErrorPackets {
                waiting.fail(error)
            }
            waitingPackets.removeAll { $0.catchErrorPackets }
            return
        }

        if cmd == ResponseCommandId.inNotSupported.rawValue {
            let error = PrintError(message: "Feature not supported", reasonId: 0)

            for waiting in waitingPackets where waiting.catchErrorPackets {
                waiting.fail(error)
            }
            waitingPackets.removeAll { $0.catchErrorPackets }
            return
        }

        // Try to match with waiting packets
        for i in waitingPackets.indices.reversed() {
            let waiting = waitingPackets[i]
            if waiting.ids.isEmpty || waiting.ids.contains(cmd) {
                waitingPackets.remove(at: i)
                waiting.complete(packet)
                return
            }
        }
    }

    /// Send packet
    public func sendPacket(_ packet: NiimbotPacket, force: Bool = false) async throws {
        try await sendRaw(packet.toBytes())
        emit(PacketSentEvent(packet: packet))
    }

    /// Initial negotiation
    public func initialNegotiate() async throws {
        var cfg = info
        cfg.connectResult = try await abstraction.connectResult()
        cfg.protocolVersion = 0

        if cfg.connectResult == .connectedNew {
            cfg.protocolVersion = 1
        } else if cfg.connectResult == .connectedV3 {
            let statusData = try await abstraction.getPrinterStatusData()
            cfg.protocolVersion = statusData.protocolVersion
        }

        info = cfg
    }

    /// Fetch printer info
    public func fetchPrinterInfo() async throws -> PrinterInfo {
        info.modelId = try? await abstraction.getPrinterModel()
        info.serial = try? await abstraction.getPrinterSerialNumber()
        info.mac = try? await abstraction.getPrinterBluetoothMacAddress()
        info.charge = try? await abstraction.getBatteryChargeLevel()
        info.autoShutdownTime = try? await abstraction.getAutoShutDownTime()
        info.labelType = try? await abstraction.getLabelType()
        info.hardwareVersion = try? await abstraction.getHardwareVersion()
        info.softwareVersion = try? await abstraction.getSoftwareVersion()

        emit(PrinterInfoFetchedEvent(info: info))
        return info
    }

    /// Get printer info
    public func getPrinterInfo() -> PrinterInfo {
        info
    }

    /// Set heartbeat interval
    public func setHeartbeatInterval(_ intervalMs: Int) {
        heartbeatIntervalMs = intervalMs
    }

    /// Start heartbeat
    public func startHeartbeat() {
        heartbeatFails = 0
        stopHeartbeat()

        heartbeatTimer = Task {
            while !Task.isCancelled {
                do {
                    let data = try await abstraction.heartbeat()
                    heartbeatFails = 0
                    emit(HeartbeatEvent(data: data))
                } catch {
                    heartbeatFails += 1
                    emit(HeartbeatFailedEvent(failedAttempts: heartbeatFails))
                }
                try? await Task.sleep(nanoseconds: UInt64(heartbeatIntervalMs) * 1_000_000)
            }
        }
    }

    /// Stop heartbeat
    public func stopHeartbeat() {
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
    }

    /// Check if heartbeat is started
    public func isHeartbeatStarted() -> Bool {
        heartbeatTimer != nil
    }

    /// Get model metadata
    public func getModelMetadata() -> PrinterModelMeta? {
        guard let modelId = info.modelId else { return nil }
        return getPrinterMetaById(modelId)
    }

    /// Get print task type
    public func getPrintTaskType() -> PrintTaskName? {
        guard let meta = getModelMetadata() else { return nil }
        return findPrintTask(meta.model, info.protocolVersion)
    }

    /// Set packet interval
    public func setPacketInterval(_ milliseconds: Int) {
        packetIntervalMs = milliseconds
    }

    /// Set debug mode
    public func setDebug(_ value: Bool) {
        debug = value
    }
}

/// Helper class for waiting packets
private final class WaitingPacket: @unchecked Sendable {
    let id = UUID()
    let ids: [Int]
    let catchErrorPackets: Bool
    private var continuation: CheckedContinuation<NiimbotPacket, Error>?

    init(ids: [Int], catchErrorPackets: Bool) {
        self.ids = ids
        self.catchErrorPackets = catchErrorPackets
    }

    func wait() async throws -> NiimbotPacket {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func complete(_ packet: NiimbotPacket) {
        continuation?.resume(returning: packet)
    }

    func fail(_ error: Error) {
        continuation?.resume(throwing: error)
    }
}
