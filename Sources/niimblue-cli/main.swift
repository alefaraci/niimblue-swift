import ArgumentParser
import NiimblueLib
import Foundation
import CoreBluetooth

@main
struct NiimblueCLI: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            abstract: "Niimbot CLI for macOS",
            subcommands: [Scan.self, Info.self, Print.self]
        )
    }
}

struct Scan: AsyncParsableCommand {
    @Option(name: .shortAndLong, help: "Timeout in seconds")
    var timeout: TimeInterval = 5.0
    
    func run() async throws {
        // BLETransport is @MainActor, so init must be awaited or on MainActor
        let transport = await BLETransport()
        print("Scanning for devices...")
        
        try await transport.scan(duration: timeout) { peripheral, name, rssi in
             let displayName = peripheral.name ?? name ?? "Unknown"
             print("Found: \(displayName) (\(peripheral.identifier.uuidString)) RSSI: \(rssi)")
        }
        print("Scan complete.")
    }
}

struct Info: AsyncParsableCommand {
    @Option(name: .shortAndLong, help: "Device name or UUID")
    var address: String
    
    func run() async throws {
        let transport = await BLETransport(deviceNameOrAddress: address)
        let client = await NiimbotClient(transport: transport)
        
        print("Connecting to \(address)...")
        try await client.connect()
        print("Connected.")
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        try await client.disconnect()
    }
}

struct Print: AsyncParsableCommand {
    @Argument(help: "Image path")
    var path: String
    
    @Option(name: .shortAndLong, help: "Device name or UUID")
    var address: String
    
    @Option(name: .shortAndLong, help: "Print density")
    var density: Int = 3
    
    @Option(name: .shortAndLong, help: "Label type (1=gap, 2=black, 3=continuous)")
    var labelType: Int = 1
    
    @Option(name: .shortAndLong, help: "Quantity")
    var quantity: Int = 1
    
    @Option(name: [.customShort("D"), .long], help: "Print direction (left/top)")
    var direction: String = "left"

    @Option(name: .shortAndLong, help: "Black/white threshold (0-255, default 128)")
    var threshold: Int = 128
    
    func run() async throws {
        let transport = await BLETransport(deviceNameOrAddress: address)
        let client = await NiimbotClient(transport: transport)
        
        print("Connecting to \(address)...")
        try await client.connect()
        print("Connected.")
        
        let printDirection = PrintDirection(rawValue: direction) ?? .left
        
        print("Encoding image...")
        let encoded = try ImageEncoder.encode(imagePath: path, printDirection: printDirection, threshold: UInt8(threshold))
        
        print("Printing \(quantity) copies...")
        
        try await client.print(image: encoded, quantity: quantity, density: density, labelType: labelType)
        
        print("Done.")
        try await client.disconnect()
    }
}
