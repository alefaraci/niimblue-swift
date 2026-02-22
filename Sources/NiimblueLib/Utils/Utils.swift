import Foundation

public struct Utils {
    
    public static func u16ToBytes(_ val: UInt16) -> [UInt8] {
        return [
            UInt8((val >> 8) & 0xff),
            UInt8(val & 0xff)
        ]
    }
    
    public static func countPixelsForBitmapPacket(buf: [UInt8], printheadPixels: Int) -> (total: Int, parts: [UInt8]) {
        var total = 0
        var parts: [Int] = [0, 0, 0]
        let chunkSize = Int(floor(Double(printheadPixels) / 8.0 / 3.0))
        let split = chunkSize > 0 && buf.count <= chunkSize * 3
        
        for (byteN, value) in buf.enumerated() {
            let chunkIdx = (split && chunkSize > 0) ? byteN / chunkSize : 0
            
            for bitN in 0..<8 {
                if (value & (1 << bitN)) != 0 {
                    total += 1
                    if split && chunkIdx <= 2 {
                        parts[chunkIdx] += 1
                    }
                }
            }
        }
        
        if split {
            return (total: total, parts: parts.map { UInt8($0) })
        } else {
            let bytes = Utils.u16ToBytes(UInt16(total))
            // Node: [0, l, h] (Little Endian for total)
            return (total: total, parts: [0, bytes[1], bytes[0]])
        }
    }
    
    public static func hexToBuf(_ str: String) -> [UInt8] {
        var data = [UInt8]()
        var index = str.startIndex
        while index < str.endIndex {
            let nextIndex = str.index(index, offsetBy: 2)
            if let byte = UInt8(str[index..<nextIndex], radix: 16) {
                data.append(byte)
            }
            index = nextIndex
        }
        return data
    }
    
    public static func bufToHex(_ buf: [UInt8]) -> String {
        return buf.map { String(format: "%02x", $0) }.joined(separator: " ")
    }
}
