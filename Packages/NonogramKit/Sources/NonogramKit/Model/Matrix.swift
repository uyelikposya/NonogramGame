import Foundation

public struct GridPosition: Hashable, Sendable, Codable {
    public let row: Int
    public let column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }
}

/// Satır öncelikli (row-major) sabit boyutlu 2B dizi. Bulmaca çözümü, oyun tahtası
/// ve renkli piksel görseli bu tip üzerinden tutulur.
public struct Matrix<Element> {
    public let rows: Int
    public let columns: Int
    public private(set) var storage: [Element]

    public init(rows: Int, columns: Int, repeating value: Element) {
        precondition(rows > 0 && columns > 0, "Matrix boyutu pozitif olmalı")
        self.rows = rows
        self.columns = columns
        self.storage = Array(repeating: value, count: rows * columns)
    }

    /// `values[row][column]` biçimindeki dikdörtgen diziden oluşturur.
    public init?(_ values: [[Element]]) {
        guard let width = values.first?.count, width > 0,
              values.allSatisfy({ $0.count == width })
        else { return nil }
        self.rows = values.count
        self.columns = width
        self.storage = values.flatMap { $0 }
    }

    public func contains(_ position: GridPosition) -> Bool {
        (0..<rows).contains(position.row) && (0..<columns).contains(position.column)
    }

    public subscript(row: Int, column: Int) -> Element {
        get { storage[row * columns + column] }
        set { storage[row * columns + column] = newValue }
    }

    public subscript(position: GridPosition) -> Element {
        get { self[position.row, position.column] }
        set { self[position.row, position.column] = newValue }
    }

    public func row(_ index: Int) -> [Element] {
        Array(storage[(index * columns)..<((index + 1) * columns)])
    }

    public func column(_ index: Int) -> [Element] {
        (0..<rows).map { self[$0, index] }
    }

    public var positions: [GridPosition] {
        (0..<rows).flatMap { row in (0..<columns).map { GridPosition(row: row, column: $0) } }
    }

    public func map<T>(_ transform: (Element) throws -> T) rethrows -> Matrix<T> {
        Matrix<T>(rows: rows, columns: columns, storage: try storage.map(transform))
    }

    private init(rows: Int, columns: Int, storage: [Element]) {
        self.rows = rows
        self.columns = columns
        self.storage = storage
    }
}

extension Matrix: Equatable where Element: Equatable {}
extension Matrix: Hashable where Element: Hashable {}
extension Matrix: Sendable where Element: Sendable {}
extension Matrix: Codable where Element: Codable {}
