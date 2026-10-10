import Foundation

/// Kedi Bulmaca tahtasındaki bir karenin durumu.
public enum CatMark: String, Codable, Sendable {
    case blank
    /// Oyuncunun ya da otomatik konan X.
    case cross
    /// Bulunan kedi (kilitli).
    case cat
    /// Yanlış kedi denemesi: kırmızı X (kilitli).
    case wrong
}

/// Kedi bulununca arayüzün kutladığı ayrıntılar.
public struct CatFind: Equatable, Sendable {
    public let position: GridPosition
    public let region: Int
    /// Kedinin satırı, sütunu, rengi ve komşularına otomatik konan X'ler.
    public let autoCrossed: [GridPosition]
    /// Kediden önce rengin diğer bütün kareleri zaten X'liydi ("Tam isabet!").
    public let perfectlyMarked: Bool
    /// İpucuyla bulundu (puan ve seri sayılmaz).
    public let revealed: Bool
}

public enum CatMove: Equatable, Sendable {
    case ignored
    case crossed
    case cleared
    case found(CatFind)
    case mistake(GridPosition)
    case solved(CatFind)
    case failed(GridPosition)
}

/// Bir Kedi Bulmaca oturumunun kuralları (saf değer tipi; zamanlayıcı ve puan arayüzde).
public struct CatGame: Sendable {
    public enum Status: Equatable, Sendable {
        case playing
        case won
        case lost
    }

    public static let defaultLives = 3

    public let level: CatLevel
    public let lives: Int
    public private(set) var marks: [CatMark]
    public private(set) var mistakes = 0
    public private(set) var status: Status = .playing
    public var elapsed: TimeInterval = 0

    public init(level: CatLevel, lives: Int = CatGame.defaultLives) {
        self.level = level
        self.lives = lives
        self.marks = Array(repeating: .blank, count: level.size * level.size)
    }

    public var size: Int { level.size }

    public subscript(position: GridPosition) -> CatMark {
        marks[index(position)]
    }

    public func contains(_ position: GridPosition) -> Bool {
        (0..<size).contains(position.row) && (0..<size).contains(position.column)
    }

    public var remainingLives: Int { max(lives - mistakes, 0) }

    /// Kedisi bulunan renkler.
    public var foundRegions: Set<Int> {
        Set(marks.indices.filter { marks[$0] == .cat }.map { level.regionMap[$0] })
    }

    public var foundCount: Int { marks.filter { $0 == .cat }.count }

    // MARK: - Hamleler

    /// Dokunma: boş → X → kedi denemesi; X'e dokununca kedi denenir.
    @discardableResult
    public mutating func tap(at position: GridPosition) -> CatMove {
        guard status == .playing, contains(position) else { return .ignored }
        switch self[position] {
        case .blank:
            marks[index(position)] = .cross
            return .crossed
        case .cross:
            return placeCat(at: position)
        case .cat, .wrong:
            return .ignored
        }
    }

    /// Sürükleme: boş karelere X koyar (`cross == true`) ya da X'leri siler.
    @discardableResult
    public mutating func paint(cross: Bool, at position: GridPosition) -> CatMove {
        guard status == .playing, contains(position) else { return .ignored }
        let i = index(position)
        if cross, marks[i] == .blank {
            marks[i] = .cross
            return .crossed
        }
        if !cross, marks[i] == .cross {
            marks[i] = .blank
            return .cleared
        }
        return .ignored
    }

    /// Kedi koyma. Doğruysa kedi kilitlenir ve satırı, sütunu, rengi ve komşuları X'lenir;
    /// yanlışsa kare kırmızı X olur ve bir can gider.
    @discardableResult
    public mutating func placeCat(at position: GridPosition, revealed: Bool = false) -> CatMove {
        guard status == .playing, contains(position) else { return .ignored }
        let i = index(position)
        guard marks[i] == .blank || marks[i] == .cross else { return .ignored }

        guard level.isCat(position) else {
            marks[i] = .wrong
            mistakes += 1
            if mistakes >= lives {
                status = .lost
                return .failed(position)
            }
            return .mistake(position)
        }

        let region = level.regionMap[i]
        let perfectly = !revealed && level.regionMap.indices.allSatisfy {
            $0 == i || level.regionMap[$0] != region || marks[$0] == .cross || marks[$0] == .wrong
        }
        marks[i] = .cat
        var crossed: [GridPosition] = []
        for target in CatRules.attacked(by: i, in: level) where marks[target] == .blank {
            marks[target] = .cross
            crossed.append(GridPosition(row: target / size, column: target % size))
        }
        let find = CatFind(position: position, region: region, autoCrossed: crossed, perfectlyMarked: perfectly, revealed: revealed)
        if foundCount == size {
            status = .won
            return .solved(find)
        }
        return .found(find)
    }

    /// "Kediyi bul" ipucu: kedisi en zor bulunacak olmayan, en kısıtlı rengin kedisini yerleştirir.
    @discardableResult
    public mutating func revealCat() -> CatMove {
        guard status == .playing else { return .ignored }
        let found = foundRegions
        let open = (0..<size).filter { !found.contains($0) }
        let candidates = CatRules.candidates(in: self)
        let region = open.min { a, b in
            let ca = level.regionMap.indices.filter { level.regionMap[$0] == a && candidates[$0] }.count
            let cb = level.regionMap.indices.filter { level.regionMap[$0] == b && candidates[$0] }.count
            return ca == cb ? a < b : ca < cb
        }
        guard let region else { return .ignored }
        return placeCat(at: level.catPosition(ofRegion: region), revealed: true)
    }

    /// "?" ipucunu uygular: X'leri koyar ya da tek seçenekse kediyi yerleştirir.
    @discardableResult
    public mutating func apply(_ hint: CatHint) -> CatMove {
        guard status == .playing else { return .ignored }
        if case .onlySpot = hint.kind, let cell = hint.cells.first {
            return placeCat(at: cell, revealed: true)
        }
        var changed = false
        for cell in hint.cells where contains(cell) && marks[index(cell)] == .blank {
            marks[index(cell)] = .cross
            changed = true
        }
        return changed ? .crossed : .ignored
    }

    /// Kaybedince ödüllü reklamla: bir can geri gelir.
    public mutating func revive() {
        guard status == .lost else { return }
        mistakes = max(lives - 1, 0)
        status = .playing
    }

    /// Mantıkla bir sonraki adım ("?" düğmesi).
    public func hint() -> CatHint? {
        guard status == .playing else { return nil }
        return CatRules.nextHint(in: self)
    }

    // MARK: - Kayıt

    public var snapshot: CatSnapshot {
        CatSnapshot(levelID: level.id, marks: marks, mistakes: mistakes, elapsed: elapsed)
    }

    public init(level: CatLevel, restoring snapshot: CatSnapshot, lives: Int = CatGame.defaultLives) {
        self.init(level: level, lives: lives)
        guard snapshot.levelID == level.id, snapshot.marks.count == marks.count else { return }
        marks = snapshot.marks
        mistakes = snapshot.mistakes
        elapsed = snapshot.elapsed
        if mistakes >= lives {
            status = .lost
        } else if foundCount == size {
            status = .won
        }
    }

    private func index(_ position: GridPosition) -> Int {
        position.row * size + position.column
    }
}

/// Yarım kalan Kedi Bulmaca oyunu.
public struct CatSnapshot: Codable, Equatable, Sendable {
    public let levelID: String
    public let marks: [CatMark]
    public let mistakes: Int
    public let elapsed: TimeInterval
}
