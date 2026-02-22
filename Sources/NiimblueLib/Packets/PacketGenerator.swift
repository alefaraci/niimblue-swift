import Foundation

public struct PacketGenerator {
    
    public static func connect() -> NiimbotPacket {
        return NiimbotPacket(command: RequestCommandId.Connect.rawValue, data: [1])
    }
    
    public static func printerInfo(type: UInt8) -> NiimbotPacket {
        return NiimbotPacket(command: RequestCommandId.PrinterInfo.rawValue, data: [type])
    }
    
    public static func setDensity(value: UInt8) -> NiimbotPacket {
        return NiimbotPacket(command: RequestCommandId.SetDensity.rawValue, data: [value])
    }
    
    public static func setLabelType(value: UInt8) -> NiimbotPacket {
        return NiimbotPacket(command: RequestCommandId.SetLabelType.rawValue, data: [value])
    }
    
    public static func setPageSize(rows: UInt16, cols: UInt16) -> NiimbotPacket {
        let rowsBytes = Utils.u16ToBytes(rows)
        let colsBytes = Utils.u16ToBytes(cols)
        return NiimbotPacket(command: RequestCommandId.SetPageSize.rawValue, data: rowsBytes + colsBytes)
    }
    
    public static func setPageSize6b(rows: UInt16, cols: UInt16, copies: UInt16) -> NiimbotPacket {
        let rowsBytes = Utils.u16ToBytes(rows)
        let colsBytes = Utils.u16ToBytes(cols)
        let copiesBytes = Utils.u16ToBytes(copies)
        return NiimbotPacket(command: RequestCommandId.SetPageSize.rawValue, data: rowsBytes + colsBytes + copiesBytes)
    }
    
    public static func setPrintQuantity(quantity: UInt16) -> NiimbotPacket {
        return NiimbotPacket(command: RequestCommandId.PrintQuantity.rawValue, data: Utils.u16ToBytes(quantity))
    }
    
    public static func printStart() -> NiimbotPacket {
        return NiimbotPacket(command: RequestCommandId.PrintStart.rawValue, data: [1])
    }
    
    public static func printStart7b(total: UInt16, color: UInt8 = 0) -> NiimbotPacket {
        let totalBytes = Utils.u16ToBytes(total)
        let data: [UInt8] = totalBytes + [0x00, 0x00, 0x00, 0x00, color]
        return NiimbotPacket(command: RequestCommandId.PrintStart.rawValue, data: data)
    }
    
    public static func printEnd() -> NiimbotPacket {
        return NiimbotPacket(command: RequestCommandId.PrintEnd.rawValue, data: [1])
    }
    
    public static func pageStart() -> NiimbotPacket {
        return NiimbotPacket(command: RequestCommandId.PageStart.rawValue, data: [1])
    }
    
    public static func pageEnd() -> NiimbotPacket {
        return NiimbotPacket(command: RequestCommandId.PageEnd.rawValue, data: [1])
    }
    
    public static func printStatus() -> NiimbotPacket {
        return NiimbotPacket(command: RequestCommandId.PrintStatus.rawValue, data: [1])
    }

    public static func printClear() -> NiimbotPacket {
        return NiimbotPacket(command: RequestCommandId.PrintClear.rawValue, data: [1])
    }
    
    public static func printEmptyRow(pos: UInt16, repeats: UInt8) -> NiimbotPacket {
        return NiimbotPacket(command: RequestCommandId.PrintEmptyRow.rawValue, data: Utils.u16ToBytes(pos) + [repeats])
    }
    
    public static func printBitmapRow(pos: UInt16, repeats: UInt8, data: [UInt8], printheadPixels: Int) -> NiimbotPacket {
        let counts = Utils.countPixelsForBitmapPacket(buf: data, printheadPixels: printheadPixels)
        return NiimbotPacket(command: RequestCommandId.PrintBitmapRow.rawValue, data: Utils.u16ToBytes(pos) + counts.parts + [repeats] + data)
    }
    
     public static func printBitmapRowIndexed(pos: UInt16, repeats: UInt8, data: [UInt8], printheadPixels: Int) -> NiimbotPacket {
         // Placeholder: We just use normal printBitmapRow for now as indexPixels logic is not ported yet.
         // And B1/D110 can handle non-indexed packets too.
         return printBitmapRow(pos: pos, repeats: repeats, data: data, printheadPixels: printheadPixels)
    }
}
