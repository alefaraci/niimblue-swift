import Foundation
import CoreGraphics
import ImageIO

public struct ImageRow: Sendable {
    public enum DataType: String, Sendable {
        case pixels = "pixels"
        case void = "void"
    }
    
    public let dataType: DataType
    public let rowNumber: Int
    public var repeatCount: Int
    public let rowData: [UInt8]?
    public let blackPixelsCount: Int
}

public struct EncodedImage: Sendable {
    public let cols: Int
    public let rows: Int
    public var rowsData: [ImageRow]
}

public enum PrintDirection: String, Sendable {
    case left = "left"
    case top = "top"
}

public class ImageEncoder {
    
    public static func encode(imagePath: String, printDirection: PrintDirection = .left) throws -> EncodedImage {
        let url = URL(fileURLWithPath: imagePath)
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
             throw NSError(domain: "ImageEncoder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"])
        }
        return encode(image: cgImage, printDirection: printDirection)
    }

    public static func encode(image: CGImage, printDirection: PrintDirection = .left) -> EncodedImage {
        let width = image.width
        let height = image.height
        
        // Convert to grayscale context
        let colorSpace = CGColorSpaceCreateDeviceGray()
        // Ensure context created successfully
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            fatalError("Failed to create graphics context")
        }
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelData = context.data else {
            fatalError("Failed to get pixel data")
        }
        
        let ptr = pixelData.bindMemory(to: UInt8.self, capacity: width * height)
        let buffer = UnsafeBufferPointer(start: ptr, count: width * height)
        
        var cols = width
        var rows = height
        
        if printDirection == .left {
            cols = height
            rows = width
        }
        
        // Check if cols is multiple of 8
        if cols % 8 != 0 {
             // For now just print warning or throw? 
             // Node code throws.
             print("Warning: Column count must be multiple of 8")
        }
        
        var rowsData: [ImageRow] = []
        
        for row in 0..<rows {
            var isVoid = true
            var blackPixelsCount = 0
            var rowData = [UInt8](repeating: 0, count: cols / 8)
            
            for colOct in 0..<(cols / 8) {
                var pixelsOctet: UInt8 = 0
                for colBit in 0..<8 {
                    if isPixelNonWhite(buffer: buffer, width: width, height: height, x: colOct * 8 + colBit, y: row, printDirection: printDirection) {
                        pixelsOctet |= 1 << (7 - colBit)
                        isVoid = false
                        blackPixelsCount += 1
                    }
                }
                rowData[colOct] = pixelsOctet
            }
            
            let newRow = ImageRow(
                dataType: isVoid ? .void : .pixels,
                rowNumber: row,
                repeatCount: 1,
                rowData: isVoid ? nil : rowData,
                blackPixelsCount: blackPixelsCount
            )
            
            if rowsData.isEmpty {
                rowsData.append(newRow)
            } else {
                var lastRow = rowsData[rowsData.count - 1]
                var same = newRow.dataType == lastRow.dataType
                
                if same && newRow.dataType == .pixels {
                    same = newRow.rowData == lastRow.rowData
                }
                
                if same {
                    lastRow.repeatCount += 1
                    rowsData[rowsData.count - 1] = lastRow
                } else {
                    rowsData.append(newRow)
                }
            }
        }
        
        return EncodedImage(cols: cols, rows: rows, rowsData: rowsData)
    }
    
    private static func isPixelNonWhite(buffer: UnsafeBufferPointer<UInt8>, width: Int, height: Int, x: Int, y: Int, printDirection: PrintDirection) -> Bool {
        var idx = y * width + x

        if printDirection == .left {
            idx = (height - 1 - x) * width + y
        }
        
        // Bounds check
        if idx < 0 || idx >= buffer.count {
            return false
        }
        
        // In grayscale, 255 is white, 0 is black.
        // We consider non-white as black (dithering should be done before if needed).
        // The node code checks !== 0xff (255).
        return buffer[idx] != 0xff
    }
}
