import Foundation

/// BLE client implementation
public actor NiimbotBleClient {
    private let client: NiimbotAbstractClient
    private let transport: BLETransport
    private var dataTask: Task<Void, Never>?

    public var isConnected: Bool {
        get async { await transport.isConnected }
    }

    public var abstraction: Abstraction {
        get async { await client.abstraction }
    }

    public var eventStream: AsyncStream<any NiimbotEvent> {
        get async { await client.eventStream }
    }

    public init() {
        self.transport = BLETransport()
        self.client = NiimbotAbstractClient()

        // Set up transport callbacks
        Task {
            await client.initialize()
            await client.setDebug(false)
        }
    }

    public func setAddress(_ address: String) async {
        await transport.setAddress(address)
    }

    public func connect() async throws -> ConnectionInfo {
        // Configure transport callback
        await client.setSendRawImpl { [transport] data in
            try await transport.sendRaw(data)
        }

        await client.setIsConnectedImpl { [transport] in
            await transport.isConnected
        }

        // CONNECT FIRST - before starting to listen for data
        let connectionInfo = try await transport.connect()

        // THEN start listening for data (after connection is established)
        dataTask = Task { [weak self] in
            guard let self = self else { return }
            let stream = await self.transport.dataStream
            for await data in stream {
                await self.client.processRawPacket(data)
            }
        }

        do {
            try await client.initialNegotiate()
            try await client.fetchPrinterInfo()
        } catch {
            print("Unable to fetch printer info: \(error)")
        }

        await client.emit(ConnectEvent(info: connectionInfo))
        await client.startHeartbeat()

        return connectionInfo
    }

    public func disconnect() async throws {
        await client.stopHeartbeat()
        dataTask?.cancel()
        dataTask = nil
        try await transport.disconnect()
        await client.emit(DisconnectEvent())
    }

    public func getPrinterInfo() async -> PrinterInfo {
        await client.getPrinterInfo()
    }

    public func getModelMetadata() async -> PrinterModelMeta? {
        await client.getModelMetadata()
    }

    public func getPrintTaskType() async -> PrintTaskName? {
        await client.getPrintTaskType()
    }

    public func setDebug(_ value: Bool) async {
        await client.setDebug(value)
    }
}

/// Serial client implementation
public actor NiimbotSerialClient {
    private let client: NiimbotAbstractClient
    private let transport: SerialTransport
    private var dataTask: Task<Void, Never>?

    public var isConnected: Bool {
        get async { await transport.isConnected }
    }

    public var abstraction: Abstraction {
        get async { await client.abstraction }
    }

    public var eventStream: AsyncStream<any NiimbotEvent> {
        get async { await client.eventStream }
    }

    public init() {
        self.transport = SerialTransport()
        self.client = NiimbotAbstractClient()

        Task {
            await client.initialize()
        }
    }

    public func setPort(_ path: String) async {
        await transport.setPort(path)
    }

    public func connect() async throws -> ConnectionInfo {
        // Configure transport callback
        await client.setSendRawImpl { [transport] data in
            try await transport.sendRaw(data)
        }

        await client.setIsConnectedImpl { [transport] in
            await transport.isConnected
        }

        // Start listening for data
        dataTask = Task { [weak self] in
            guard let self = self else { return }
            let stream = await self.transport.dataStream
            for await data in stream {
                await self.client.processRawPacket(data)
            }
        }

        let connectionInfo = try await transport.connect()

        do {
            try await client.initialNegotiate()
            try await client.fetchPrinterInfo()
        } catch {
            print("Unable to fetch printer info: \(error)")
        }

        await client.emit(ConnectEvent(info: connectionInfo))
        await client.startHeartbeat()

        return connectionInfo
    }

    public func disconnect() async throws {
        await client.stopHeartbeat()
        dataTask?.cancel()
        dataTask = nil
        try await transport.disconnect()
        await client.emit(DisconnectEvent())
    }

    public func getPrinterInfo() async -> PrinterInfo {
        await client.getPrinterInfo()
    }

    public func getModelMetadata() async -> PrinterModelMeta? {
        await client.getModelMetadata()
    }

    public func getPrintTaskType() async -> PrintTaskName? {
        await client.getPrintTaskType()
    }

    public func setDebug(_ value: Bool) async {
        await client.setDebug(value)
    }
}

// MARK: - Extensions for NiimbotAbstractClient

extension NiimbotAbstractClient {
    public func setSendRawImpl(_ impl: @escaping @Sendable ([UInt8]) async throws -> Void) {
        sendRawImpl = impl
    }

    public func setIsConnectedImpl(_ impl: @escaping @Sendable () async -> Bool) {
        isConnectedImpl = impl
    }
}
