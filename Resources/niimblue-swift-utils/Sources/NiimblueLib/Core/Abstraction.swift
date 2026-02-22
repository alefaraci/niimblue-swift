import Foundation

/// Protocol for client abstraction needs
public protocol NiimbotClientProtocol: Actor {
    var eventStream: AsyncStream<any NiimbotEvent> { get async }
    func emit(_ event: any NiimbotEvent)
    func sendPacketWaitResponse(_ packet: NiimbotPacket, timeoutMs: Int) async throws -> NiimbotPacket
    func getPrinterInfo() -> PrinterInfo
}

/// Sequential data reader for packet parsing
public class SequentialDataReader {
    private var data: [UInt8]
    private var pos: Int = 0

    public init(_ data: [UInt8]) {
        self.data = data
    }

    public func readBytes(_ count: Int) -> [UInt8] {
        let result = Array(data[pos..<min(pos + count, data.count)])
        pos += count
        return result
    }

    public func readI8() -> UInt8 {
        defer { pos += 1 }
        return data[pos]
    }

    public func readI16() -> Int {
        defer { pos += 2 }
        return Int(Utils.bytesToI16(Array(data[pos..<(pos + 2)])))
    }

    public func readBool() -> Bool {
        readI8() != 0
    }

    public func readVString() -> String {
        let len = Int(readI8())
        let bytes = readBytes(len)
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }

    public func skip(_ count: Int) {
        pos += count
    }

    public func canRead(_ count: Int) -> Bool {
        pos + count <= data.count
    }

    public func end() {}
}

/// Packet sender and parser
public actor Abstraction {
    private let DEFAULT_PACKET_TIMEOUT: Int = 1000
    private var packetTimeout: Int
    private weak var client: NiimbotAbstractClient?
    private var statusPollTimer: Task<Void, Error>?
    private var statusTimeoutTimer: Task<Void, Never>?

    public init() {
        self.packetTimeout = DEFAULT_PACKET_TIMEOUT
        self.client = nil
    }

    public func setClient(_ client: NiimbotAbstractClient) {
        self.client = client
    }

    public func getClient() -> NiimbotAbstractClient? {
        client
    }

    public func getPacketTimeout() -> Int {
        packetTimeout
    }

    public func setPacketTimeout(_ value: Int) {
        packetTimeout = value
    }

    public func setDefaultPacketTimeout() {
        packetTimeout = DEFAULT_PACKET_TIMEOUT
    }

    /// Send packet and wait for response
    public func send(_ packet: NiimbotPacket, timeout: Int? = nil) async throws -> NiimbotPacket {
        guard let client = client else {
            throw PrintError(message: "Client not set", reasonId: 0)
        }
        return try await client.sendPacketWaitResponse(packet, timeoutMs: timeout ?? packetTimeout)
    }

    /// Send packet, wait for response, repeat if failed
    public func sendRepeatUntilSuccess(_ packet: NiimbotPacket, attempts: Int, timeout: Int? = nil) async throws -> NiimbotPacket {
        var lastError: Error = PrintError(message: "Unknown error", reasonId: 0)

        for _ in 0..<attempts {
            do {
                return try await send(packet, timeout: timeout)
            } catch {
                lastError = error
            }
        }

        throw lastError
    }

    /// Send all packets
    public func sendAll(_ packets: [NiimbotPacket], timeoutMs: Int? = nil) async throws {
        for packet in packets {
            _ = try await send(packet, timeout: timeoutMs)
        }
    }

    /// Get print status
    public func getPrintStatus(tries: Int = 1) async throws -> PrintStatus {
        let packet = try await sendRepeatUntilSuccess(PacketGenerator.printStatus(), attempts: tries)

        guard packet.data.count >= 4 else {
            throw PrintError(message: "Invalid print status data length", reasonId: 0)
        }

        let r = SequentialDataReader(packet.data)
        let page = r.readI16()
        let pagePrintProgress = Int(r.readI8())
        let pageFeedProgress = Int(r.readI8())

        if packet.data.count == 10 {
            r.skip(2)
            let error = r.readI8()
            if error != 0 {
                throw PrintError(message: "Print error (status packet flag)", reasonId: error)
            }
        }

        return PrintStatus(page: page, pagePrintProgress: pagePrintProgress, pageFeedProgress: pageFeedProgress)
    }

    /// Get connect result
    public func connectResult() async throws -> ConnectResult {
        let packet = try await send(PacketGenerator.connect())
        guard packet.data.count >= 1 else {
            throw PrintError(message: "Invalid connect response", reasonId: 0)
        }
        return ConnectResult(rawValue: packet.data[0]) ?? .firmwareErrors
    }

    /// Get printer status data
    public func getPrinterStatusData() async throws -> PrinterStatusData {
        let packet = try await send(PacketGenerator.getPrinterStatusData())

        var protocolVersion = 0
        var supportColor = 0

        if packet.data.count > 12 {
            supportColor = Int(packet.data[10])
            let n = Int(packet.data[11]) * 100 + Int(packet.data[12])

            if n >= 204 && n < 300 {
                protocolVersion = 3
            } else if n < 300 || n >= 302 {
                protocolVersion = n >= 302 ? 5 : 0
            } else {
                protocolVersion = 4
            }
        }

        return PrinterStatusData(supportColor: supportColor, protocolVersion: protocolVersion)
    }

    /// Get printer model
    public func getPrinterModel() async throws -> Int {
        let packet = try await send(PacketGenerator.getPrinterInfo(.printerModelId))

        guard packet.data.count >= 1 else {
            throw PrintError(message: "Invalid printer model response", reasonId: 0)
        }

        if packet.data.count == 1 {
            return Int(packet.data[0]) << 8
        }

        return Int(Utils.bytesToI16(Array(packet.data[0..<2])))
    }

    /// Get RFID info
    public func rfidInfo() async throws -> RfidInfo {
        let packet = try await send(PacketGenerator.rfidInfo())
        return processRfidInfo(packet)
    }

    /// Get RFID info 2
    public func rfidInfo2() async throws -> RfidInfo {
        let packet = try await send(PacketGenerator.rfidInfo2())
        return processRfidInfo(packet)
    }

    private func processRfidInfo(_ packet: NiimbotPacket) -> RfidInfo {
        var info = RfidInfo()

        if packet.data.count == 1 {
            return info
        }

        let r = SequentialDataReader(packet.data)
        info.tagPresent = true
        info.uuid = Utils.bufToHex(r.readBytes(8), separator: "")
        info.barCode = r.readVString()
        info.serialNumber = r.readVString()
        info.allPaper = r.readI16()
        info.usedPaper = r.readI16()
        info.consumablesType = LabelType(rawValue: r.readI8()) ?? .invalid

        if r.canRead(2) {
            info.capacity = r.readI16()
        }

        return info
    }

    /// Send heartbeat
    public func heartbeat() async throws -> HeartbeatData {
        let packet = try await send(PacketGenerator.heartbeat(.advanced1), timeout: 500)

        var info = HeartbeatData()
        let len = packet.data.count
        let r = SequentialDataReader(packet.data)

        switch len {
        case 10: // D110
            r.skip(8)
            info.lidClosed = r.readBool()
            info.powerLevel = BatteryChargeLevel(rawValue: r.readI8()) ?? .charge0
        case 20:
            r.skip(18)
            info.paperState = Int(r.readI8())
            info.rfidReadState = Int(r.readI8())
        case 19:
            r.skip(15)
            info.lidClosed = r.readBool()
            info.powerLevel = BatteryChargeLevel(rawValue: r.readI8()) ?? .charge0
            info.paperState = Int(r.readI8())
            info.rfidReadState = Int(r.readI8())
        case 13: // B1
            r.skip(9)
            info.lidClosed = r.readBool()
            info.powerLevel = BatteryChargeLevel(rawValue: r.readI8()) ?? .charge0
            info.paperState = Int(r.readI8())
            info.rfidReadState = Int(r.readI8())
        default:
            throw PrintError(message: "Invalid heartbeat length: \(len)", reasonId: 0)
        }

        // Some models have inverted lidClosed
        if let client = client {
            let modelId = await client.getPrinterInfo().modelId
            if let modelId = modelId {
                let invertedModels: [Int] = [512, 514, 513, 2304, 1792, 3584, 5120, 2560, 3840, 4352, 272]
                if !invertedModels.contains(modelId) {
                    info.lidClosed = !info.lidClosed
                }
            }
        }

        return info
    }

    /// Get battery charge level
    public func getBatteryChargeLevel() async throws -> BatteryChargeLevel {
        let packet = try await send(PacketGenerator.getPrinterInfo(.batteryChargeLevel))
        guard packet.data.count == 1 else {
            throw PrintError(message: "Invalid battery level response", reasonId: 0)
        }
        return BatteryChargeLevel(rawValue: packet.data[0]) ?? .charge0
    }

    /// Get auto shutdown time
    public func getAutoShutDownTime() async throws -> AutoShutdownTime {
        let packet = try await send(PacketGenerator.getPrinterInfo(.autoShutdownTime))
        guard packet.data.count == 1 else {
            throw PrintError(message: "Invalid auto shutdown time response", reasonId: 0)
        }
        return AutoShutdownTime(rawValue: packet.data[0]) ?? .shutdownTime1
    }

    /// Get software version
    public func getSoftwareVersion() async throws -> String {
        let packet = try await send(PacketGenerator.getPrinterInfo(.softWareVersion))
        guard packet.data.count == 2 else {
            throw PrintError(message: "Invalid software version response", reasonId: 0)
        }
        let v1 = Double(packet.data[1]) / 100.0 + Double(packet.data[0])
        let v2 = Double(Int(packet.data[0]) * 256 + Int(packet.data[1])) / 100.0
        return "0x\(Utils.bufToHex(packet.data, separator: "")) (\(String(format: "%.2f", v1)) or \(String(format: "%.2f", v2)))"
    }

    /// Get hardware version
    public func getHardwareVersion() async throws -> String {
        let packet = try await send(PacketGenerator.getPrinterInfo(.hardWareVersion))
        guard packet.data.count == 2 else {
            throw PrintError(message: "Invalid hardware version response", reasonId: 0)
        }
        let v1 = Double(packet.data[1]) / 100.0 + Double(packet.data[0])
        let v2 = Double(Int(packet.data[0]) * 256 + Int(packet.data[1])) / 100.0
        return "0x\(Utils.bufToHex(packet.data, separator: "")) (\(String(format: "%.2f", v1)) or \(String(format: "%.2f", v2)))"
    }

    /// Set auto shutdown time
    public func setAutoShutDownTime(_ time: AutoShutdownTime) async throws {
        _ = try await send(PacketGenerator.setAutoShutDownTime(time))
    }

    /// Get label type
    public func getLabelType() async throws -> LabelType {
        let packet = try await send(PacketGenerator.getPrinterInfo(.labelType))
        guard packet.data.count == 1 else {
            throw PrintError(message: "Invalid label type response", reasonId: 0)
        }
        return LabelType(rawValue: packet.data[0]) ?? .invalid
    }

    /// Get printer serial number
    public func getPrinterSerialNumber() async throws -> String {
        let packet = try await send(PacketGenerator.getPrinterInfo(.serialNumber))

        guard packet.data.count >= 1 else {
            return "-1"
        }

        if packet.data.count >= 8 {
            return String(bytes: packet.data, encoding: .utf8) ?? "-1"
        }

        return Utils.bufToHex(Array(packet.data[0..<4]), separator: "").uppercased()
    }

    /// Get printer Bluetooth MAC address
    public func getPrinterBluetoothMacAddress() async throws -> String {
        let packet = try await send(PacketGenerator.getPrinterInfo(.bluetoothAddress))
        guard packet.data.count >= 1 else {
            throw PrintError(message: "Invalid MAC address response", reasonId: 0)
        }
        return Utils.bufToHex(packet.data.reversed(), separator: ":")
    }

    /// Reset printer
    public func printerReset() async throws {
        _ = try await send(PacketGenerator.printerReset())
    }

    /// Wait until print finished by page index
    public func waitUntilPrintFinishedByPageIndex(_ pagesToPrint: Int, timeoutMs: Int = 5000) async throws {
        guard let client = client else {
            throw PrintError(message: "Client not set", reasonId: 0)
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var hasFinished = false

            // Set up timeout
            Task { @Sendable in
                try? await Task.sleep(nanoseconds: UInt64(timeoutMs) * 1_000_000)
                if !hasFinished {
                    hasFinished = true
                    continuation.resume(throwing: PrintError(message: "Timeout waiting print status", reasonId: 0))
                }
            }

            // Listen for packet
            Task {
                for await event in await client.eventStream {
                    if hasFinished { return }
                    if let packetEvent = event as? PacketReceivedEvent {
                        if packetEvent.packet.command == ResponseCommandId.inPrinterPageIndex.rawValue {
                            guard packetEvent.packet.data.count == 2 else { continue }
                            let page = Utils.bytesToI16(Array(packetEvent.packet.data[0..<2]))

                            await client.emit(PrintProgressEvent(page: Int(page), pagesTotal: pagesToPrint, pagePrintProgress: 100, pageFeedProgress: 100))

                            if page == pagesToPrint && !hasFinished {
                                hasFinished = true
                                continuation.resume()
                                return
                            }
                        }
                    }
                }
            }
        }
    }

    /// Wait until print finished by status poll
    public func waitUntilPrintFinishedByStatusPoll(_ pagesToPrint: Int, pollIntervalMs: Int = 300) async throws {
        guard let client = client else {
            throw PrintError(message: "Client not set", reasonId: 0)
        }

        await client.emit(PrintProgressEvent(page: 1, pagesTotal: pagesToPrint, pagePrintProgress: 0, pageFeedProgress: 0))

        while true {
            do {
                let status = try await getPrintStatus(tries: 2)
                await client.emit(PrintProgressEvent(
                    page: status.page,
                    pagesTotal: pagesToPrint,
                    pagePrintProgress: status.pagePrintProgress,
                    pageFeedProgress: status.pageFeedProgress
                ))

                if status.page == pagesToPrint && status.pagePrintProgress == 100 && status.pageFeedProgress == 100 {
                    return
                }
            } catch {
                throw error
            }

            try? await Task.sleep(nanoseconds: UInt64(pollIntervalMs) * 1_000_000)
        }
    }

    /// Print end
    public func printEnd() async throws -> Bool {
        let response = try await send(PacketGenerator.printEnd())
        guard response.data.count == 1 else {
            throw PrintError(message: "Invalid print end response", reasonId: 0)
        }
        return response.data[0] == 1
    }

    /// Create new print task
    public func newPrintTask(_ name: PrintTaskName, options: PrintOptions = PrintOptions()) -> any AbstractPrintTask {
        switch name {
        case .b1:
            return B1PrintTask(abstraction: self, options: options)
        case .d110, .oldD11, .d110Mv4:
            return D110PrintTask(abstraction: self, options: options)
        case .b21:
            return B1PrintTask(abstraction: self, options: options)
        }
    }
}
