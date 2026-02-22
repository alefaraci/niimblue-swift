import Foundation
import CoreGraphics
import ImageIO

/// Image row data type
public enum ImageRowDataType: Sendable {
    case void
    case pixels
    case check
}

/// Encoded image row
public struct ImageRow: Sendable {
    public let dataType: ImageRowDataType
    public let rowNumber: Int
    public let repeatCount: Int
    public let rowData: [UInt8]?
    public let blackPixelsCount: Int

    public init(dataType: ImageRowDataType, rowNumber: Int, repeatCount: Int, rowData: [UInt8]?, blackPixelsCount: Int) {
        self.dataType = dataType
        self.rowNumber = rowNumber
        self.repeatCount = repeatCount
        self.rowData = rowData
        self.blackPixelsCount = blackPixelsCount
    }
}

/// Encoded image
public struct EncodedImage: Sendable {
    public let cols: Int
    public let rows: Int
    public let rowsData: [ImageRow]

    public init(cols: Int, rows: Int, rowsData: [ImageRow]) {
        self.cols = cols
        self.rows = rows
        self.rowsData = rowsData
    }
}

/// Image encoder for thermal printing
public enum ImageEncoder {
    /// Encode CGImage to thermal printer format
    public static func encodeImage(_ image: CGImage, printDirection: PrintDirection = .left, threshold: UInt8 = 128) -> EncodedImage {
        let width = image.width
        let height = image.height
        let colorSpace = CGColorSpaceCreateDeviceGray()

        var cols = width
        var rows = height

        if printDirection == .left {
            cols = height
            rows = width
        }

        // Ensure cols is multiple of 8
        let alignedCols = ((cols + 7) / 8) * 8

        // Create grayscale context
        guard let context = CGContext(
            data: nil,
            width: alignedCols,
            height: rows,
            bitsPerComponent: 8,
            bytesPerRow: alignedCols,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return EncodedImage(cols: 0, rows: 0, rowsData: [])
        }

        // Fill with white
        context.setFillColor(CGColor(gray: 1.0, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: alignedCols, height: rows))

        // Draw image
        if printDirection == .left {
            // Rotate 90 degrees clockwise
            context.translateBy(x: CGFloat(alignedCols), y: 0)
            context.rotate(by: CGFloat.pi / 2)
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Get pixel data
        guard let data = context.data else {
            return EncodedImage(cols: 0, rows: 0, rowsData: [])
        }

        let pixels = data.assumingMemoryBound(to: UInt8.self)

        var rowsData: [ImageRow] = []

        for row in 0..<rows {
            var isVoid = true
            var blackPixelsCount = 0
            var rowData = [UInt8](repeating: 0, count: alignedCols / 8)

            for colOct in 0..<(alignedCols / 8) {
                var pixelsOctet: UInt8 = 0
                for colBit in 0..<8 {
                    let col = colOct * 8 + colBit
                    if col < cols {
                        let pixelIdx = row * alignedCols + col
                        let pixelValue = pixels[pixelIdx]

                        // Black if below threshold
                        if pixelValue < threshold {
                            pixelsOctet |= 1 << (7 - colBit)
                            isVoid = false
                            blackPixelsCount += 1
                        }
                    }
                }
                rowData[colOct] = pixelsOctet
            }

            let newPart = ImageRow(
                dataType: isVoid ? .void : .pixels,
                rowNumber: row,
                repeatCount: 1,
                rowData: isVoid ? nil : rowData,
                blackPixelsCount: blackPixelsCount
            )

            // Check if same as previous row
            if let lastPacket = rowsData.last {
                var same = newPart.dataType == lastPacket.dataType

                if same && newPart.dataType == .pixels {
                    same = newPart.rowData == lastPacket.rowData
                }

                if same {
                    // Increment repeat count by creating new row
                    let updatedRow = ImageRow(
                        dataType: lastPacket.dataType,
                        rowNumber: lastPacket.rowNumber,
                        repeatCount: lastPacket.repeatCount + 1,
                        rowData: lastPacket.rowData,
                        blackPixelsCount: lastPacket.blackPixelsCount
                    )
                    rowsData[rowsData.count - 1] = updatedRow
                } else {
                    rowsData.append(newPart)
                }
            } else {
                rowsData.append(newPart)
            }
        }

        return EncodedImage(cols: alignedCols, rows: rows, rowsData: rowsData)
    }

    /// Load image from file
    public static func loadImage(from url: URL) throws -> CGImage {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw PrintError(message: "Failed to load image from \(url.path)", reasonId: 0)
        }
        return image
    }

    /// Index pixels for sparse rows
    /// Returns array of indexes where every index stored in two bytes (big endian)
    public static func indexPixels(_ data: [UInt8]) -> [UInt8] {
        var indexes: [UInt8] = []

        for (byteIdx, byte) in data.enumerated() {
            for bitIdx in 0..<8 {
                if (byte & (1 << bitIdx)) != 0 {
                    let pixelIdx = byteIdx * 8 + (7 - bitIdx)
                    indexes.append(UInt8(pixelIdx >> 8))
                    indexes.append(UInt8(pixelIdx & 0xFF))
                }
            }
        }

        return indexes
    }
}
