import Foundation

public struct NiimbotPacket: Sendable {
    public static let HEAD: [UInt8] = [0x55, 0x55]
    public static let TAIL: [UInt8] = [0xaa, 0xaa]

    public let command: UInt8
    public let data: [UInt8]

    public init(command: UInt8, data: [UInt8] = [0x01]) {
        self.command = command
        self.data = data
    }

    public var checksum: UInt8 {
        var cs: UInt8 = 0
        cs ^= command
        cs ^= UInt8(data.count)
        for byte in data {
            cs ^= byte
        }
        return cs
    }

    public func toBytes() -> [UInt8] {
        var packet: [UInt8] = []
        packet.append(contentsOf: NiimbotPacket.HEAD)
        packet.append(command)
        packet.append(UInt8(data.count))
        packet.append(contentsOf: data)
        packet.append(checksum)
        packet.append(contentsOf: NiimbotPacket.TAIL)

        return packet
    }
    
    public static func fromBytes(_ bytes: [UInt8]) -> NiimbotPacket? {
        guard bytes.count >= 7 else { return nil }
        
        // Head check
        guard bytes[0] == 0x55, bytes[1] == 0x55 else { return nil }
        
        let cmd = bytes[2]
        let len = Int(bytes[3])
        
        guard bytes.count == 2 + 1 + 1 + len + 1 + 2 else { return nil }
        
        let data = Array(bytes[4..<(4+len)])
        let checksum = bytes[4+len]
        
        // Tail check
        guard bytes[4+len+1] == 0xaa, bytes[4+len+2] == 0xaa else { return nil }
        
        let packet = NiimbotPacket(command: cmd, data: data)
        
        if packet.checksum != checksum {
            return nil
        }
        
        return packet
    }
}
