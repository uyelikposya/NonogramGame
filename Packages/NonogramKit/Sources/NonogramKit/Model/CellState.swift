import Foundation

/// Oyuncunun tahtadaki bir kareye verdiği işaret.
public enum CellState: UInt8, Codable, Sendable {
    case blank
    case filled
    case crossed
}

/// Oyuncunun seçili aracı: doldurma veya çarpı (X).
public enum MarkTool: String, Codable, Sendable, CaseIterable {
    case fill
    case cross

    public var cellState: CellState {
        switch self {
        case .fill: .filled
        case .cross: .crossed
        }
    }
}
