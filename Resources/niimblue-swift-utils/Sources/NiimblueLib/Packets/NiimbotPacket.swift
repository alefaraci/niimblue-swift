import Foundation

/// NIIMBOT packet object
public class NiimbotPacket: @unchecked Sendable {
    public static let head: [UInt8] = [0x55, 0x55]
    public static let tail: [UInt8] = [0xAA, 0xAA]

    private let _command: Int
    private let _data: [UInt8]
    private var _validResponseIds: [ResponseCommandId]?
    private var _oneWay: Bool

    public init(command: Int, data: [UInt8], validResponseIds: [ResponseCommandId]? = nil) {
        self._command = command
        self._data = data
        self._validResponseIds = validResponseIds
        self._oneWay = false
    }

    public convenience init(command: RequestCommandId, data: [UInt8], validResponseIds: [ResponseCommandId]? = nil) {
        self.init(command: command.rawValue, data: data, validResponseIds: validResponseIds)
    }

    public convenience init(command: ResponseCommandId, data: [UInt8], validResponseIds: [ResponseCommandId]? = nil) {
        self.init(command: command.rawValue, data: data, validResponseIds: validResponseIds)
    }

    /// Data length (header, command, dataLen, checksum, tail are excluded)
    public var dataLength: Int {
        _data.count
    }

    public var length: Int {
        Self.head.count + 1 + 1 + dataLength + 1 + Self.tail.count
    }

    public var oneWay: Bool {
        get { _oneWay }
        set { _oneWay = newValue }
    }

    public var validResponseIds: [ResponseCommandId]? {
        get { _validResponseIds }
        set { _validResponseIds = newValue }
    }

    public var command: Int {
        _command
    }

    public var data: [UInt8] {
        _data
    }

    public var checksum: UInt8 {
        var checksum: UInt8 = 0
        checksum ^= UInt8(_command & 0xFF)
        checksum ^= UInt8(_data.count & 0xFF)
        for byte in _data {
            checksum ^= byte
        }
        return checksum
    }

    /// Convert packet to bytes
    /// [0x55, 0x55, CMD, DATA_LEN, DATA..., CHECKSUM, 0xAA, 0xAA]
    public func toBytes() -> [UInt8] {
        var arr: [UInt8] = []
        arr.append(contentsOf: Self.head)
        arr.append(UInt8(_command & 0xFF))
        arr.append(UInt8(_data.count & 0xFF))
        arr.append(contentsOf: _data)
        arr.append(checksum)
        arr.append(contentsOf: Self.tail)

        // Connect command needs prefix 0x03
        if _command == RequestCommandId.connect.rawValue {
            return [0x03] + arr
        }
        return arr
    }

    /// Parse packet from bytes
    public static func parse(_ buf: [UInt8]) throws -> NiimbotPacket {
        let minPacketSize = head.count + 1 + 1 + 1 + tail.count

        guard buf.count >= minPacketSize else {
            throw PrintError(message: "Packet is too small (\(buf.count) < \(minPacketSize))", reasonId: 0)
        }

        let headBytes = Array(buf[0..<2])
        let tailBytes = Array(buf[buf.count - 2..<buf.count])

        guard Utils.u8ArraysEqual(headBytes, head) else {
            throw PrintError(message: "Invalid packet head", reasonId: 0)
        }

        guard Utils.u8ArraysEqual(tailBytes, tail) else {
            throw PrintError(message: "Invalid packet tail", reasonId: 0)
        }

        let cmd = Int(buf[2])
        let dataLen = Int(buf[3])

        guard buf.count == minPacketSize + dataLen else {
            throw PrintError(message: "Invalid packet size (\(buf.count) != \(minPacketSize + dataLen))", reasonId: 0)
        }

        let data = Array(buf[4..<(4 + dataLen)])
        let checksum = buf[4 + dataLen]

        let packet = NiimbotPacket(command: cmd, data: data)
        if packet.checksum != checksum {
            throw PrintError(message: "Invalid packet checksum (\(packet.checksum) != \(checksum))", reasonId: 0)
        }

        return packet
    }
}

/// NIIMBOT packet object with CRC32 checksum. Used in firmware process.
public final class NiimbotCrc32Packet: NiimbotPacket, @unchecked Sendable {
    private let _chunkNumber: Int

    public init(command: Int, chunkNumber: Int, data: [UInt8], validResponseIds: [ResponseCommandId]? = nil) {
        self._chunkNumber = chunkNumber
        super.init(command: command, data: data, validResponseIds: validResponseIds)
    }

    public convenience init(command: RequestCommandId, chunkNumber: Int, data: [UInt8], validResponseIds: [ResponseCommandId]? = nil) {
        self.init(command: command.rawValue, chunkNumber: chunkNumber, data: data, validResponseIds: validResponseIds)
    }

    public var chunkNumber: Int {
        _chunkNumber
    }

    /// Calculate CRC checksum from command and data
    public var crc32Checksum: Int32 {
        var dataToChecksum: [UInt8] = []
        dataToChecksum.append(UInt8(command & 0xFF))
        dataToChecksum.append(contentsOf: Utils.u16ToBytes(UInt16(_chunkNumber)))
        dataToChecksum.append(UInt8(data.count & 0xFF))
        dataToChecksum.append(contentsOf: data)
        return CRC32.calculate(dataToChecksum)
    }

    /// [0x55, 0x55, CMD, CHUNK_NUMBER, DATA_SIZE, DATA..., CRC32_CHECKSUM, 0xAA, 0xAA]
    public override func toBytes() -> [UInt8] {
        var arr: [UInt8] = []
        arr.append(contentsOf: Self.head)
        arr.append(UInt8(command & 0xFF))
        arr.append(contentsOf: Utils.u16ToBytes(UInt16(_chunkNumber)))
        arr.append(UInt8(data.count & 0xFF))
        arr.append(contentsOf: data)

        let crc = crc32Checksum
        arr.append(UInt8((crc >> 24) & 0xFF))
        arr.append(UInt8((crc >> 16) & 0xFF))
        arr.append(UInt8((crc >> 8) & 0xFF))
        arr.append(UInt8(crc & 0xFF))

        arr.append(contentsOf: Self.tail)
        return arr
    }

    /// Parse CRC32 packet from bytes
    public static func parseCrc32(_ buf: [UInt8]) throws -> NiimbotCrc32Packet {
        let minPacketSize = head.count + 1 + 2 + 1 + 4 + tail.count

        guard buf.count >= minPacketSize else {
            throw PrintError(message: "Packet is too small (\(buf.count) < \(minPacketSize))", reasonId: 0)
        }

        let headBytes = Array(buf[0..<2])
        let tailBytes = Array(buf[buf.count - 2..<buf.count])

        guard Utils.u8ArraysEqual(headBytes, head) else {
            throw PrintError(message: "Invalid packet head", reasonId: 0)
        }

        guard Utils.u8ArraysEqual(tailBytes, tail) else {
            throw PrintError(message: "Invalid packet tail", reasonId: 0)
        }

        let cmd = Int(buf[2])
        let chunkNumber = Int(Utils.bytesToI16(Array(buf[3..<5])))
        let dataLen = Int(buf[5])

        guard buf.count == minPacketSize + dataLen else {
            throw PrintError(message: "Invalid packet size (\(buf.count) != \(minPacketSize + dataLen))", reasonId: 0)
        }

        let data = Array(buf[6..<(6 + dataLen)])
        let checksum = Utils.bytesToI32(Array(buf[(6 + dataLen)..<(6 + dataLen + 4)]))

        let packet = NiimbotCrc32Packet(command: cmd, chunkNumber: chunkNumber, data: data)
        if packet.crc32Checksum != checksum {
            throw PrintError(message: "Invalid packet checksum (\(packet.crc32Checksum) != \(checksum))", reasonId: 0)
        }

        return packet
    }
}
