import Foundation

/// Printer info type
public enum PrinterInfoType: UInt8, Sendable {
    case density = 1
    case speed = 2
    case labelType = 3
    case language = 6
    case autoShutdownTime = 7
    case printerModelId = 8
    case softWareVersion = 9
    case batteryChargeLevel = 10
    case serialNumber = 11
    case hardWareVersion = 12
    case bluetoothAddress = 13
    case printMode = 14
    case area = 15
}

/// Sound settings type
public enum SoundSettingsType: UInt8, Sendable {
    case setSound = 1
    case getSoundState = 2
}

/// Sound settings item type
public enum SoundSettingsItemType: UInt8, Sendable {
    case bluetoothConnectionSound = 1
    case powerSound = 2
}

/// Label type
public enum LabelType: UInt8, Sendable, Codable {
    case invalid = 0
    /// Default for most label printers
    case withGaps = 1
    case black = 2
    case continuous = 3
    case perforated = 4
    case transparent = 5
    case pvcTag = 6
    case blackMarkGap = 10
    case heatShrinkTube = 11
}

/// Heartbeat type
public enum HeartbeatType: UInt8, Sendable {
    case advanced1 = 1
    case basic = 2
    case unknown = 3
    case advanced2 = 4
}

/// Auto shutdown time
public enum AutoShutdownTime: UInt8, Sendable, Codable {
    /// Usually 15 minutes
    case shutdownTime1 = 1
    /// Usually 30 minutes
    case shutdownTime2 = 2
    /// May be 45 or 60 minutes
    case shutdownTime3 = 3
    /// May be 60 minutes or never
    case shutdownTime4 = 4
}

/// Battery charge level
public enum BatteryChargeLevel: UInt8, Sendable, Codable {
    case charge0 = 0
    case charge25 = 1
    case charge50 = 2
    case charge75 = 3
    case charge100 = 4
}

/// Connect result
public enum ConnectResult: UInt8, Sendable, Codable {
    case disconnect = 0
    case connected = 1
    case connectedNew = 2
    case connectedV3 = 3
    case firmwareErrors = 90
}

/// Printer error code
public enum PrinterErrorCode: UInt8, Sendable {
    case coverOpen = 1
    case lackPaper = 2
    case lowBattery = 3
    case batteryException = 4
    case userCancel = 5
    case dataError = 6
    case overheat = 7
    case paperOutException = 8
    case printerBusy = 9
    case noPrinterHead = 10
    case temperatureLow = 11
    case printerHeadLoose = 12
    case noRibbon = 13
    case wrongRibbon = 14
    case usedRibbon = 15
    case wrongPaper = 16
    case setPaperFail = 17
    case setPrintModeFail = 18
    case setPrintDensityFail = 19
    case writeRfidFail = 20
    case setMarginFail = 21
    case communicationException = 22
    case disconnect = 23
    case canvasParameterError = 24
    case rotationParameterException = 25
    case jsonParameterException = 26
    case b3sAbnormalPaperOutput = 27
    case eCheckPaper = 28
    case rfidTagNotWritten = 29
    case setPrintDensityNoSupport = 30
    case setPrintModeNoSupport = 31
    case setPrintLabelMaterialError = 32
    case setPrintLabelMaterialNoSupport = 33
    case notSupportWrittenRfid = 34
    case illegalPage = 50
    case illegalRibbonPage = 51
    case receiveDataTimeout = 52
    case nonDedicatedRibbon = 53

    public var description: String {
        switch self {
        case .coverOpen: return "Cover open"
        case .lackPaper: return "No paper"
        case .lowBattery: return "Low battery"
        case .batteryException: return "Battery exception"
        case .userCancel: return "User cancel"
        case .dataError: return "Data error"
        case .overheat: return "Overheat"
        case .paperOutException: return "Paper out exception"
        case .printerBusy: return "Printer busy"
        case .noPrinterHead: return "No printer head"
        case .temperatureLow: return "Temperature low"
        case .printerHeadLoose: return "Printer head loose"
        case .noRibbon: return "No ribbon"
        case .wrongRibbon: return "Wrong ribbon"
        case .usedRibbon: return "Used ribbon"
        case .wrongPaper: return "Wrong paper"
        case .setPaperFail: return "Set paper fail"
        case .setPrintModeFail: return "Set print mode fail"
        case .setPrintDensityFail: return "Set print density fail"
        case .writeRfidFail: return "Write RFID fail"
        case .setMarginFail: return "Set margin fail"
        case .communicationException: return "Communication exception"
        case .disconnect: return "Disconnect"
        case .canvasParameterError: return "Canvas parameter error"
        case .rotationParameterException: return "Rotation parameter exception"
        case .jsonParameterException: return "JSON parameter exception"
        case .b3sAbnormalPaperOutput: return "B3S abnormal paper output"
        case .eCheckPaper: return "Check paper"
        case .rfidTagNotWritten: return "RFID tag not written"
        case .setPrintDensityNoSupport: return "Set print density not supported"
        case .setPrintModeNoSupport: return "Set print mode not supported"
        case .setPrintLabelMaterialError: return "Set print label material error"
        case .setPrintLabelMaterialNoSupport: return "Set print label material not supported"
        case .notSupportWrittenRfid: return "Not support written RFID"
        case .illegalPage: return "Illegal page"
        case .illegalRibbonPage: return "Illegal ribbon page"
        case .receiveDataTimeout: return "Receive data timeout"
        case .nonDedicatedRibbon: return "Non-dedicated ribbon"
        }
    }
}

/// Print error
public struct PrintError: Error, CustomStringConvertible {
    public let message: String
    public let reasonId: UInt8

    public init(message: String, reasonId: UInt8) {
        self.message = message
        self.reasonId = reasonId
    }

    public var description: String {
        message
    }
}

/// Printer information
public struct PrinterInfo: Sendable, Codable {
    public var connectResult: ConnectResult?
    public var protocolVersion: Int?
    public var modelId: Int?
    public var serial: String?
    public var mac: String?
    public var charge: BatteryChargeLevel?
    public var autoShutdownTime: AutoShutdownTime?
    public var labelType: LabelType?
    public var softwareVersion: String?
    public var hardwareVersion: String?

    public init() {}
}

/// Print status
public struct PrintStatus: Sendable {
    public let page: Int
    public let pagePrintProgress: Int
    public let pageFeedProgress: Int
}

/// RFID info
public struct RfidInfo: Sendable {
    public var tagPresent: Bool
    public var uuid: String
    public var barCode: String
    public var serialNumber: String
    public var allPaper: Int
    public var usedPaper: Int
    public var consumablesType: LabelType
    public var capacity: Int?

    public init() {
        tagPresent = false
        uuid = ""
        barCode = ""
        serialNumber = ""
        allPaper = -1
        usedPaper = -1
        consumablesType = .invalid
    }
}

/// Heartbeat data
public struct HeartbeatData: Sendable {
    public var paperState: Int
    public var rfidReadState: Int
    public var lidClosed: Bool
    public var powerLevel: BatteryChargeLevel

    public init() {
        paperState = -1
        rfidReadState = -1
        lidClosed = false
        powerLevel = .charge0
    }
}

/// Sound settings
public struct SoundSettings: Sendable {
    public let category: SoundSettingsType
    public let item: SoundSettingsItemType
    public let value: Bool
}

/// Printer status data
public struct PrinterStatusData: Sendable {
    public let supportColor: Int
    public let protocolVersion: Int
}

/// Connection info
public struct ConnectionInfo: Sendable {
    public let deviceName: String?
    public let result: ConnectResult
}
