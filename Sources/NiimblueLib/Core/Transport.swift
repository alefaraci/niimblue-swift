import Foundation

public protocol TransportDelegate: AnyObject {
    @MainActor func transportDidConnect(_ transport: Transport)
    @MainActor func transportDidDisconnect(_ transport: Transport)
    @MainActor func transport(_ transport: Transport, didReceive data: [UInt8])
}

public protocol Transport: AnyObject {
    @MainActor var delegate: TransportDelegate? { get set }
    @MainActor func connect() async throws
    @MainActor func disconnect() async throws
    @MainActor func send(data: [UInt8]) async throws
}
