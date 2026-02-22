import Foundation
@preconcurrency import CoreBluetooth

@MainActor
public class BLETransport: NSObject, Transport, CBCentralManagerDelegate, CBPeripheralDelegate {
    public weak var delegate: TransportDelegate?

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?

    private var deviceNameOrAddress: String?
    private var found = false
    private var didConnect = false
    private var connectionContinuation: CheckedContinuation<Void, Error>?
    private var readyContinuation: CheckedContinuation<Void, Error>?
    private var scanCallback: ((CBPeripheral, String?, NSNumber) -> Void)?

    /// Queue of continuations waiting for writeWithoutResponse readiness.
    private var writeContinuations: [CheckedContinuation<Void, Never>] = []

    public init(deviceNameOrAddress: String? = nil) {
        self.deviceNameOrAddress = deviceNameOrAddress
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    private func waitForReady() async throws {
        if centralManager.state == .poweredOn { return }

        if centralManager.state == .unauthorized {
             throw NSError(domain: "BLETransport", code: -2, userInfo: [NSLocalizedDescriptionKey: "Bluetooth unauthorized"])
        }

        if centralManager.state == .poweredOff {
             // Wait for it to turn on?
        }

        return try await withCheckedThrowingContinuation { continuation in
            if self.readyContinuation != nil {
                 continuation.resume(throwing: NSError(domain: "BLETransport", code: -6, userInfo: [NSLocalizedDescriptionKey: "Busy waiting for state"]))
                 return
            }
            self.readyContinuation = continuation
        }
    }

    public func scan(duration: TimeInterval, callback: @escaping (CBPeripheral, String?, NSNumber) -> Void) async throws {
        self.scanCallback = callback

        try await waitForReady()

        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])

        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        centralManager.stopScan()
        self.scanCallback = nil
    }

    public func connect() async throws {
        guard self.deviceNameOrAddress != nil else {
            throw NSError(domain: "BLETransport", code: -5, userInfo: [NSLocalizedDescriptionKey: "Device address not set"])
        }

        self.didConnect = false

        return try await withCheckedThrowingContinuation { continuation in
            self.connectionContinuation = continuation
            self.found = false

            if centralManager.state == .poweredOn {
                startScan()
            }
        }
    }

    public func disconnect() async throws {
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    public func send(data: [UInt8]) async throws {
        guard let peripheral = peripheral, let characteristic = characteristic else {
            throw NSError(domain: "BLETransport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not connected"])
        }

        let data = Data(data)
        let type: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse

        if type == .withoutResponse {
            // Wait until the peripheral is ready to accept a writeWithoutResponse
            if !peripheral.canSendWriteWithoutResponse {
                await withCheckedContinuation { continuation in
                    self.writeContinuations.append(continuation)
                }
            }
        }

        peripheral.writeValue(data, for: characteristic, type: type)
    }

    private func startScan() {
        centralManager.scanForPeripherals(withServices: nil, options: nil)

        // Use Task instead of DispatchQueue to stay in actor context
        Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            if !self.found {
                self.centralManager.stopScan()
                if let continuation = self.connectionContinuation {
                    continuation.resume(throwing: NSError(domain: "BLETransport", code: -3, userInfo: [NSLocalizedDescriptionKey: "Device not found"]))
                    self.connectionContinuation = nil
                }
            }
        }
    }

    // MARK: - CBCentralManagerDelegate

    nonisolated public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            if central.state == .poweredOn {
                self.readyContinuation?.resume()
                self.readyContinuation = nil

                if self.connectionContinuation != nil && !self.found {
                    self.startScan()
                }
            } else if central.state == .poweredOff || central.state == .unauthorized {
                 if let continuation = self.connectionContinuation {
                     continuation.resume(throwing: NSError(domain: "BLETransport", code: -2, userInfo: [NSLocalizedDescriptionKey: "Bluetooth unavailable"]))
                     self.connectionContinuation = nil
                 }

                 if let continuation = self.readyContinuation {
                     continuation.resume(throwing: NSError(domain: "BLETransport", code: -2, userInfo: [NSLocalizedDescriptionKey: "Bluetooth unavailable"]))
                     self.readyContinuation = nil
                 }
            }
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String

        MainActor.assumeIsolated {
            self.scanCallback?(peripheral, localName, RSSI)

            guard let deviceNameOrAddress = self.deviceNameOrAddress else { return }

            let name = peripheral.name ?? localName ?? ""

            if name == deviceNameOrAddress || peripheral.identifier.uuidString == deviceNameOrAddress {
                self.found = true
                self.peripheral = peripheral
                self.centralManager.stopScan()
                self.centralManager.connect(peripheral, options: nil)
            }
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated {
            peripheral.delegate = self
            peripheral.discoverServices(nil)
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
         MainActor.assumeIsolated {
             if let continuation = self.connectionContinuation {
                 continuation.resume(throwing: error ?? NSError(domain: "BLETransport", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to connect"]))
                 self.connectionContinuation = nil
             }
         }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            self.peripheral = nil
            self.characteristic = nil
            self.didConnect = false
            self.delegate?.transportDidDisconnect(self)
        }
    }

    // MARK: - CBPeripheralDelegate

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        MainActor.assumeIsolated {
            guard let services = peripheral.services else { return }

            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        MainActor.assumeIsolated {
            // Guard against multiple services triggering this callback
            guard !self.didConnect else { return }
            guard let characteristics = service.characteristics else { return }

            for characteristic in characteristics {
                if characteristic.properties.contains(.notify) && (characteristic.properties.contains(.writeWithoutResponse) || characteristic.properties.contains(.write)) {
                    self.didConnect = true
                    self.characteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)

                    if let continuation = self.connectionContinuation {
                        continuation.resume()
                        self.connectionContinuation = nil
                    }
                    self.delegate?.transportDidConnect(self)
                    return
                }
            }
        }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        MainActor.assumeIsolated {
            guard let data = characteristic.value else { return }
            let bytes = [UInt8](data)
            self.delegate?.transport(self, didReceive: bytes)
        }
    }

    /// Called when the peripheral is ready to accept another writeWithoutResponse.
    nonisolated public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        MainActor.assumeIsolated {
            if !self.writeContinuations.isEmpty {
                let continuation = self.writeContinuations.removeFirst()
                continuation.resume()
            }
        }
    }
}
