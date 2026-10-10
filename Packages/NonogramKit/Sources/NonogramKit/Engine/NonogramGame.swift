import Foundation

/// Bir bulmaca oturumunun tüm kuralları. Saf değer tipidir (UI, zamanlayıcı veya kalıcılık bilmez);
/// ViewModel onu sarar, zamanı `advanceTime(by:)` ile ilerletir, kaydetmek için `snapshot` alır.
public struct NonogramGame: Sendable {
    public enum Status: Equatable, Sendable {
        case playing
        case won
        case lost(LossReason)
    }

    public enum LossReason: Equatable, Sendable {
        case outOfMistakes
        case outOfTime
    }

    public enum MoveOutcome: Equatable, Sendable {
        /// Hiçbir şey değişmedi (aynı işaret, kilitli kare, oyun bitmiş).
        case ignored
        case changed
        /// Yanlış hamle; doğru işaret otomatik konuldu ve kare kilitlendi.
        case mistake
        case solved
        case failed(LossReason)
    }

    public struct CellChange: Equatable, Sendable, Codable {
        public let position: GridPosition
        public let from: CellState
        public let to: CellState
    }

    public let puzzle: Puzzle
    public let rules: GameRules
    public private(set) var board: Matrix<CellState>
    public private(set) var status: Status = .playing
    public private(set) var mistakes = 0
    public private(set) var elapsed: TimeInterval = 0
    /// Hata sonrası düzeltilen kareler; oyuncu bunları değiştiremez.
    public private(set) var lockedCells: Set<GridPosition> = []
    private var undoStack: [[CellChange]] = []
    /// Tamamlanan satır/sütuna otomatik X konur mu? Kurallardan başlar; oyuncu "Zor" moda
    /// geçince oyun sırasında kapatılabilir (yalnızca sonraki hamleleri etkiler).
    public var autoCrossesCompletedLines: Bool
    /// "Kolay" modda: satırdaki X'lerin hepsi konunca kalan kareler kendiliğinden dolar.
    /// Yalnızca `autoCrossesCompletedLines` açıkken çalışır; eğitimin bazı derslerinde kapatılır.
    public var autoFillsCrossedLines = true

    public init(puzzle: Puzzle, rules: GameRules) {
        self.puzzle = puzzle
        self.rules = rules
        self.board = Matrix(rows: puzzle.rows, columns: puzzle.columns, repeating: .blank)
        self.autoCrossesCompletedLines = rules.autoCrossCompletedLines
    }

    // MARK: - Durum

    public var remainingMistakes: Int? {
        guard rules.checksMoves, let limit = rules.mistakeLimit else { return nil }
        return max(limit - mistakes, 0)
    }

    public var remainingTime: TimeInterval? {
        rules.timeLimit.map { max($0 - elapsed, 0) }
    }

    public var canUndo: Bool { status == .playing && !undoStack.isEmpty }

    public func isRowSatisfied(_ row: Int) -> Bool {
        LineClue.isSatisfied(board.row(row), by: puzzle.rowClues[row])
    }

    public func isColumnSatisfied(_ column: Int) -> Bool {
        LineClue.isSatisfied(board.column(column), by: puzzle.columnClues[column])
    }

    /// 0...1 arası; ilerleme çubuğu için.
    public var progress: Double {
        let target = puzzle.solution.storage.filter { $0 }.count
        let correct = puzzle.solution.positions.filter { puzzle.solution[$0] && board[$0] == .filled }.count
        return Double(correct) / Double(target)
    }

    // MARK: - Hamleler

    /// Dokunma davranışı: boş kareye aracın işaretini koyar, aynı işaret varsa siler,
    /// diğer işaretin üstüne yazmaz (yanlışlıkla X'li kareyi doldurmayı önler).
    @discardableResult
    public mutating func toggle(at position: GridPosition, with tool: MarkTool) -> MoveOutcome {
        guard board.contains(position) else { return .ignored }
        switch board[position] {
        case .blank: return mark(tool.cellState, at: position)
        case tool.cellState: return mark(.blank, at: position)
        default: return .ignored
        }
    }

    /// Kareyi doğrudan `target` durumuna getirir. Sürükleyerek doldurma bunu kullanır:
    /// ViewModel ilk karede hedefi belirler, geçilen her kare için bu metodu çağırır.
    @discardableResult
    public mutating func mark(_ target: CellState, at position: GridPosition) -> MoveOutcome {
        guard status == .playing,
              board.contains(position),
              board[position] != target,
              !lockedCells.contains(position)
        else { return .ignored }

        if rules.checksMoves, target != .blank, (target == .filled) != puzzle.solution[position] {
            return registerMistake(at: position)
        }

        var changes: [CellChange] = []
        set(target, at: position, recordingInto: &changes)
        if target != .blank { autoResolveLines(through: position, recordingInto: &changes) }
        undoStack.append(changes)
        return evaluateCompletion() ? .solved : .changed
    }

    /// Son hamle grubunu (otomatik X'ler dahil) geri alır. Hatalar geri alınamaz.
    @discardableResult
    public mutating func undo() -> Bool {
        guard canUndo, let changes = undoStack.popLast() else { return false }
        for change in changes.reversed() where !lockedCells.contains(change.position) {
            board[change.position] = change.from
        }
        return true
    }

    /// Süreli modda ViewModel her saniye çağırır.
    @discardableResult
    public mutating func advanceTime(by interval: TimeInterval) -> MoveOutcome {
        guard status == .playing, interval > 0 else { return .ignored }
        elapsed += interval
        if let limit = rules.timeLimit, elapsed >= limit {
            elapsed = limit
            status = .lost(.outOfTime)
            return .failed(.outOfTime)
        }
        return .changed
    }

    /// "Devam et" (ör. ödüllü reklam sonrası): kaybedilen oyunu ek hak/süre ile sürdürür.
    public mutating func revive(extraMistakes: Int = 1, extraTime: TimeInterval = 60) {
        guard case .lost(let reason) = status else { return }
        switch reason {
        case .outOfMistakes: mistakes = max(mistakes - extraMistakes, 0)
        case .outOfTime: elapsed = max(elapsed - extraTime, 0)
        }
        status = .playing
    }

    // MARK: - Yardımcılar

    private mutating func registerMistake(at position: GridPosition) -> MoveOutcome {
        mistakes += 1
        var changes: [CellChange] = []
        let correct: CellState = puzzle.solution[position] ? .filled : .crossed
        set(correct, at: position, recordingInto: &changes)
        lockedCells.insert(position)
        autoResolveLines(through: position, recordingInto: &changes)

        if let limit = rules.mistakeLimit, mistakes >= limit {
            status = .lost(.outOfMistakes)
            return .failed(.outOfMistakes)
        }
        return evaluateCompletion() ? .solved : .mistake
    }

    private mutating func set(_ state: CellState, at position: GridPosition, recordingInto changes: inout [CellChange]) {
        changes.append(CellChange(position: position, from: board[position], to: state))
        board[position] = state
    }

    /// "Kolay" mod yardımları (tek geri alma grubunda):
    /// - Dolu kare konunca ipucu sağlanan satır/sütunun boş karelerine X konur.
    /// - X konunca, satır/sütundaki X'lerin hepsi doğru ve sayısı boş kalması gereken kare
    ///   sayısına eşitse kalan boş kareler doldurulur; bu dolu kareler de ilk kuralı tetikler.
    ///   Otomatik X'ler doldurmayı tetiklemez (oyunu oyuncunun yerine çözmesin diye).
    private mutating func autoResolveLines(through position: GridPosition, recordingInto changes: inout [CellChange]) {
        guard autoCrossesCompletedLines else { return }
        switch board[position] {
        case .filled:
            crossSatisfiedLines(through: position, recordingInto: &changes)
        case .crossed:
            guard autoFillsCrossedLines else { return }
            let lines = [
                (rowCells(position.row), puzzle.rowClues[position.row]),
                (columnCells(position.column), puzzle.columnClues[position.column]),
            ]
            for (cells, clue) in lines {
                let blanks = cells.filter { board[$0] == .blank }
                let crosses = cells.filter { board[$0] == .crossed }.count
                let allCorrect = cells.allSatisfy {
                    board[$0] == .blank || (board[$0] == .filled) == puzzle.solution[$0]
                }
                guard !blanks.isEmpty, allCorrect, crosses == cells.count - clue.reduce(0, +) else { continue }
                for cell in blanks {
                    set(.filled, at: cell, recordingInto: &changes)
                    crossSatisfiedLines(through: cell, recordingInto: &changes)
                }
            }
        case .blank:
            break
        }
    }

    private func rowCells(_ row: Int) -> [GridPosition] {
        (0..<board.columns).map { GridPosition(row: row, column: $0) }
    }

    private func columnCells(_ column: Int) -> [GridPosition] {
        (0..<board.rows).map { GridPosition(row: $0, column: column) }
    }

    private mutating func crossSatisfiedLines(through position: GridPosition, recordingInto changes: inout [CellChange]) {
        if isRowSatisfied(position.row) {
            for column in 0..<board.columns where board[position.row, column] == .blank {
                set(.crossed, at: GridPosition(row: position.row, column: column), recordingInto: &changes)
            }
        }
        if isColumnSatisfied(position.column) {
            for row in 0..<board.rows where board[row, position.column] == .blank {
                set(.crossed, at: GridPosition(row: row, column: position.column), recordingInto: &changes)
            }
        }
    }

    /// Kontrollü modda tüm dolu kareler doğru olmalı; serbest modda tüm ipuçları sağlanmalı
    /// (içerik benzersiz çözümlü olduğundan ikisi aynı sonucu verir).
    private mutating func evaluateCompletion() -> Bool {
        let solved: Bool
        if rules.checksMoves {
            solved = puzzle.solution.positions.allSatisfy { !puzzle.solution[$0] || board[$0] == .filled }
        } else {
            solved = (0..<board.rows).allSatisfy { isRowSatisfied($0) }
                && (0..<board.columns).allSatisfy { isColumnSatisfied($0) }
        }
        if solved {
            status = .won
            undoStack.removeAll()
        }
        return solved
    }
}

// MARK: - Kaydet / devam et

/// Yarım kalan oyunu kalıcı hale getirmek için (SwiftData'da `Data` olarak saklanır).
public struct GameSnapshot: Codable, Equatable, Sendable {
    public let puzzleID: String
    public let board: Matrix<CellState>
    public let mistakes: Int
    public let elapsed: TimeInterval
    public let lockedCells: Set<GridPosition>
}

extension NonogramGame {
    public var snapshot: GameSnapshot {
        GameSnapshot(puzzleID: puzzle.id, board: board, mistakes: mistakes, elapsed: elapsed, lockedCells: lockedCells)
    }

    /// Kayıt bu bulmacaya ait değilse veya boyut uyuşmuyorsa yeni oyun başlar.
    public init(puzzle: Puzzle, rules: GameRules, restoring snapshot: GameSnapshot) {
        self.init(puzzle: puzzle, rules: rules)
        guard snapshot.puzzleID == puzzle.id,
              snapshot.board.rows == puzzle.rows,
              snapshot.board.columns == puzzle.columns
        else { return }
        board = snapshot.board
        mistakes = snapshot.mistakes
        elapsed = snapshot.elapsed
        lockedCells = snapshot.lockedCells
        if let limit = rules.mistakeLimit, rules.checksMoves, mistakes >= limit {
            status = .lost(.outOfMistakes)
        } else if let limit = rules.timeLimit, elapsed >= limit {
            status = .lost(.outOfTime)
        } else {
            _ = evaluateCompletion()
        }
    }
}
