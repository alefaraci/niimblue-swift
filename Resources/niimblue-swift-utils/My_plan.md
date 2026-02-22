
 Here is the plan:
╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
 Plan: Port niimblue-node to Swift CLI

 Context

 The user wants to port niimblue-node (a Node.js library for Niimbot thermal label printers) to a Swift command-line application. This
 involves implementing:
 - Binary protocol communication with Niimbot printers
 - BLE and Serial transport layers
 - Image encoding for thermal printing
 - CLI with print, scan, info, and firmware flash commands

 Architecture Overview

 +-----------------------------------------------------------------------------------+
 |                              niimblue-cli (Executable)                            |
 |  +-------------+  +-------------+  +-------------+  +-------------+  +----------+ |
 |  |   info      |  |    scan     |  |   print     |  |   flash     |  |  server  | |
 |  +------+------+  +------+------+  +------+------+  +------+------+  +----------+ |
 +---------|----------------|----------------|----------------|-----------------------+
           |                |                |                |
           v                v                v                v
 +-----------------------------------------------------------------------------------+
 |                                NiimblueLib (Library)                              |
 |  +-----------------------------------------------------------------------------+ |
 |  |                       NiimbotAbstractClient (actor)                         | |
 |  |  - connect()/disconnect()  - sendPacketWaitResponse()  - heartbeat         | |
 |  +-----------------------------------------------------------------------------+ |
 |          +-------------------------+-------------------------+                   |
 |          |                                                   |                   |
 |  +-------v-------+                                   +-------v-------+           |
 |  | BLETransport  |                                   | SerialTransport|           |
 |  | (CoreBluetooth)|                                  | (ORSSerialPort)|           |
 |  +---------------+                                   +----------------+           |
 |  +-----------------------------------------------------------------------------+ |
 |  |  Packets Layer: NiimbotPacket, PacketGenerator, PacketParser, CommandsMap   | |
 |  +-----------------------------------------------------------------------------+ |
 |  +-----------------------------------------------------------------------------+ |
 |  |  Print Tasks: AbstractPrintTask, D110PrintTask, B1PrintTask, B21PrintTask   | |
 |  +-----------------------------------------------------------------------------+ |
 |  +-----------------------------+  +------------------------------------------+   |
 |  |      ImageEncoder           |  |          PrinterModels                   |   |
 |  +-----------------------------+  +------------------------------------------+   |
 +-----------------------------------------------------------------------------------+

 File Structure

 niimblue-swift/
 ├── Package.swift
 └── Sources/
     ├── NiimblueLib/
     │   ├── NiimblueLib.swift              # Public exports
     │   ├── Core/
     │   │   ├── NiimbotClient.swift        # Abstract client (actor)
     │   │   ├── Transport.swift            # Transport protocol
     │   │   └── Events.swift               # Event types
     │   ├── Transports/
     │   │   ├── BLETransport.swift         # CoreBluetooth implementation
     │   │   └── SerialTransport.swift      # ORSSerialPort implementation
     │   ├── Packets/
     │   │   ├── Commands.swift             # Request/Response command IDs
     │   │   ├── NiimbotPacket.swift        # Standard + CRC32 packets
     │   │   ├── PacketParser.swift         # Parse bytes to packets
     │   │   ├── PacketGenerator.swift      # Factory for all packets
     │   │   ├── CommandsMap.swift          # Request-to-response mapping
     │   │   └── DTOs.swift                 # PrintStatus, HeartbeatData, etc.
     │   ├── PrintTasks/
     │   │   ├── AbstractPrintTask.swift    # Base class
     │   │   ├── D110PrintTask.swift        # D110/D11 series
     │   │   ├── B1PrintTask.swift          # B1 series
     │   │   ├── B21PrintTask.swift         # B21 series
     │   │   └── PrintTaskRegistry.swift    # Model-to-task mapping
     │   ├── Image/
     │   │   └── ImageEncoder.swift         # CGImage to 1-bit bitmap
     │   ├── Models/
     │   │   └── PrinterModels.swift        # Printer metadata library
     │   └── Utils/
     │       ├── Utils.swift                # Byte manipulation
     │       └── CRC32.swift                # CRC32 implementation
     └── niimblue-cli/
         └── main.swift                     # ArgumentParser commands

 Protocol Summary

 Packet Format

 Basic: [0x55, 0x55, CMD, DATA_LEN, DATA..., CHECKSUM, 0xAA, 0xAA]
 CRC32: [0x55, 0x55, CMD, CHUNK_NUM, DATA_LEN, DATA..., CRC32, 0xAA, 0xAA]
 - Checksum = XOR of CMD + DATA_LEN + all DATA bytes
 - CRC32 = CRC32 of CMD + CHUNK_NUM + DATA_LEN + DATA

 Key Commands

 ┌────────────────┬─────┬─────────────┐
 │    Command     │ ID  │ Response ID │
 ├────────────────┼─────┼─────────────┤
 │ Connect        │ 193 │ 194         │
 ├────────────────┼─────┼─────────────┤
 │ PrintStart     │ 1   │ 2           │
 ├────────────────┼─────┼─────────────┤
 │ PrintEnd       │ 243 │ 244         │
 ├────────────────┼─────┼─────────────┤
 │ PageStart      │ 3   │ 4           │
 ├────────────────┼─────┼─────────────┤
 │ PageEnd        │ 227 │ -           │
 ├────────────────┼─────┼─────────────┤
 │ PrintBitmapRow │ 133 │ -           │
 ├────────────────┼─────┼─────────────┤
 │ PrintEmptyRow  │ 132 │ -           │
 ├────────────────┼─────┼─────────────┤
 │ Heartbeat      │ 220 │ 221-223     │
 ├────────────────┼─────┼─────────────┤
 │ PrinterInfo    │ 64  │ 64          │
 └────────────────┴─────┴─────────────┘

 Swift Dependencies

 ┌───────────────────┬─────────────────────────┐
 │      Node.js      │          Swift          │
 ├───────────────────┼─────────────────────────┤
 │ @stoprocent/noble │ CoreBluetooth (native)  │
 ├───────────────────┼─────────────────────────┤
 │ serialport        │ ORSSerialPort           │
 ├───────────────────┼─────────────────────────┤
 │ async-mutex       │ Swift actor isolation   │
 ├───────────────────┼─────────────────────────┤
 │ sharp             │ CGImage / Core Graphics │
 ├───────────────────┼─────────────────────────┤
 │ commander         │ ArgumentParser          │
 ├───────────────────┼─────────────────────────┤
 │ eventemitter3     │ AsyncStream             │
 └───────────────────┴─────────────────────────┘

 User Requirements

 - Transports: Both BLE and Serial
 - Server Mode: Not needed - CLI only
 - Printer Model: B1 series (prioritize B1PrintTask)

 Implementation Phases

 Phase 1: Core Protocol Layer

 - Complete NiimbotPacket with checksum calculation
 - Add NiimbotCrc32Packet for firmware updates
 - Complete PacketGenerator with all packet types
 - Implement CommandsMap for request-response mapping
 - Add DTOs: PrintStatus, HeartbeatData, PrinterInfo, RfidInfo

 Phase 2: Transport Layer

 - Complete BLETransport using CoreBluetooth
 - Implement SerialTransport using ORSSerialPort
 - Add scan functionality for both transports

 Phase 3: Abstract Client

 - Implement NiimbotAbstractClient as Swift actor
 - Add mutex-protected packet sending
 - Implement heartbeat mechanism
 - Add event emission via AsyncStream
 - Implement timeout handling

 Phase 4: Print Tasks (B1 series prioritized)

 - Create AbstractPrintTask base class
 - Implement B1PrintTask (primary target for B1 series)
 - Implement D110PrintTask (for broader compatibility)
 - Create PrintTaskRegistry for model mapping

 Phase 5: Image Encoding

 - Implement threshold-based black/white conversion
 - Add row compression for identical rows
 - Support both print directions (left/top)
 - Handle indexed mode for sparse rows

 Phase 6: Printer Models

 - Port printer model metadata library
 - Add DPI, direction, density range info
 - Implement model lookup functions

 Phase 7: CLI

 - Implement info command
 - Implement scan command
 - Implement print command with all options
 - Implement flash command for firmware

 Key Files to Reference

 ┌───────────────────────────────────────────────────────────────────┬────────────────────────────┐
 │                              Source                               │          Purpose           │
 ├───────────────────────────────────────────────────────────────────┼────────────────────────────┤
 │ node_modules/@mmote/niimbluelib/dist/cjs/packets/packet.d.ts      │ Packet structure           │
 ├───────────────────────────────────────────────────────────────────┼────────────────────────────┤
 │ node_modules/@mmote/niimbluelib/dist/cjs/packets/abstraction.d.ts │ Abstraction API            │
 ├───────────────────────────────────────────────────────────────────┼────────────────────────────┤
 │ node_modules/@mmote/niimbluelib/dist/cjs/print_tasks/*.ts         │ Print task implementations │
 ├───────────────────────────────────────────────────────────────────┼────────────────────────────┤
 │ node_modules/@mmote/niimbluelib/dist/cjs/printer_models.d.ts      │ Printer metadata           │
 ├───────────────────────────────────────────────────────────────────┼────────────────────────────┤
 │ src/client/headless_ble_impl.ts                                   │ BLE transport reference    │
 ├───────────────────────────────────────────────────────────────────┼────────────────────────────┤
 │ src/client/headless_serial_impl.ts                                │ Serial transport reference │
 ├───────────────────────────────────────────────────────────────────┼────────────────────────────┤
 │ src/image_encoder.ts                                              │ Image encoding logic       │
 ├───────────────────────────────────────────────────────────────────┼────────────────────────────┤
 │ src/cli/index.ts                                                  │ CLI command structure      │
 └───────────────────────────────────────────────────────────────────┴────────────────────────────┘

 Verification

 After implementation, test with:
 1. Unit tests: Packet encoding/decoding, checksums, CRC32
 2. Scan test: niimblue-cli scan --transport ble should discover printers
 3. Info test: niimblue-cli info --transport ble --address <MAC> should show printer info
 4. Print test: niimblue-cli print image.png --transport ble --address <MAC> should print
 5. Serial test: Same commands with --transport serial --address /dev/tty.usbmodem*

 Estimated Scope

 - ~3,000-4,000 lines of Swift code
 - 6 phases over approximately 6 weeks for full implementation
 - MVP (BLE + basic print) could be done in ~2 weeks
╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌