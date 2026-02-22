import Foundation

public class PacketParser {
    private var buffer: [UInt8] = []
    
    public init() {}
    
    public func append(_ data: [UInt8]) -> [NiimbotPacket] {
        buffer.append(contentsOf: data)
        var packets: [NiimbotPacket] = []
        
        while true {
            guard let firstHead = buffer.firstIndex(of: 0x55) else {
                buffer.removeAll()
                break
            }
            
            // Remove garbage before head
            if firstHead > 0 {
                buffer.removeFirst(firstHead)
            }
            
            // Ensure at least 2 bytes for HEAD
            if buffer.count < 2 {
                break
            }
            
            if buffer[1] != 0x55 {
                // Not a valid head, remove first byte and retry
                buffer.removeFirst()
                continue
            }
            
            // Ensure min packet size (HEAD:2, CMD:1, LEN:1, CS:1, TAIL:2) -> 7
            if buffer.count < 7 {
                break
            }
            
            let dataLen = Int(buffer[3])
            let packetLen = 2 + 1 + 1 + dataLen + 1 + 2
            
            if buffer.count < packetLen {
                break // Wait for more data
            }
            
            // Extract potential packet
            let packetBytes = Array(buffer[0..<packetLen])
            
            if let packet = NiimbotPacket.fromBytes(packetBytes) {
                packets.append(packet)
                buffer.removeFirst(packetLen)
            } else {
                // Invalid packet (checksum or tail), skip head and try again
                buffer.removeFirst(2)
            }
        }
        
        return packets
    }
}
