import Foundation

public enum RequestCommandId: UInt8, Sendable {
    case Invalid = 255
    case Connect = 193
    case CancelPrint = 218
    case CalibrateHeight = 89
    case Heartbeat = 220
    case LabelPositioningCalibration = 142
    case PageEnd = 227
    case PrinterLog = 5
    case PageStart = 3
    case PrintBitmapRow = 133
    case PrintBitmapRowIndexed = 131
    case PrintClear = 32
    case PrintEmptyRow = 132
    case PrintEnd = 243
    case PrinterInfo = 64
    case PrinterConfig = 175
    case PrinterStatusData = 165
    case PrinterReset = 40
    case PrintQuantity = 21
    case PrintStart = 1
    case PrintStatus = 163
    case RfidInfo = 26
    case RfidInfo2 = 28
    case RfidSuccessTimes = 84
    case SetAutoShutdownTime = 39
    case SetDensity = 33
    case SetLabelType = 35
    case SetPageSize = 19
    case SoundSettings = 88
    case AntiFake = 11
    case WriteRFID = 112
    case PrintTestPage = 90
    case StartFirmwareUpgrade = 245
    case FirmwareCrc = 145
    case FirmwareCommit = 146
    case FirmwareChunk = 155
    case FirmwareNoMoreChunks = 156
    case PrinterCheckLine = 134
    case GetCurrentTimeFormat = 18
    case PrinterConfig2 = 7
    case GetKeyFunction = 9
    case GetPrintQuality = 13
    case GetPrinterConfigurationWifi = 162
}

public enum ResponseCommandId: UInt8, Sendable {
    case In_Invalid = 255
    case In_NotSupported = 0
    case In_Connect = 194
    case In_CalibrateHeight = 105
    case In_CancelPrint = 208
    case In_AntiFake = 12
    case In_HeartbeatAdvanced1 = 221
    case In_HeartbeatBasic = 222
    case In_HeartbeatUnknown = 223
    case In_HeartbeatAdvanced2 = 217
    case In_LabelPositioningCalibration = 143
    case In_PageStart = 4
    case In_PrintClear = 48
    case In_PrinterCheckLine = 211
    case In_PrintEnd = 244
    case In_PrinterConfig = 191
    case In_PrinterLog = 6
    case In_PrinterInfoAutoShutDownTime = 71
    case In_PrinterInfoBluetoothAddress = 77
    case In_PrinterInfoSpeed = 66
    case In_PrinterInfoDensity = 65
    case In_PrinterInfoLanguage = 70
    case In_PrinterInfoChargeLevel = 74
    case In_PrinterInfoHardWareVersion = 76
    case In_PrinterInfoLabelType = 67
    case In_PrinterInfoPrinterCode = 72
    case In_PrinterInfoSerialNumber = 75
    case In_PrinterInfoSoftWareVersion = 73
    case In_PrinterInfoArea = 79
    case In_PrinterStatusData = 181
    case In_PrinterReset = 56
    case In_PrintStatus = 179
    case In_PrintError = 219
    case In_PrintQuantity = 22
    case In_PrintStart = 2
    case In_RfidInfo = 27
    case In_RfidInfo2 = 29
    case In_RfidSuccessTimes = 100
    case In_SetAutoShutdownTime = 55
    case In_SetDensity = 49
    case In_SetLabelType = 51
    case In_SetPageSize = 20
    case In_SoundSettings = 104
    case In_PageEnd = 228
    case In_PrinterPageIndex = 224
    case In_PrintTestPage = 106
    case In_WriteRFID = 113
    case In_StartFirmwareUpgrade = 246
    case In_RequestFirmwareCrc = 144
    case In_RequestFirmwareChunk = 154
    case In_FirmwareCheckResult = 157
    case In_FirmwareResult = 158
    case In_ResetTimeout = 198
    case In_GetCurrentTimeFormat = 17
    case In_PrinterConfig2 = 8
    case In_GetKeyFunction = 10
    case In_GetPrintQuality = 13
    case In_GetPrinterConfigurationWifi = 178
}

public struct CommandsMap: Sendable {
    public static let requestToResponse: [RequestCommandId: [ResponseCommandId]?] = [
        .Connect: [.In_Connect],
        .PrinterInfo: [
            .In_PrinterInfoArea,
            .In_PrinterInfoAutoShutDownTime,
            .In_PrinterInfoBluetoothAddress,
            .In_PrinterInfoChargeLevel,
            .In_PrinterInfoDensity,
            .In_PrinterInfoHardWareVersion,
            .In_PrinterInfoLabelType,
            .In_PrinterInfoLanguage,
            .In_PrinterInfoPrinterCode,
            .In_PrinterInfoSerialNumber,
            .In_PrinterInfoSoftWareVersion,
            .In_PrinterInfoSpeed,
        ],
        .PrinterStatusData: [.In_PrinterStatusData],
        .SetDensity: [.In_SetDensity],
        .SetLabelType: [.In_SetLabelType],
        .PrintStart: [.In_PrintStart],
        .PageStart: [.In_PageStart],
        .PageEnd: [.In_PageEnd],
        .PrintEnd: [.In_PrintEnd],
        .PrintClear: [.In_PrintClear],
        .PrintQuantity: [.In_PrintQuantity],
        .SetPageSize: [.In_SetPageSize],
        .PrinterReset: [.In_PrinterReset],
        .CancelPrint: [.In_CancelPrint],
        .PrintStatus: [.In_PrintStatus],
        .SoundSettings: [.In_SoundSettings],
        .PrintEmptyRow: nil,
        .PrintBitmapRow: nil,
        .PrintBitmapRowIndexed: nil,
    ]
}
