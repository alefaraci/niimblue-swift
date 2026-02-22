import Foundation

/// Scanned device info
public struct ScannedDevice: Sendable, Identifiable {
    public let id: String
    public let address: String
    public let name: String

    public init(address: String, name: String) {
        self.id = address
        self.address = address
        self.name = name
    }
}

/// Transport scanner protocol
public protocol TransportScanner: AnyObject, Sendable {
    associatedtype Device: Sendable & Identifiable where Device.ID == String

    /// Scan for devices
    func scan(timeoutMs: Int) async throws -> [Device]
}
