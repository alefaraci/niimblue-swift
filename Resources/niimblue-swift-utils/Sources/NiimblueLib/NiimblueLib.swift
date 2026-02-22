// NiimblueLib - Swift library for Niimbot thermal label printers

// Core
@_exported import Foundation

// Packets
public typealias RequestCommand = RequestCommandId
public typealias ResponseCommand = ResponseCommandId

// Re-export main types
public typealias Packet = NiimbotPacket
public typealias Crc32Packet = NiimbotCrc32Packet
public typealias Client = NiimbotAbstractClient
public typealias BLEClient = NiimbotBleClient
public typealias SerialClient = NiimbotSerialClient

// Print task names for easy access
public let printTaskNames = ["D110", "B1", "B21", "D110_MV4", "OldD11"]
