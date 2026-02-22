import ArgumentParser
import Foundation
import NiimblueLib
import CoreGraphics

/// Client wrapper to handle both BLE and Serial clients
enum NiimbotClient {
    case ble(NiimbotBleClient)
    case serial(NiimbotSerialClient)

    var isConnected: Bool {
        get async {
            switch self {
            case .ble(let client):
                return await client.isConnected
            case .serial(let client):
                return await client.isConnected
            }
        }
    }

    var abstraction: Abstraction {
        get async {
            switch self {
            case .ble(let client):
                return await client.abstraction
            case .serial(let client):
                return await client.abstraction
            }
        }
    }

    var eventStream: AsyncStream<any NiimbotEvent> {
        get async {
            switch self {
            case .ble(let client):
                return await client.eventStream
            case .serial(let client):
                return await client.eventStream
            }
        }
    }

    func connect() async throws -> ConnectionInfo {
        switch self {
        case .ble(let client):
            return try await client.connect()
        case .serial(let client):
            return try await client.connect()
        }
    }

    func disconnect() async throws {
        switch self {
        case .ble(let client):
            try await client.disconnect()
        case .serial(let client):
            try await client.disconnect()
        }
    }

    func getPrinterInfo() async -> PrinterInfo {
        switch self {
        case .ble(let client):
            return await client.getPrinterInfo()
        case .serial(let client):
            return await client.getPrinterInfo()
        }
    }

    func getPrintTaskType() async -> PrintTaskName? {
        switch self {
        case .ble(let client):
            return await client.getPrintTaskType()
        case .serial(let client):
            return await client.getPrintTaskType()
        }
    }

    func setDebug(_ value: Bool) async {
        switch self {
        case .ble(let client):
            await client.setDebug(value)
        case .serial(let client):
            await client.setDebug(value)
        }
    }
}

@main
struct NiimblueCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "niimblue-cli",
        abstract: "CLI for Niimbot thermal label printers",
        subcommands: [Scan.self, Info.self, Print.self, Flash.self]
    )
}

// MARK: - Scan Command

struct Scan: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Scan for available printers"
    )

    @Option(name: [.customShort("T"), .long], help: "Timeout in milliseconds")
    var timeout: Int = 5000

    @Option(name: [.short, .long], help: "Transport type (ble or serial)")
    var transport: String = "ble"

    mutating func run() async throws {
        print("Scanning for \(transport) devices...")

        switch transport.lowercased() {
        case "ble":
            let scanner = BLEScanner()
            let devices = try await scanner.scan(timeoutMs: timeout)
            if devices.isEmpty {
                print("No devices found")
            } else {
                print("Found \(devices.count) device(s):")
                for device in devices {
                    print("  - \(device.name) [\(device.address)]")
                }
            }

        case "serial":
            let scanner = SerialScanner()
            let devices = try await scanner.scan(timeoutMs: timeout)
            if devices.isEmpty {
                print("No serial ports found")
            } else {
                print("Found \(devices.count) serial port(s):")
                for device in devices {
                    print("  - \(device.name) [\(device.address)]")
                }
            }

        default:
            throw ValidationError("Invalid transport: \(transport). Use 'ble' or 'serial'.")
        }
    }
}

// MARK: - Info Command

struct Info: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Get printer information"
    )

    @Option(name: [.short, .long], help: "Transport type (ble or serial)")
    var transport: String

    @Option(name: [.short, .long], help: "Device address or port path")
    var address: String

    @Flag(name: [.short, .long], help: "Enable debug output")
    var debug: Bool = false

    mutating func run() async throws {
        let client: NiimbotClient

        switch transport.lowercased() {
        case "ble":
            let bleClient = NiimbotBleClient()
            await bleClient.setAddress(address)
            client = .ble(bleClient)

        case "serial":
            let serialClient = NiimbotSerialClient()
            await serialClient.setPort(address)
            client = .serial(serialClient)

        default:
            throw ValidationError("Invalid transport: \(transport). Use 'ble' or 'serial'.")
        }

        await client.setDebug(debug)

        // Set up event handlers
        let debugMode = debug
        Task {
            for await event in await client.eventStream {
                if debugMode {
                    switch event {
                    case let e as PacketSentEvent:
                        print(">> \(Utils.bufToHex(e.packet.toBytes())) (cmd: \(e.packet.command))")
                    case let e as PacketReceivedEvent:
                        print("<< \(Utils.bufToHex(e.packet.toBytes())) (cmd: \(e.packet.command))")
                    case let e as ConnectEvent:
                        print("Connected: \(e.info.deviceName ?? "unknown")")
                    case is DisconnectEvent:
                        print("Disconnected")
                    default:
                        break
                    }
                }
            }
        }

        do {
            print("Connecting to \(address)...")
            _ = try await client.connect()

            let info = await client.getPrinterInfo()
            print("\n=== Printer Information ===")
            print("Model ID: \(info.modelId ?? 0)")

            if let modelId = info.modelId, let meta = getPrinterMetaById(modelId) {
                print("Model: \(meta.model.rawValue)")
                print("DPI: \(meta.dpi)")
                print("Printhead: \(meta.printheadPixels) pixels")
                print("Print direction: \(meta.printDirection.rawValue)")
                print("Density range: \(meta.densityMin) - \(meta.densityMax) (default: \(meta.densityDefault))")
            }

            print("Serial: \(info.serial ?? "unknown")")
            print("MAC: \(info.mac ?? "unknown")")
            print("Battery: \(info.charge?.rawValue ?? 0)")
            print("Label type: \(info.labelType?.rawValue ?? 0)")
            print("Software: \(info.softwareVersion ?? "unknown")")
            print("Hardware: \(info.hardwareVersion ?? "unknown")")
            print("Protocol version: \(info.protocolVersion ?? 0)")

            if let taskName = await client.getPrintTaskType() {
                print("Print task: \(taskName.rawValue)")
            }

            try await client.disconnect()
        } catch {
            print("Error: \(error)")
            try? await client.disconnect()
            throw ExitCode(1)
        }
    }
}

// MARK: - Print Command

struct Print: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print an image"
    )

    @Argument(help: "Path to PNG image file")
    var imagePath: String

    @Option(name: [.short, .long], help: "Transport type (ble or serial)")
    var transport: String

    @Option(name: [.short, .long], help: "Device address or port path")
    var address: String

    @Option(name: [.customShort("P"), .long], help: "Print direction (left or top)")
    var printDirection: String = "left"

    @Option(name: [.long], help: "Print task type (D110, B1, etc.)")
    var printTask: String?

    @Option(name: [.customShort("L"), .long], help: "Label type (1-10)")
    var labelType: Int = 1

    @Option(name: [.short, .long], help: "Print density")
    var density: Int = 3

    @Option(name: [.short, .long], help: "Number of copies")
    var quantity: Int = 1

    @Option(name: [.customShort("T"), .long], help: "Black/white threshold (0-255)")
    var threshold: Int = 128

    @Flag(name: [.customShort("D"), .long], help: "Enable debug output")
    var debug: Bool = false

    mutating func run() async throws {
        let direction: PrintDirection = printDirection == "top" ? .top : .left

        // Load and encode image
        let url = URL(fileURLWithPath: imagePath)
        let image = try ImageEncoder.loadImage(from: url)
        let encoded = ImageEncoder.encodeImage(image, printDirection: direction, threshold: UInt8(threshold))

        print("Image: \(encoded.cols)x\(encoded.rows) pixels, \(encoded.rowsData.count) rows")

        let client: NiimbotClient

        switch transport.lowercased() {
        case "ble":
            let bleClient = NiimbotBleClient()
            await bleClient.setAddress(address)
            client = .ble(bleClient)

        case "serial":
            let serialClient = NiimbotSerialClient()
            await serialClient.setPort(address)
            client = .serial(serialClient)

        default:
            throw ValidationError("Invalid transport: \(transport). Use 'ble' or 'serial'.")
        }

        await client.setDebug(debug)

        // Set up event handlers
        let debugMode = debug
        Task {
            for await event in await client.eventStream {
                switch event {
                case let e as PrintProgressEvent:
                    print("Progress: Page \(e.page)/\(e.pagesTotal), Print: \(e.pagePrintProgress)%, Feed: \(e.pageFeedProgress)%")
                case let e as PacketSentEvent where debugMode:
                    print(">> \(Utils.bufToHex(e.packet.toBytes())) (cmd: \(e.packet.command))")
                case let e as PacketReceivedEvent where debugMode:
                    print("<< \(Utils.bufToHex(e.packet.toBytes())) (cmd: \(e.packet.command))")
                case let e as ConnectEvent:
                    print("Connected: \(e.info.deviceName ?? "unknown")")
                case is DisconnectEvent:
                    print("Disconnected")
                default:
                    break
                }
            }
        }

        do {
            print("Connecting to \(address)...")
            _ = try await client.connect()

            // Determine print task
            let taskName: PrintTaskName
            if let task = printTask, let name = PrintTaskName(rawValue: task) {
                taskName = name
            } else if let detected = await client.getPrintTaskType() {
                taskName = detected
            } else {
                taskName = .d110
            }

            print("Using print task: \(taskName.rawValue)")

            let abstraction = await client.abstraction
            let printTaskInstance = await abstraction.newPrintTask(taskName, options: PrintOptions(
                labelType: LabelType(rawValue: UInt8(labelType)) ?? .withGaps,
                density: density,
                totalPages: quantity,
                statusPollIntervalMs: 500,
                statusTimeoutMs: 8000
            ))

            try await printTaskInstance.printInit()
            try await printTaskInstance.printPage(encoded, quantity: quantity)
            try await printTaskInstance.waitForFinished()
            _ = try await printTaskInstance.printEnd()

            try await client.disconnect()
            print("Print completed successfully!")

        } catch {
            print("Error: \(error)")
            try? await client.disconnect()
            throw ExitCode(1)
        }
    }
}

// MARK: - Flash Command

struct Flash: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Flash firmware to printer"
    )

    @Option(name: [.short, .long], help: "Transport type (ble or serial)")
    var transport: String

    @Option(name: [.short, .long], help: "Device address or port path")
    var address: String

    @Option(name: [.short, .long], help: "Firmware file path")
    var file: String

    @Option(name: [.short, .long], help: "New firmware version (x.x format)")
    var newVersion: String

    @Flag(name: [.short, .long], help: "Enable debug output")
    var debug: Bool = false

    mutating func run() async throws {
        print("Firmware flashing is not yet implemented")
        throw ExitCode(1)
    }
}
