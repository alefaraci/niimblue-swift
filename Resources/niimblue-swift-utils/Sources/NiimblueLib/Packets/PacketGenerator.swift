import Foundation

/// A helper class that generates various types of packets
public enum PacketGenerator {
    /// Maps a request command ID to its corresponding response IDs and creates a packet object
    public static func mapped(_ sendCmd: RequestCommandId, data: [UInt8] = [1]) -> NiimbotPacket {
        guard let respIds = commandsMap[sendCmd] else {
            let p = NiimbotPacket(command: sendCmd, data: data)
            p.oneWay = true
            return p
        }

        if respIds == nil {
            let p = NiimbotPacket(command: sendCmd, data: data)
            p.oneWay = true
            return p
        }

        return NiimbotPacket(command: sendCmd, data: data, validResponseIds: respIds!)
    }

    public static func connect() -> NiimbotPacket {
        mapped(.connect)
    }

    public static func getPrinterStatusData() -> NiimbotPacket {
        mapped(.printerStatusData)
    }

    public static func rfidInfo() -> NiimbotPacket {
        mapped(.rfidInfo)
    }

    public static func rfidInfo2() -> NiimbotPacket {
        mapped(.rfidInfo2)
    }

    public static func antiFake(_ queryType: UInt8) -> NiimbotPacket {
        mapped(.antiFake, data: [queryType])
    }

    public static func setAutoShutDownTime(_ time: AutoShutdownTime) -> NiimbotPacket {
        mapped(.setAutoShutdownTime, data: [time.rawValue])
    }

    public static func getPrinterInfo(_ type: PrinterInfoType) -> NiimbotPacket {
        mapped(.printerInfo, data: [type.rawValue])
    }

    public static func setSoundSettings(_ soundType: SoundSettingsItemType, on: Bool) -> NiimbotPacket {
        mapped(.soundSettings, data: [SoundSettingsType.setSound.rawValue, soundType.rawValue, on ? 1 : 0])
    }

    public static func getSoundSettings(_ soundType: SoundSettingsItemType) -> NiimbotPacket {
        mapped(.soundSettings, data: [SoundSettingsType.getSoundState.rawValue, soundType.rawValue, 1])
    }

    public static func heartbeat(_ type: HeartbeatType) -> NiimbotPacket {
        mapped(.heartbeat, data: [type.rawValue])
    }

    public static func setDensity(_ value: UInt8) -> NiimbotPacket {
        mapped(.setDensity, data: [value])
    }

    public static func setLabelType(_ value: UInt8) -> NiimbotPacket {
        mapped(.setLabelType, data: [value])
    }

    public static func setPageSize2b(_ rows: Int) -> NiimbotPacket {
        mapped(.setPageSize, data: Utils.u16ToBytes(UInt16(rows)))
    }

    /// B1 behavior: strange, first print is blank or printer prints many copies (use setPageSize6b instead)
    /// D110 behavior: ordinary.
    public static func setPageSize4b(_ rows: Int, _ cols: Int) -> NiimbotPacket {
        mapped(.setPageSize, data: Utils.u16ToBytes(UInt16(rows)) + Utils.u16ToBytes(UInt16(cols)))
    }

    /// 6-byte page size (for B1)
    public static func setPageSize6b(_ rows: Int, _ cols: Int, _ copiesCount: Int) -> NiimbotPacket {
        mapped(.setPageSize, data: Utils.u16ToBytes(UInt16(rows)) + Utils.u16ToBytes(UInt16(cols)) + Utils.u16ToBytes(UInt16(copiesCount)))
    }

    /// 13-byte page size (first seen on D110M v4)
    public static func setPageSize13b(
        _ rows: Int,
        _ cols: Int,
        _ copiesCount: Int,
        cutHeight: Int = 0,
        cutType: Int = 0,
        sendAll: Int = 0,
        partHeight: Int = 0
    ) -> NiimbotPacket {
        mapped(.setPageSize, data: Utils.u16ToBytes(UInt16(rows)) +
            Utils.u16ToBytes(UInt16(cols)) +
            Utils.u16ToBytes(UInt16(copiesCount)) +
            Utils.u16ToBytes(UInt16(cutHeight)) +
            [UInt8(cutType), 0x00, UInt8(sendAll)] +
            Utils.u16ToBytes(UInt16(partHeight)))
    }

    public static func setPrintQuantity(_ quantity: Int) -> NiimbotPacket {
        mapped(.printQuantity, data: Utils.u16ToBytes(UInt16(quantity)))
    }

    public static func printStatus() -> NiimbotPacket {
        mapped(.printStatus)
    }

    public static func printerReset() -> NiimbotPacket {
        mapped(.printerReset)
    }

    /// B1 behavior: after pageEnd paper stops at printhead position, on printEnd paper moved further.
    /// D110 behavior: ordinary.
    public static func printStart1b() -> NiimbotPacket {
        mapped(.printStart)
    }

    public static func printStart2b(_ totalPages: Int) -> NiimbotPacket {
        mapped(.printStart, data: Utils.u16ToBytes(UInt16(totalPages)))
    }

    /// B1 behavior: when totalPages > 1 after pageEnd paper stops at printhead position and waits for next page.
    /// When last page (totalPages) printed paper moved further.
    public static func printStart7b(_ totalPages: Int, pageColor: UInt8 = 0) -> NiimbotPacket {
        mapped(.printStart, data: Utils.u16ToBytes(UInt16(totalPages)) + [0x00, 0x00, 0x00, 0x00, pageColor])
    }

    /// First seen on D110M v4
    public static func printStart9b(_ totalPages: Int, pageColor: UInt8 = 0, quality: UInt8 = 0, someFlag: Bool = false) -> NiimbotPacket {
        mapped(.printStart, data: Utils.u16ToBytes(UInt16(totalPages)) + [0x00, 0x00, 0x00, 0x00, pageColor, quality, someFlag ? 0x01 : 0x00])
    }

    public static func printEnd() -> NiimbotPacket {
        mapped(.printEnd)
    }

    public static func pageStart() -> NiimbotPacket {
        mapped(.pageStart)
    }

    public static func pageEnd() -> NiimbotPacket {
        mapped(.pageEnd)
    }

    public static func printEmptySpace(_ pos: Int, _ repeatCount: UInt8) -> NiimbotPacket {
        mapped(.printEmptyRow, data: Utils.u16ToBytes(UInt16(pos)) + [repeatCount])
    }

    public static func printBitmapRow(
        _ pos: Int,
        _ repeatCount: UInt8,
        _ data: [UInt8],
        printheadPixels: Int,
        countsMode: CountsMode = .auto
    ) -> NiimbotPacket {
        let counts = Utils.countPixelsForBitmapPacket(data, printheadPixels: printheadPixels, mode: countsMode)
        return mapped(.printBitmapRow, data: Utils.u16ToBytes(UInt16(pos)) + counts.parts + [repeatCount] + data)
    }

    /// Printer powers off if black pixel count > 6
    public static func printBitmapRowIndexed(
        _ pos: Int,
        _ repeatCount: UInt8,
        _ data: [UInt8],
        printheadPixels: Int,
        countsMode: CountsMode = .auto
    ) throws -> NiimbotPacket {
        let counts = Utils.countPixelsForBitmapPacket(data, printheadPixels: printheadPixels, mode: countsMode)
        let indexes = ImageEncoder.indexPixels(data)

        guard counts.total <= 6 else {
            throw PrintError(message: "Black pixel count > 6 (\(counts.total))", reasonId: 0)
        }

        return mapped(.printBitmapRowIndexed, data: Utils.u16ToBytes(UInt16(pos)) + counts.parts + [repeatCount] + indexes)
    }

    public static func printClear() -> NiimbotPacket {
        mapped(.printClear)
    }

    public static func writeRfid(_ data: [UInt8]) -> NiimbotPacket {
        mapped(.writeRFID, data: data)
    }

    public static func checkLine(_ line: Int) -> NiimbotPacket {
        mapped(.printerCheckLine, data: Utils.u16ToBytes(UInt16(line)) + [0x01])
    }

    /// Generate image data packets
    public static func writeImageData(_ image: EncodedImage, options: ImagePacketsGenerateOptions? = nil) -> [NiimbotPacket] {
        var out: [NiimbotPacket] = []

        for d in image.rowsData {
            switch d.dataType {
            case .pixels:
                if d.blackPixelsCount <= 6 && options?.noIndexPacket != true {
                    if let packet = try? printBitmapRowIndexed(
                        d.rowNumber,
                        UInt8(d.repeatCount),
                        d.rowData ?? [],
                        printheadPixels: options?.printheadPixels ?? 0,
                        countsMode: options?.countsMode ?? .auto
                    ) {
                        out.append(packet)
                    } else {
                        out.append(printBitmapRow(
                            d.rowNumber,
                            UInt8(d.repeatCount),
                            d.rowData ?? [],
                            printheadPixels: options?.printheadPixels ?? 0,
                            countsMode: options?.countsMode ?? .auto
                        ))
                    }
                } else {
                    out.append(printBitmapRow(
                        d.rowNumber,
                        UInt8(d.repeatCount),
                        d.rowData ?? [],
                        printheadPixels: options?.printheadPixels ?? 0,
                        countsMode: options?.countsMode ?? .auto
                    ))
                }
            case .check:
                if options?.enableCheckLine == true {
                    out.append(checkLine(d.rowNumber))
                }
            case .void:
                out.append(printEmptySpace(d.rowNumber, UInt8(d.repeatCount)))
            }
        }

        return out
    }

    public static func printTestPage() -> NiimbotPacket {
        mapped(.printTestPage)
    }

    public static func labelPositioningCalibration(_ value: UInt8) -> NiimbotPacket {
        mapped(.labelPositioningCalibration, data: [value])
    }

    public static func startFirmwareUpgrade(_ version: String) throws -> NiimbotPacket {
        guard let range = version.range(of: "^\\d+\\.\\d+$", options: .regularExpression) else {
            throw PrintError(message: "Invalid version format (x.x expected)", reasonId: 0)
        }
        let parts = version[range].split(separator: ".").map { Int($0)! }
        return mapped(.startFirmwareUpgrade, data: [UInt8(parts[0]), UInt8(parts[1])])
    }

    public static func sendFirmwareChecksum(_ crc: UInt32) -> NiimbotPacket {
        let p = NiimbotCrc32Packet(command: .firmwareCrc, chunkNumber: 0, data: Utils.u32ToBytes(crc))
        p.oneWay = true
        return p
    }

    public static func sendFirmwareChunk(_ idx: Int, _ data: [UInt8]) -> NiimbotPacket {
        let p = NiimbotCrc32Packet(command: .firmwareChunk, chunkNumber: idx, data: data)
        p.oneWay = true
        return p
    }

    public static func firmwareNoMoreChunks() -> NiimbotPacket {
        let p = NiimbotCrc32Packet(command: .firmwareNoMoreChunks, chunkNumber: 0, data: [1])
        p.oneWay = true
        return p
    }

    public static func firmwareCommit() -> NiimbotPacket {
        let p = NiimbotCrc32Packet(command: .firmwareCommit, chunkNumber: 0, data: [1])
        p.oneWay = true
        return p
    }
}

/// Options for image packet generation
public struct ImagePacketsGenerateOptions {
    public var countsMode: CountsMode
    public var noIndexPacket: Bool
    public var enableCheckLine: Bool
    public var printheadPixels: Int?

    public init(
        countsMode: CountsMode = .auto,
        noIndexPacket: Bool = false,
        enableCheckLine: Bool = false,
        printheadPixels: Int? = nil
    ) {
        self.countsMode = countsMode
        self.noIndexPacket = noIndexPacket
        self.enableCheckLine = enableCheckLine
        self.printheadPixels = printheadPixels
    }
}
