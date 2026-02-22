import Foundation

/// Commands IDs from client to printer
public enum RequestCommandId: Int, Sendable {
    case invalid = -1
    /// Entire packet should be prefixed with 0x03
    case connect = 193
    case cancelPrint = 218
    case calibrateHeight = 89
    case heartbeat = 220
    case labelPositioningCalibration = 142
    case pageEnd = 227
    case printerLog = 5
    case pageStart = 3
    case printBitmapRow = 133
    /// Sent if black pixels < 6
    case printBitmapRowIndexed = 131
    case printClear = 32
    case printEmptyRow = 132
    case printEnd = 243
    case printerInfo = 64
    case printerConfig = 175
    case printerStatusData = 165
    case printerReset = 40
    case printQuantity = 21
    case printStart = 1
    case printStatus = 163
    case rfidInfo = 26
    case rfidInfo2 = 28
    case rfidSuccessTimes = 84
    case setAutoShutdownTime = 39
    case setDensity = 33
    case setLabelType = 35
    /// 2, 4 or 6 bytes
    case setPageSize = 19
    case soundSettings = 88
    /// some info request (niimbot app)
    case antiFake = 11
    case writeRFID = 112
    case printTestPage = 90
    case startFirmwareUpgrade = 245
    case firmwareCrc = 145
    case firmwareCommit = 146
    case firmwareChunk = 155
    case firmwareNoMoreChunks = 156
    case printerCheckLine = 134
    case getCurrentTimeFormat = 18
    case printerConfig2 = 7
    case getKeyFunction = 9
    case getPrintQuality = 13
    case getPrinterConfigurationWifi = 162
}

/// Commands IDs from printer to client
public enum ResponseCommandId: Int, Sendable {
    case inInvalid = -1
    case inNotSupported = 0
    case inConnect = 194
    case inCalibrateHeight = 105
    case inCancelPrint = 208
    case inAntiFake = 12
    case inHeartbeatAdvanced1 = 221
    case inHeartbeatBasic = 222
    case inHeartbeatUnknown = 223
    case inHeartbeatAdvanced2 = 217
    case inLabelPositioningCalibration = 143
    case inPageStart = 4
    case inPrintClear = 48
    case inPrinterCheckLine = 211
    case inPrintEnd = 244
    case inPrinterConfig = 191
    case inPrinterLog = 6
    case inPrinterInfoAutoShutDownTime = 71
    case inPrinterInfoBluetoothAddress = 77
    case inPrinterInfoSpeed = 66
    case inPrinterInfoDensity = 65
    case inPrinterInfoLanguage = 70
    case inPrinterInfoChargeLevel = 74
    case inPrinterInfoHardWareVersion = 76
    case inPrinterInfoLabelType = 67
    case inPrinterInfoPrinterCode = 72
    case inPrinterInfoSerialNumber = 75
    case inPrinterInfoSoftWareVersion = 73
    case inPrinterInfoArea = 79
    case inPrinterStatusData = 181
    case inPrinterReset = 56
    case inPrintStatus = 179
    case inPrintError = 219
    case inPrintQuantity = 22
    case inPrintStart = 2
    case inRfidInfo = 27
    case inRfidInfo2 = 29
    case inRfidSuccessTimes = 100
    case inSetAutoShutdownTime = 55
    case inSetDensity = 49
    case inSetLabelType = 51
    case inSetPageSize = 20
    case inSoundSettings = 104
    case inPageEnd = 228
    case inPrinterPageIndex = 224
    case inPrintTestPage = 106
    case inWriteRFID = 113
    case inStartFirmwareUpgrade = 246
    case inRequestFirmwareCrc = 144
    case inRequestFirmwareChunk = 154
    case inFirmwareCheckResult = 157
    case inFirmwareResult = 158
    case inResetTimeout = 198
    case inGetCurrentTimeFormat = 17
    case inPrinterConfig2 = 8
    case inGetKeyFunction = 10
    case inGetPrintQuality = 13
    case inGetPrinterConfigurationWifi = 178
}

/// Map request id to response id. nil means no response expected (one way).
public let commandsMap: [RequestCommandId: [ResponseCommandId]?] = [
    .invalid: nil,
    .printBitmapRow: nil,
    .printBitmapRowIndexed: nil,
    .printEmptyRow: nil,
    .connect: [.inConnect],
    .cancelPrint: [.inCancelPrint],
    .calibrateHeight: [.inCalibrateHeight],
    .heartbeat: [.inHeartbeatBasic, .inHeartbeatUnknown, .inHeartbeatAdvanced1, .inHeartbeatAdvanced2],
    .labelPositioningCalibration: [.inLabelPositioningCalibration],
    .pageEnd: [.inPageEnd],
    .printerLog: [.inPrinterLog],
    .pageStart: [.inPageStart],
    .printClear: [.inPrintClear],
    .printEnd: [.inPrintEnd],
    .printerInfo: [
        .inPrinterInfoArea,
        .inPrinterInfoAutoShutDownTime,
        .inPrinterInfoBluetoothAddress,
        .inPrinterInfoChargeLevel,
        .inPrinterInfoDensity,
        .inPrinterInfoHardWareVersion,
        .inPrinterInfoLabelType,
        .inPrinterInfoLanguage,
        .inPrinterInfoPrinterCode,
        .inPrinterInfoSerialNumber,
        .inPrinterInfoSoftWareVersion,
        .inPrinterInfoSpeed
    ],
    .printerConfig: [.inPrinterConfig],
    .printerStatusData: [.inPrinterStatusData],
    .printerReset: [.inPrinterReset],
    .printQuantity: [.inPrintQuantity],
    .printStart: [.inPrintStart],
    .printStatus: [.inPrintStatus],
    .rfidInfo: [.inRfidInfo],
    .rfidInfo2: [.inRfidInfo2],
    .rfidSuccessTimes: [.inRfidSuccessTimes],
    .setAutoShutdownTime: [.inSetAutoShutdownTime],
    .setDensity: [.inSetDensity],
    .setLabelType: [.inSetLabelType],
    .setPageSize: [.inSetPageSize],
    .soundSettings: [.inSoundSettings],
    .antiFake: [.inAntiFake],
    .writeRFID: [.inWriteRFID],
    .printTestPage: [.inPrintTestPage],
    .startFirmwareUpgrade: [.inStartFirmwareUpgrade],
    .firmwareCrc: nil,
    .firmwareChunk: nil,
    .firmwareNoMoreChunks: nil,
    .firmwareCommit: nil,
    .printerCheckLine: [.inPrinterCheckLine],
    .getCurrentTimeFormat: [.inGetCurrentTimeFormat],
    .printerConfig2: [.inPrinterConfig2],
    .getKeyFunction: [.inGetKeyFunction],
    .getPrintQuality: [.inGetPrintQuality],
    .getPrinterConfigurationWifi: [.inGetPrinterConfigurationWifi]
]

/// Firmware exchange packet IDs
public let firmwareExchangePackets = (
    tx: [
        RequestCommandId.firmwareChunk,
        .firmwareCrc,
        .firmwareNoMoreChunks,
        .firmwareCommit
    ],
    rx: [
        ResponseCommandId.inRequestFirmwareCrc,
        .inRequestFirmwareChunk,
        .inFirmwareCheckResult,
        .inFirmwareResult
    ]
)
