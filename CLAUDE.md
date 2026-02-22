# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Run Commands

```bash
# Build the project
swift build

# Run CLI with help
swift run niimblue-cli --help

# Scan for BLE printers
swift run niimblue-cli scan --timeout 5

# Get printer info
swift run niimblue-cli info --address "PrinterName"

# Print an image
swift run niimblue-cli print <image_path> --address "PrinterName" --density 3 --quantity 1
```

## Architecture Overview

This is a Swift port of niimblue-node for communicating with Niimbot thermal label printers via BLE (Serial transport planned but not implemented).

### Layer Structure

```
niimblue-cli (CLI using ArgumentParser)
    │
    ▼
NiimbotClient (Main client - @MainActor class)
    │  - Manages connection state and request/response matching
    │  - Sends packets via transport, waits for responses with timeout
    │  - Implements print workflow (density, label type, page start/end, bitmap rows)
    │
    ▼
Transport Protocol (BLETransport implementation)
    │  - Abstract interface: connect(), disconnect(), send(data:)
    │  - Delegate pattern for incoming data
    │
    ▼
Packet Layer (NiimbotPacket, PacketGenerator, PacketParser)
    │  - Binary protocol: [0x55, 0x55, CMD, LEN, DATA..., CHECKSUM, 0xAA, 0xAA]
    │  - Checksum = XOR of CMD + LEN + all DATA bytes
```

### Key Files

| File | Purpose |
|------|---------|
| `Sources/niimblue-cli/main.swift` | CLI entry point with scan/info/print subcommands |
| `Sources/NiimblueLib/Core/NiimbotClient.swift` | Main client handling connection, packet matching, print workflow |
| `Sources/NiimblueLib/Core/Transport.swift` | Transport protocol and delegate definitions |
| `Sources/NiimblueLib/Core/BLETransport.swift` | CoreBluetooth BLE implementation |
| `Sources/NiimblueLib/Packets/NiimbotPacket.swift` | Packet structure, serialization, and parsing |
| `Sources/NiimblueLib/Packets/PacketGenerator.swift` | Factory methods for command packets |
| `Sources/NiimblueLib/Packets/Commands.swift` | RequestCommandId, ResponseCommandId enums, CommandsMap |
| `Sources/NiimblueLib/ImageEncoder.swift` | Converts CGImage to EncodedImage with row compression |

### Concurrency Model

- `BLETransport` is `@MainActor` isolated (CoreBluetooth requires main thread)
- `NiimbotClient` is `@MainActor` isolated to coordinate with transport
- Uses `CheckedContinuation` for async connect/send operations
- 20ms throttling between packets to prevent BLE flooding

### Print Workflow

1. `initialNegotiate()` - Send Connect (0xC1) and PrinterInfo (0x40) packets
2. `print()` - Set density/label type, PrintStart, PageStart, SetPageSize, bitmap rows, PageEnd, PrintEnd
3. Bitmap rows use `PrintBitmapRow` (0x85) for pixel data, `PrintEmptyRow` (0x84) for void rows
4. Row compression merges consecutive identical rows via `repeatCount`

### Protocol Notes

- Commands map to responses via `CommandsMap.requestToResponse`
- Some commands (PrintBitmapRow, PrintEmptyRow) have no response
- Heartbeat responses (0xDD-0xDF) are unsolicited
- Printer targets B1 series (uses `printStart7b` and `setPageSize6b` variants)

## Reference Resources

The `Resources/` directory contains reference implementations and documentation:

| Directory | Contents |
|-----------|----------|
| `niimblue-node/` | Original Node.js CLI reference implementation (src/cli/, src/client/) |
| `niimbluelib/` | TypeScript library with print tasks (B1, D110, B21, OldD11), packet handling, BLE/Serial clients |
| `niimbot-wiki/` | Protocol documentation: packet formats, command IDs, print task sequences, hardware specs |
| `niimblue-swift-utils/` | Alternative Swift implementation with SerialTransport, CRC32, PrintTasks, PrinterModels |

### Key Reference Files

- `Resources/niimbot-wiki/docs/interfacing/proto.md` - Packet structure, command IDs, checksum calculation
- `Resources/niimbot-wiki/docs/interfacing/print-tasks.md` - Print sequences for D11, B21, D110, B1, D110M_V4
- `Resources/niimbluelib/src/print_tasks/` - Print task implementations per printer model
- `Resources/niimblue-swift-utils/Sources/NiimblueLib/Transports/SerialTransport.swift` - Serial transport reference
