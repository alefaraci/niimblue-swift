import Foundation
import CoreBluetooth

/// BLE transport using CoreBluetooth
public actor BLETransport: NSObject {
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    private var centralManager: CBCentralManager?

    private var address: String = ""
    private var discoveryContinuation: CheckedContinuation<Void, Error>?
    private var bleConnectContinuation: CheckedContinuation<Void, Error>?
    private var subscriptionContinuation: CheckedContinuation<Void, Error>?
    private var dataContinuation: AsyncStream<[UInt8]>.Continuation?

    private var stream: AsyncStream<[UInt8]>!

    public var isConnected: Bool {
        peripheral != nil && characteristic != nil
    }

    public var dataStream: AsyncStream<[UInt8]> {
        stream
    }

    public override init() {
        super.init()
        stream = AsyncStream {[weak self] continuation in
            Task { [weak self] in
                await self?.setDataContinuation(continuation)
            }
        }
    }

    private func setDataContinuation(_ continuation: AsyncStream<[UInt8]>.Continuation) {
        dataContinuation = continuation
    }

    public func setAddress(_ address: String) {
        self.address = address
    }

    public func connect() async throws -> ConnectionInfo {
        if peripheral != nil {
            await disconnect()
        }

        centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)

        // Wait for powered on
        try await waitForPowerOn()

        // Find and connect to peripheral
        try await findAndConnectPeripheral()

        guard let peripheral = peripheral else {
            throw PrintError(message: "Device not found", reasonId: 0)
        }

        let deviceName = peripheral.name ?? address

        return ConnectionInfo(deviceName: deviceName, result: .connected)
    }

    private func waitForPowerOn() async throws {
        guard let cm = centralManager else { return }

        while cm.state != .poweredOn {
            if cm.state == .unauthorized {
                throw PrintError(message: "Bluetooth not authorized", reasonId: 0)
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func findAndConnectPeripheral() async throws {
        guard let cm = centralManager else { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            discoveryContinuation = continuation
            cm.scanForPeripherals(withServices: nil, options: nil)

            // Set timeout
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if discoveryContinuation != nil {
                    cm.stopScan()
                    discoveryContinuation?.resume(throwing: PrintError(message: "Device not found (timeout)", reasonId: 0))
                    discoveryContinuation = nil
                }
            }
        }
    }

    public func disconnect() async {
        centralManager?.stopScan()

        if let peripheral = peripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }

        peripheral = nil
        characteristic = nil
        dataContinuation?.finish()
    }

    public func sendRaw(_ data: [UInt8]) async throws {
        guard let peripheral = peripheral, let characteristic = characteristic else {
            throw PrintError(message: "Not connected", reasonId: 0)
        }

        let dataToSend = Data(data)
        peripheral.writeValue(dataToSend, for: characteristic, type: .withoutResponse)
    }
}

// MARK: - CBCentralManagerDelegate
extension BLETransport: CBCentralManagerDelegate {
    nonisolated public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // State updated
    }

    nonisolated public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task {
            let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""

            // Get the target address from the actor
            let targetAddress = await self.address

            if peripheral.identifier.uuidString.lowercased() == targetAddress.lowercased() ||
               name == targetAddress ||
               peripheral.name == targetAddress {

                central.stopScan()
                await setPeripheral(peripheral, centralManager: central)

                // Resume discovery continuation - device found
                await discoveryContinuation?.resume()
                await clearDiscoveryContinuation()

                // Continue with connection
                do {
                    try await connectToPeripheral()
                } catch {
                    // Connection error will be handled by bleConnectContinuation
                }
            }
        }
    }

    private func setPeripheral(_ peripheral: CBPeripheral, centralManager: CBCentralManager) {
        self.peripheral = peripheral
        self.centralManager = centralManager
    }

    private func clearDiscoveryContinuation() {
        discoveryContinuation = nil
    }

    private func clearBleConnectContinuation() {
        bleConnectContinuation = nil
    }

    private func connectToPeripheral() async throws {
        guard let cm = centralManager, let peripheral = peripheral else { return }

        // Phase 2: Wait for BLE connection
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            bleConnectContinuation = continuation
            peripheral.delegate = self
            cm.connect(peripheral, options: nil)

            // Connection timeout
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if bleConnectContinuation != nil {
                    bleConnectContinuation?.resume(throwing: PrintError(message: "Connection timeout", reasonId: 0))
                    bleConnectContinuation = nil
                }
            }
        }

        // Phase 2: Wait for characteristic discovery and subscription
        // The characteristicContinuation is resumed in setCharacteristic()
        // The subscriptionContinuation is resumed in didUpdateNotificationStateFor
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            subscriptionContinuation = continuation

            // Discovery/subscription timeout
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if subscriptionContinuation != nil {
                    subscriptionContinuation?.resume(throwing: PrintError(message: "Characteristic subscription timeout", reasonId: 0))
                    subscriptionContinuation = nil
                }
            }
        }

        guard characteristic != nil else {
            throw PrintError(message: "Unable to find suitable channel characteristic", reasonId: 0)
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task {
            // Resume BLE connection continuation
            await bleConnectContinuation?.resume()
            await clearBleConnectContinuation()
            // Start service discovery
            peripheral.discoverServices(nil)
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task {
            await handleDisconnect()
        }
    }

    private func handleDisconnect() {
        peripheral = nil
        characteristic = nil
    }
}

// MARK: - CBPeripheralDelegate
extension BLETransport: CBPeripheralDelegate {
    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for char in characteristics {
            if char.properties.contains(.notify) && char.properties.contains(.writeWithoutResponse) {
                Task {
                    await setCharacteristic(char, peripheral: peripheral)
                }
                return
            }
        }
    }

    private func setCharacteristic(_ char: CBCharacteristic, peripheral: CBPeripheral) {
        characteristic = char
        peripheral.setNotifyValue(true, for: char)
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }

        Task {
            await dataContinuation?.yield(Array(data))
        }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        Task {
            // Resume subscription continuation to signal that subscription is complete
            if let error = error {
                await subscriptionContinuation?.resume(throwing: error)
            } else {
                await subscriptionContinuation?.resume()
            }
            await clearSubscriptionContinuation()
        }
    }

    private func clearSubscriptionContinuation() {
        subscriptionContinuation = nil
    }
}

/// BLE scanner
public class BLEScanner: NSObject, TransportScanner {
    public typealias Device = ScannedDevice

    private var centralManager: CBCentralManager?
    private var discoveredDevices: [ScannedDevice] = []

    public override init() {
        super.init()
    }

    public func scan(timeoutMs: Int) async throws -> [ScannedDevice] {
        discoveredDevices = []

        centralManager = CBCentralManager(delegate: self, queue: nil)

        // Wait for powered on
        while centralManager?.state != .poweredOn {
            if centralManager?.state == .unauthorized {
                throw PrintError(message: "Bluetooth not authorized", reasonId: 0)
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        centralManager?.scanForPeripherals(withServices: nil, options: nil)

        try await Task.sleep(nanoseconds: UInt64(timeoutMs) * 1_000_000)

        centralManager?.stopScan()

        return discoveredDevices
    }
}

extension BLEScanner: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {}

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? "unknown"
        let device = ScannedDevice(address: peripheral.identifier.uuidString, name: name)

        // Avoid duplicates
        if !discoveredDevices.contains(where: { $0.address == device.address }) {
            discoveredDevices.append(device)
        }
    }
}
