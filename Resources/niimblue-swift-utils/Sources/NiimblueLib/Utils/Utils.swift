import Foundation

/// Utility functions for byte manipulation
public enum Utils {
    /// Convert a byte to hex string
    public static func byteToHex(_ byte: UInt8) -> String {
        String(format: "%02X", byte)
    }

    /// Convert a byte array to hex string
    public static func bufToHex(_ buf: [UInt8], separator: String = " ") -> String {
        buf.map { byteToHex($0) }.joined(separator: separator)
    }

    /// Convert hex string to byte array
    public static func hexToBuf(_ hex: String) -> [UInt8] {
        let clean = hex.replacingOccurrences(of: " ", with: "")
        var result: [UInt8] = []
        var i = clean.startIndex
        while i < clean.endIndex {
            let next = clean.index(i, offsetBy: 2, limitedBy: clean.endIndex) ?? clean.endIndex
            if let byte = UInt8(clean[i..<next], radix: 16) {
                result.append(byte)
            }
            i = next
        }
        return result
    }

    /// Convert 16-bit integer to bytes (big endian)
    public static func u16ToBytes(_ n: UInt16) -> [UInt8] {
        [UInt8(n >> 8), UInt8(n & 0xFF)]
    }

    /// Convert 32-bit integer to bytes (big endian)
    public static func u32ToBytes(_ n: UInt32) -> [UInt8] {
        [
            UInt8((n >> 24) & 0xFF),
            UInt8((n >> 16) & 0xFF),
            UInt8((n >> 8) & 0xFF),
            UInt8(n & 0xFF)
        ]
    }

    /// Convert bytes to 16-bit integer (big endian)
    public static func bytesToI16(_ arr: [UInt8]) -> Int16 {
        guard arr.count >= 2 else { return 0 }
        return Int16(arr[0]) << 8 | Int16(arr[1])
    }

    /// Convert bytes to 32-bit integer (big endian)
    public static func bytesToI32(_ arr: [UInt8]) -> Int32 {
        guard arr.count >= 4 else { return 0 }
        return (Int32(arr[0]) << 24) | (Int32(arr[1]) << 16) | (Int32(arr[2]) << 8) | Int32(arr[3])
    }

    /// Check if two byte arrays are equal
    public static func u8ArraysEqual(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        a == b
    }

    /// Append data to a byte array
    public static func u8ArrayAppend(_ src: [UInt8], _ data: [UInt8]) -> [UInt8] {
        src + data
    }

    /// Check if array has subarray at position
    public static func hasSubarrayAtPos(_ arr: [UInt8], _ sub: [UInt8], _ pos: Int) -> Bool {
        guard pos + sub.count <= arr.count else { return false }
        for i in 0..<sub.count {
            if arr[pos + i] != sub[i] {
                return false
            }
        }
        return true
    }

    /// Count pixels for bitmap packet
    public static func countPixelsForBitmapPacket(
        _ buf: [UInt8],
        printheadPixels: Int,
        mode: CountsMode = .auto
    ) -> (total: Int, parts: [UInt8]) {
        var total = 0
        var parts: [UInt8] = [0, 0, 0]
        let chunkSize = printheadPixels / 8 / 3
        var split = buf.count <= chunkSize * 3

        switch mode {
        case .total:
            split = false
        case .split:
            split = buf.count <= chunkSize * 3
        case .auto:
            break
        }

        for byteN in 0..<buf.count {
            let chunkIdx = byteN / chunkSize
            let value = buf[byteN]
            for bitN in 0..<8 {
                if (value & (1 << bitN)) != 0 {
                    total += 1
                    if split && chunkIdx < 3 {
                        parts[chunkIdx] += 1
                    }
                }
            }
        }

        if split {
            return (total, parts)
        }

        let (h, l) = (UInt8(total >> 8), UInt8(total & 0xFF))
        return (total, [0, l, h])
    }
}

public enum CountsMode {
    case auto, split, total
}
