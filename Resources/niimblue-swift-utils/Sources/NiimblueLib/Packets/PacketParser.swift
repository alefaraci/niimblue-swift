import Foundation

/// Packet parser for raw data containing one or more packets
public enum PacketParser {
    /// Parse raw data containing one or more packets
    public static func parsePacketBundle(_ buf: [UInt8]) throws -> [NiimbotPacket] {
        var remaining = buf
        var chunks: [(cls: PacketType, raw: [UInt8])] = []

        while !remaining.isEmpty {
            guard Utils.hasSubarrayAtPos(remaining, NiimbotPacket.head, 0) else {
                break
            }

            guard remaining.count >= 3 else {
                break
            }

            let cmd = remaining[2]
            var cls: PacketType = .standard
            var sizePos = 3
            var crcSize = 1

            // Check if this is a firmware exchange packet
            let isFirmwarePacket = firmwareExchangePackets.rx.contains { $0.rawValue == Int(cmd) } ||
                                   firmwareExchangePackets.tx.contains { $0.rawValue == Int(cmd) }

            if isFirmwarePacket {
                cls = .crc32
                sizePos = 5
                crcSize = 4
            }

            guard remaining.count > sizePos else {
                break
            }

            let size = Int(remaining[sizePos])
            let tailPos = sizePos + size + crcSize + 1

            guard remaining.count > tailPos + NiimbotPacket.tail.count else {
                break
            }

            guard Utils.hasSubarrayAtPos(remaining, NiimbotPacket.tail, tailPos) else {
                print("Invalid tail")
                break
            }

            let tailEnd = tailPos + NiimbotPacket.tail.count
            chunks.append((cls, Array(remaining[0..<tailEnd])))
            remaining = Array(remaining[tailEnd...])
        }

        let chunksDataLen = chunks.reduce(0) { $0 + $1.raw.count }
        if buf.count != chunksDataLen {
            throw PrintError(message: "Split chunks data length not equals buffer length (\(buf.count) != \(chunksDataLen))", reasonId: 0)
        }

        return try chunks.map { chunk in
            switch chunk.cls {
            case .standard:
                return try NiimbotPacket.parse(chunk.raw)
            case .crc32:
                return try NiimbotCrc32Packet.parseCrc32(chunk.raw)
            }
        }
    }
}

private enum PacketType {
    case standard, crc32
}
