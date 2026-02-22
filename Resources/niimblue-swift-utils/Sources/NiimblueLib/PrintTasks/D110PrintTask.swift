import Foundation

/// D110 series print task
public actor D110PrintTask: AbstractPrintTask {
    public let abstraction: Abstraction
    public var printOptions: PrintOptions
    public var pagesPrinted: Int = 0

    public init(abstraction: Abstraction, options: PrintOptions = PrintOptions()) {
        self.abstraction = abstraction
        self.printOptions = options
    }

    public func printInit() async throws {
        try await abstraction.sendAll([
            PacketGenerator.setDensity(UInt8(printOptions.density)),
            PacketGenerator.setLabelType(printOptions.labelType.rawValue),
            PacketGenerator.printStart1b()
        ])
    }

    public func printPage(_ image: EncodedImage, quantity: Int = 1) async throws {
        try checkAddPage(quantity)

        let pixels = await printheadPixels()
        let packets = PacketGenerator.writeImageData(image, options: ImagePacketsGenerateOptions(
            printheadPixels: pixels
        ))

        var allPackets: [NiimbotPacket] = [
            PacketGenerator.pageStart(),
            PacketGenerator.setPageSize4b(image.rows, image.cols)
        ]
        allPackets.append(contentsOf: packets)
        allPackets.append(PacketGenerator.pageEnd())

        try await abstraction.sendAll(allPackets, timeoutMs: printOptions.pageTimeoutMs)

        pagesPrinted += quantity
    }

    public func waitForFinished() async throws {
        await abstraction.setPacketTimeout(printOptions.statusTimeoutMs)
        defer {
            Task { await abstraction.setDefaultPacketTimeout() }
        }

        try await abstraction.waitUntilPrintFinishedByStatusPoll(
            printOptions.totalPages,
            pollIntervalMs: printOptions.statusPollIntervalMs
        )
    }
}
