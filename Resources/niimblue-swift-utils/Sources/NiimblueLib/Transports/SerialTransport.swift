import Foundation
import ORSSerial

/// Serial transport using ORSSerialPort
public class SerialTransport: NSObject, @unchecked Sendable {
    private var serialPort: ORSSerialPort?
    private var portPath: String = ""
    private var dataContinuation: AsyncStream<[UInt8]>.Continuation?
    private var _isConnected = false

    private var stream: AsyncStream<[UInt8]>!

    public var dataStream: AsyncStream<[UInt8]> {
        stream
    }

    public var isConnected: Bool {
        _isConnected && serialPort?.isOpen == true
    }

    public override init() {
        super.init()
        stream = AsyncStream {[weak self] continuation in
            self?.dataContinuation = continuation
        }
    }

    public func setPort(_ path: String) {
        self.portPath = path
    }

    public func connect() async throws -> ConnectionInfo {
        if isConnected {
            await disconnect()
        }

        guard let port = ORSSerialPort(path: portPath) else {
            throw PrintError(message: "Failed to create port \(portPath)", reasonId: 0)
        }

        port.baudRate = 115200
        port.delegate = self
        serialPort = port

        port.open()

        // Give it a moment to open
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        guard port.isOpen else {
            throw PrintError(message: "Failed to open port \(portPath)", reasonId: 0)
        }

        _isConnected = true

        return ConnectionInfo(deviceName: "Serial (\(portPath))", result: .connected)
    }

    public func disconnect() async {
        serialPort?.close()
        _isConnected = false
        serialPort = nil
        dataContinuation?.finish()
    }

    public func sendRaw(_ data: [UInt8]) async throws {
        guard let port = serialPort, port.isOpen else {
            throw PrintError(message: "Not connected", reasonId: 0)
        }

        port.send(Data(data))
    }
}

// MARK: - ORSSerialPortDelegate
extension SerialTransport: ORSSerialPortDelegate {
    public func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        dataContinuation?.yield(Array(data))
    }

    public func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        _isConnected = false
        dataContinuation?.finish()
    }

    public func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        _isConnected = false
    }
}

/// Serial port scanner
public class SerialScanner: NSObject, TransportScanner, @unchecked Sendable {
    public typealias Device = ScannedDevice

    public override init() {
        super.init()
    }

    public func scan(timeoutMs: Int) async throws -> [ScannedDevice] {
        let portManager = ORSSerialPortManager.shared()
        let ports = portManager.availablePorts

        return ports.map { port in
            let name = port.name ?? (port.path as NSString).lastPathComponent
            return ScannedDevice(address: port.path, name: name)
        }
    }
}
