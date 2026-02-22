import Foundation

/// Print options for print tasks
public struct PrintOptions: Sendable {
    public var labelType: LabelType
    public var density: Int
    public var totalPages: Int
    public var statusPollIntervalMs: Int
    public var statusTimeoutMs: Int
    public var pageTimeoutMs: Int

    public init(
        labelType: LabelType = .withGaps,
        density: Int = 2,
        totalPages: Int = 1,
        statusPollIntervalMs: Int = 300,
        statusTimeoutMs: Int = 5000,
        pageTimeoutMs: Int = 10000
    ) {
        self.labelType = labelType
        self.density = density
        self.totalPages = totalPages
        self.statusPollIntervalMs = statusPollIntervalMs
        self.statusTimeoutMs = statusTimeoutMs
        self.pageTimeoutMs = pageTimeoutMs
    }
}

/// Print task type
public enum PrintTaskName: String, Sendable, CaseIterable {
    case d110 = "D110"
    case b1 = "B1"
    case b21 = "B21"
    case d110Mv4 = "D110_MV4"
    case oldD11 = "OldD11"
}

/// Abstract print task base class
public protocol AbstractPrintTask: Actor {
    var abstraction: Abstraction { get }
    var printOptions: PrintOptions { get set }
    var pagesPrinted: Int { get set }

    func printInit() async throws
    func printPage(_ image: EncodedImage, quantity: Int) async throws
    func waitForFinished() async throws
    func printEnd() async throws -> Bool
}

/// Default implementation
public extension AbstractPrintTask {
    func checkAddPage(_ quantity: Int) throws {
        if pagesPrinted + quantity > (printOptions.totalPages) {
            throw PrintError(message: "Trying to print too many pages (task totalPages may not be set correctly)", reasonId: 0)
        }
    }

    func printheadPixels() async -> Int? {
        await abstraction.getClient()?.getModelMetadata()?.printheadPixels
    }

    func printEnd() async throws -> Bool {
        try await abstraction.printEnd()
    }
}

/// Find print task for model
public func findPrintTask(_ model: PrinterModel, _ protocolVersion: Int?) -> PrintTaskName? {
    switch model {
    case .b1, .b1_PRO, .b21, .b21_PRO, .b21_C2B, .b21_L2B, .b21S, .b21S_C2B, .b3, .b31, .b4:
        return .b1
    case .d11, .d11S, .d110, .d101, .b16, .b18, .b18S, .h1, .h1S, .n1, .hi_D110, .hi_NB_D11, .d11_H, .d11_PRO, .fust, .betty, .d110_M:
        if protocolVersion == 4 {
            return .d110Mv4
        }
        return .d110
    default:
        return nil
    }
}
