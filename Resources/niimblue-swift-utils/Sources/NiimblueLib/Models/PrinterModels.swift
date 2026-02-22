import Foundation

/// Print direction
public enum PrintDirection: String, Sendable, Codable {
    case left
    case top
}

/// Printer model
public enum PrinterModel: String, Sendable, Codable, CaseIterable {
    case unknown = "UNKNOWN"
    case a20 = "A20"
    case a203 = "A203"
    case a63 = "A63"
    case a8 = "A8"
    case a8_P = "A8_P"
    case b1 = "B1"
    case b1_PRO = "B1_PRO"
    case b11 = "B11"
    case b16 = "B16"
    case b18 = "B18"
    case b18S = "B18S"
    case b2 = "B2"
    case b2_PRO = "B2_PRO"
    case b203 = "B203"
    case b21 = "B21"
    case b21_PRO = "B21_PRO"
    case b21_C2B = "B21_C2B"
    case b21_L2B = "B21_L2B"
    case b21S = "B21S"
    case b21S_C2B = "B21S_C2B"
    case b3 = "B3"
    case b31 = "B31"
    case b32 = "B32"
    case b32R = "B32R"
    case b3S = "B3S"
    case b3S_P = "B3S_P"
    case b4 = "B4"
    case b50 = "B50"
    case b50W = "B50W"
    case betty = "BETTY"
    case c1 = "C1"
    case d101 = "D101"
    case d11 = "D11"
    case d11_H = "D11_H"
    case d11_PRO = "D11_PRO"
    case d110 = "D110"
    case d110_M = "D110_M"
    case d11S = "D11S"
    case d41 = "D41"
    case d61 = "D61"
    case dxx = "DXX"
    case ep2M_H = "EP2M_H"
    case ep3M = "EP3M"
    case et10 = "ET10"
    case fust = "FUST"
    case h1 = "H1"
    case h1S = "H1S"
    case hi_D110 = "HI_D110"
    case hi_NB_D11 = "HI_NB_D11"
    case jc_M90 = "JC_M90"
    case jcb3S = "JCB3S"
    case k2 = "K2"
    case k3 = "K3"
    case k3_W = "K3_W"
    case m2_H = "M2_H"
    case m3 = "M3"
    case mp3K = "MP3K"
    case mp3K_W = "MP3K_W"
    case n1 = "N1"
    case p1 = "P1"
    case p18 = "P18"
    case p1S = "P1S"
    case s1 = "S1"
    case s3 = "S3"
    case s6 = "S6"
    case s6_P = "S6_P"
    case t2S = "T2S"
    case t6 = "T6"
    case t7 = "T7"
    case t8 = "T8"
    case t8S = "T8S"
    case tp2M_H = "TP2M_H"
    case z401 = "Z401"
}

/// Printer model metadata
public struct PrinterModelMeta: Sendable, Codable {
    public let model: PrinterModel
    public let id: [Int]
    public let dpi: Int
    public let printDirection: PrintDirection
    public let printheadPixels: Int
    public let paperTypes: [LabelType]
    public let densityMin: Int
    public let densityMax: Int
    public let densityDefault: Int
}

/// Printer models library
public let modelsLibrary: [PrinterModelMeta] = [
    PrinterModelMeta(model: .b1, id: [4096], dpi: 203, printDirection: .top, printheadPixels: 384, paperTypes: [.withGaps, .black, .transparent], densityMin: 1, densityMax: 5, densityDefault: 3),
    PrinterModelMeta(model: .b1_PRO, id: [4097], dpi: 300, printDirection: .top, printheadPixels: 567, paperTypes: [.withGaps, .black, .transparent], densityMin: 1, densityMax: 5, densityDefault: 3),
    PrinterModelMeta(model: .b21, id: [768], dpi: 203, printDirection: .top, printheadPixels: 384, paperTypes: [.withGaps, .black, .continuous, .transparent], densityMin: 1, densityMax: 5, densityDefault: 3),
    PrinterModelMeta(model: .b21_PRO, id: [785], dpi: 300, printDirection: .top, printheadPixels: 591, paperTypes: [.withGaps, .black, .continuous, .transparent], densityMin: 1, densityMax: 5, densityDefault: 3),
    PrinterModelMeta(model: .d11, id: [512], dpi: 203, printDirection: .left, printheadPixels: 96, paperTypes: [.withGaps, .transparent], densityMin: 1, densityMax: 3, densityDefault: 2),
    PrinterModelMeta(model: .d110, id: [2304, 2305], dpi: 203, printDirection: .left, printheadPixels: 96, paperTypes: [.withGaps, .transparent], densityMin: 1, densityMax: 3, densityDefault: 2),
    PrinterModelMeta(model: .d110_M, id: [2320], dpi: 203, printDirection: .left, printheadPixels: 96, paperTypes: [.withGaps, .transparent], densityMin: 1, densityMax: 5, densityDefault: 3),
    PrinterModelMeta(model: .b16, id: [1792], dpi: 203, printDirection: .left, printheadPixels: 96, paperTypes: [.withGaps, .transparent], densityMin: 1, densityMax: 3, densityDefault: 2),
    PrinterModelMeta(model: .b18, id: [3584], dpi: 203, printDirection: .left, printheadPixels: 96, paperTypes: [.withGaps, .transparent, .blackMarkGap, .heatShrinkTube, .continuous], densityMin: 1, densityMax: 3, densityDefault: 2),
    PrinterModelMeta(model: .b3S, id: [256, 260, 262], dpi: 203, printDirection: .top, printheadPixels: 576, paperTypes: [.withGaps, .black, .continuous, .transparent], densityMin: 1, densityMax: 5, densityDefault: 3),
    PrinterModelMeta(model: .s6, id: [261, 259, 258, 257], dpi: 203, printDirection: .top, printheadPixels: 576, paperTypes: [.withGaps, .black, .transparent], densityMin: 1, densityMax: 5, densityDefault: 3),
    PrinterModelMeta(model: .a20, id: [2817], dpi: 203, printDirection: .top, printheadPixels: 400, paperTypes: [.withGaps, .black, .transparent], densityMin: 1, densityMax: 5, densityDefault: 3),
    PrinterModelMeta(model: .a203, id: [2818], dpi: 203, printDirection: .top, printheadPixels: 400, paperTypes: [.withGaps, .black, .transparent], densityMin: 1, densityMax: 5, densityDefault: 3),
    PrinterModelMeta(model: .b203, id: [2816], dpi: 203, printDirection: .top, printheadPixels: 400, paperTypes: [.withGaps, .black, .transparent], densityMin: 1, densityMax: 5, densityDefault: 3),
]

/// Get printer metadata by ID
public func getPrinterMetaById(_ id: Int) -> PrinterModelMeta? {
    modelsLibrary.first { $0.id.contains(id) }
}

/// Get printer metadata by model
public func getPrinterMetaByModel(_ model: PrinterModel) -> PrinterModelMeta? {
    modelsLibrary.first { $0.model == model }
}
