import Foundation
import Observation

enum PieceColor: String, Codable, Equatable, CaseIterable {
    case white = "w"
    case black = "b"

    var opposite: PieceColor { self == .white ? .black : .white }
    var label: String { self == .white ? "white" : "black" }
}

enum PieceKind: String, Codable, Equatable {
    case pawn = "p"
    case knight = "n"
    case bishop = "b"
    case rook = "r"
    case queen = "q"
    case king = "k"

    var glyph: String {
        switch self {
        case .pawn: "♟"
        case .knight: "♞"
        case .bishop: "♝"
        case .rook: "♜"
        case .queen: "♛"
        case .king: "♚"
        }
    }

    var value: Int {
        switch self {
        case .pawn: 100
        case .knight: 320
        case .bishop: 330
        case .rook: 500
        case .queen: 900
        case .king: 20_000
        }
    }
}

struct ChessPiece: Codable, Equatable {
    var kind: PieceKind
    let color: PieceColor
}

struct BoardSquare: Hashable, Codable {
    let row: Int
    let col: Int

    var name: String {
        let files = Array("abcdefgh")
        return "\(files[col])\(8 - row)"
    }
}

struct ChessMove: Identifiable, Codable, Equatable {
    let id = UUID()
    let from: BoardSquare
    let to: BoardSquare
    var promotion: PieceKind?
    var isEnPassant = false
    var enPassantCapture: BoardSquare?
    var isCastle = false
    var rookFrom: BoardSquare?
    var rookTo: BoardSquare?

    enum CodingKeys: CodingKey {
        case from
        case to
        case promotion
        case isEnPassant
        case enPassantCapture
        case isCastle
        case rookFrom
        case rookTo
    }
}

struct CastleRights: Codable, Equatable {
    var whiteKingMoved = false
    var whiteRookA = false
    var whiteRookH = false
    var blackKingMoved = false
    var blackRookA = false
    var blackRookH = false
}

struct MoveLogEntry: Identifiable, Equatable {
    let id = UUID()
    let player: String
    let notation: String
}

@Observable
final class ChessGame {
    var board: [[ChessPiece?]]
    var turn: PieceColor = .white
    var selected: BoardSquare?
    var legalTargets: [ChessMove] = []
    var lastMove: ChessMove?
    var enPassantTarget: BoardSquare?
    var castleRights = CastleRights()
    var gameOverMessage: String?
    var moveLog: [MoveLogEntry] = []
    var codexNote = "The Codex opens after the first exchange."
    var playerColor: PieceColor = .white

    init() {
        board = ChessGame.initialBoard()
    }

    func reset(playerColor: PieceColor = .white) {
        board = ChessGame.initialBoard()
        turn = .white
        selected = nil
        legalTargets = []
        lastMove = nil
        enPassantTarget = nil
        castleRights = CastleRights()
        gameOverMessage = nil
        moveLog = []
        codexNote = "The Codex opens after the first exchange."
        self.playerColor = playerColor
    }

    static func initialBoard() -> [[ChessPiece?]] {
        var rows = Array(repeating: Array<ChessPiece?>(repeating: nil, count: 8), count: 8)
        let back: [PieceKind] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]
        for col in 0..<8 {
            rows[0][col] = ChessPiece(kind: back[col], color: .black)
            rows[1][col] = ChessPiece(kind: .pawn, color: .black)
            rows[6][col] = ChessPiece(kind: .pawn, color: .white)
            rows[7][col] = ChessPiece(kind: back[col], color: .white)
        }
        return rows
    }

    func piece(at square: BoardSquare) -> ChessPiece? {
        guard Self.inBounds(square.row, square.col) else { return nil }
        return board[square.row][square.col]
    }

    func tap(square: BoardSquare, region: RegionTheme) {
        guard gameOverMessage == nil, turn == playerColor else { return }
        if selected != nil, let move = legalTargets.first(where: { $0.to == square }) {
            apply(move: move, actor: "You", region: region)
            return
        }

        guard let piece = piece(at: square), piece.color == playerColor else {
            selected = nil
            legalTargets = []
            return
        }

        selected = square
        legalTargets = legalMoves(from: square)
    }

    func apply(move: ChessMove, actor: String, region: RegionTheme) {
        guard var moving = piece(at: move.from) else { return }
        let captured = move.isEnPassant ? move.enPassantCapture.flatMap(piece) : piece(at: move.to)

        board[move.from.row][move.from.col] = nil
        if let capture = move.enPassantCapture, move.isEnPassant {
            board[capture.row][capture.col] = nil
        }
        if move.isCastle, let rookFrom = move.rookFrom, let rookTo = move.rookTo {
            board[rookTo.row][rookTo.col] = board[rookFrom.row][rookFrom.col]
            board[rookFrom.row][rookFrom.col] = nil
        }

        if moving.kind == .pawn, move.to.row == (moving.color == .white ? 0 : 7) {
            moving.kind = move.promotion ?? .queen
        }
        board[move.to.row][move.to.col] = moving

        updateCastleRights(for: moving, from: move.from, captured: captured, captureSquare: move.to)
        enPassantTarget = enPassantSquare(for: moving, from: move.from, to: move.to)
        lastMove = move
        selected = nil
        legalTargets = []
        log(move: move, piece: moving, captured: captured, actor: actor)
        if let captured { codexNote = Codex.note(for: captured.kind, region: region) }

        let next = moving.color.opposite
        let nextMoves = allLegalMoves(for: next)
        if nextMoves.isEmpty {
            gameOverMessage = isInCheck(next) ? "\(actor) wins by checkmate." : "Stalemate. The board holds."
        } else {
            turn = next
        }
    }

    func performAIMove(region: RegionTheme) {
        guard gameOverMessage == nil, turn != playerColor else { return }
        let moves = allLegalMoves(for: turn)
        guard let move = bestMove(from: moves, for: turn) else { return }
        apply(move: move, actor: region.persona, region: region)
    }

    func legalMoves(from square: BoardSquare) -> [ChessMove] {
        guard let piece = piece(at: square) else { return [] }
        return pseudoMoves(from: square, piece: piece).filter { move in
            let after = boardAfter(move: move)
            return !Self.isInCheck(board: after, color: piece.color)
        }
    }

    func allLegalMoves(for color: PieceColor) -> [ChessMove] {
        var moves: [ChessMove] = []
        for row in 0..<8 {
            for col in 0..<8 where board[row][col]?.color == color {
                moves.append(contentsOf: legalMoves(from: BoardSquare(row: row, col: col)))
            }
        }
        return moves
    }

    private func pseudoMoves(from square: BoardSquare, piece: ChessPiece) -> [ChessMove] {
        switch piece.kind {
        case .pawn: pawnMoves(from: square, color: piece.color)
        case .knight: jumpMoves(from: square, color: piece.color, deltas: [(1, 2), (2, 1), (-1, 2), (-2, 1), (1, -2), (2, -1), (-1, -2), (-2, -1)])
        case .bishop: rayMoves(from: square, color: piece.color, directions: [(1, 1), (1, -1), (-1, 1), (-1, -1)])
        case .rook: rayMoves(from: square, color: piece.color, directions: [(1, 0), (-1, 0), (0, 1), (0, -1)])
        case .queen: rayMoves(from: square, color: piece.color, directions: [(1, 1), (1, -1), (-1, 1), (-1, -1), (1, 0), (-1, 0), (0, 1), (0, -1)])
        case .king: kingMoves(from: square, color: piece.color)
        }
    }

    private func pawnMoves(from square: BoardSquare, color: PieceColor) -> [ChessMove] {
        let direction = color == .white ? -1 : 1
        let startRow = color == .white ? 6 : 1
        var moves: [ChessMove] = []
        let one = BoardSquare(row: square.row + direction, col: square.col)
        if Self.inBounds(one.row, one.col), piece(at: one) == nil {
            moves.append(ChessMove(from: square, to: one))
            let two = BoardSquare(row: square.row + (direction * 2), col: square.col)
            if square.row == startRow, piece(at: two) == nil {
                moves.append(ChessMove(from: square, to: two))
            }
        }
        for dc in [-1, 1] {
            let target = BoardSquare(row: square.row + direction, col: square.col + dc)
            guard Self.inBounds(target.row, target.col) else { continue }
            if let occupant = piece(at: target), occupant.color != color {
                moves.append(ChessMove(from: square, to: target))
            } else if target == enPassantTarget {
                var move = ChessMove(from: square, to: target)
                move.isEnPassant = true
                move.enPassantCapture = BoardSquare(row: square.row, col: target.col)
                moves.append(move)
            }
        }
        return moves
    }

    private func jumpMoves(from square: BoardSquare, color: PieceColor, deltas: [(Int, Int)]) -> [ChessMove] {
        deltas.compactMap { dr, dc in
            let target = BoardSquare(row: square.row + dr, col: square.col + dc)
            guard Self.inBounds(target.row, target.col) else { return nil }
            guard piece(at: target)?.color != color else { return nil }
            return ChessMove(from: square, to: target)
        }
    }

    private func rayMoves(from square: BoardSquare, color: PieceColor, directions: [(Int, Int)]) -> [ChessMove] {
        var moves: [ChessMove] = []
        for (dr, dc) in directions {
            var row = square.row + dr
            var col = square.col + dc
            while Self.inBounds(row, col) {
                let target = BoardSquare(row: row, col: col)
                if let occupant = piece(at: target) {
                    if occupant.color != color { moves.append(ChessMove(from: square, to: target)) }
                    break
                }
                moves.append(ChessMove(from: square, to: target))
                row += dr
                col += dc
            }
        }
        return moves
    }

    private func kingMoves(from square: BoardSquare, color: PieceColor) -> [ChessMove] {
        var moves = jumpMoves(from: square, color: color, deltas: [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)])
        guard !isInCheck(color) else { return moves }
        let row = color == .white ? 7 : 0
        let kingMoved = color == .white ? castleRights.whiteKingMoved : castleRights.blackKingMoved
        guard !kingMoved, square == BoardSquare(row: row, col: 4) else { return moves }
        let rookA = color == .white ? castleRights.whiteRookA : castleRights.blackRookA
        let rookH = color == .white ? castleRights.whiteRookH : castleRights.blackRookH
        if !rookA,
           piece(at: BoardSquare(row: row, col: 0)) == ChessPiece(kind: .rook, color: color),
           piece(at: BoardSquare(row: row, col: 1)) == nil,
           piece(at: BoardSquare(row: row, col: 2)) == nil,
           piece(at: BoardSquare(row: row, col: 3)) == nil,
           !isSquare(BoardSquare(row: row, col: 3), attackedBy: color.opposite),
           !isSquare(BoardSquare(row: row, col: 2), attackedBy: color.opposite) {
            var move = ChessMove(from: square, to: BoardSquare(row: row, col: 2))
            move.isCastle = true
            move.rookFrom = BoardSquare(row: row, col: 0)
            move.rookTo = BoardSquare(row: row, col: 3)
            moves.append(move)
        }
        if !rookH,
           piece(at: BoardSquare(row: row, col: 7)) == ChessPiece(kind: .rook, color: color),
           piece(at: BoardSquare(row: row, col: 5)) == nil,
           piece(at: BoardSquare(row: row, col: 6)) == nil,
           !isSquare(BoardSquare(row: row, col: 5), attackedBy: color.opposite),
           !isSquare(BoardSquare(row: row, col: 6), attackedBy: color.opposite) {
            var move = ChessMove(from: square, to: BoardSquare(row: row, col: 6))
            move.isCastle = true
            move.rookFrom = BoardSquare(row: row, col: 7)
            move.rookTo = BoardSquare(row: row, col: 5)
            moves.append(move)
        }
        return moves
    }

    func isInCheck(_ color: PieceColor) -> Bool {
        Self.isInCheck(board: board, color: color)
    }

    private func isSquare(_ square: BoardSquare, attackedBy color: PieceColor) -> Bool {
        Self.isSquare(square, attackedBy: color, board: board)
    }

    private func rayAttacked(_ square: BoardSquare, by color: PieceColor, directions: [(Int, Int)], kinds: Set<PieceKind>) -> Bool {
        Self.rayAttacked(square, by: color, directions: directions, kinds: kinds, board: board)
    }

    private func findKing(_ color: PieceColor) -> BoardSquare? {
        Self.findKing(color, board: board)
    }

    private func updateCastleRights(for piece: ChessPiece, from: BoardSquare, captured: ChessPiece?, captureSquare: BoardSquare) {
        if piece.kind == .king {
            if piece.color == .white { castleRights.whiteKingMoved = true } else { castleRights.blackKingMoved = true }
        }
        if piece.kind == .rook {
            if from == BoardSquare(row: 7, col: 0) { castleRights.whiteRookA = true }
            if from == BoardSquare(row: 7, col: 7) { castleRights.whiteRookH = true }
            if from == BoardSquare(row: 0, col: 0) { castleRights.blackRookA = true }
            if from == BoardSquare(row: 0, col: 7) { castleRights.blackRookH = true }
        }
        if captured?.kind == .rook {
            if captureSquare == BoardSquare(row: 7, col: 0) { castleRights.whiteRookA = true }
            if captureSquare == BoardSquare(row: 7, col: 7) { castleRights.whiteRookH = true }
            if captureSquare == BoardSquare(row: 0, col: 0) { castleRights.blackRookA = true }
            if captureSquare == BoardSquare(row: 0, col: 7) { castleRights.blackRookH = true }
        }
    }

    private func enPassantSquare(for piece: ChessPiece, from: BoardSquare, to: BoardSquare) -> BoardSquare? {
        guard piece.kind == .pawn, abs(from.row - to.row) == 2 else { return nil }
        return BoardSquare(row: (from.row + to.row) / 2, col: from.col)
    }

    private func boardAfter(move: ChessMove) -> [[ChessPiece?]] {
        var next = board
        guard var moving = next[move.from.row][move.from.col] else { return next }
        next[move.from.row][move.from.col] = nil
        if let capture = move.enPassantCapture, move.isEnPassant {
            next[capture.row][capture.col] = nil
        }
        if move.isCastle, let rookFrom = move.rookFrom, let rookTo = move.rookTo {
            next[rookTo.row][rookTo.col] = next[rookFrom.row][rookFrom.col]
            next[rookFrom.row][rookFrom.col] = nil
        }
        if moving.kind == .pawn, move.to.row == (moving.color == .white ? 0 : 7) {
            moving.kind = move.promotion ?? .queen
        }
        next[move.to.row][move.to.col] = moving
        return next
    }

    private func bestMove(from moves: [ChessMove], for color: PieceColor) -> ChessMove? {
        moves.max { lhs, rhs in score(move: lhs, for: color) < score(move: rhs, for: color) }
    }

    private func score(move: ChessMove, for color: PieceColor) -> Int {
        var score = 0
        if let target = piece(at: move.to) { score += target.kind.value * 10 }
        if move.isEnPassant { score += PieceKind.pawn.value * 10 }
        if piece(at: move.from)?.kind == .pawn, [3, 4].contains(move.to.col) { score += 20 }
        if move.isCastle { score += 45 }
        if Self.isInCheck(board: boardAfter(move: move), color: color.opposite) { score += 80 }
        return score
    }

    private func log(move: ChessMove, piece: ChessPiece, captured: ChessPiece?, actor: String) {
        let notation: String
        if move.isCastle {
            notation = move.to.col == 6 ? "O-O" : "O-O-O"
        } else {
            let joiner = captured == nil && !move.isEnPassant ? "-" : "x"
            notation = "\(piece.kind.rawValue.uppercased())\(move.from.name)\(joiner)\(move.to.name)"
        }
        moveLog.insert(MoveLogEntry(player: actor, notation: notation), at: 0)
    }

    static func inBounds(_ row: Int, _ col: Int) -> Bool {
        row >= 0 && row < 8 && col >= 0 && col < 8
    }

    private static func piece(at square: BoardSquare, board: [[ChessPiece?]]) -> ChessPiece? {
        guard inBounds(square.row, square.col) else { return nil }
        return board[square.row][square.col]
    }

    private static func isInCheck(board: [[ChessPiece?]], color: PieceColor) -> Bool {
        guard let king = findKing(color, board: board) else { return false }
        return isSquare(king, attackedBy: color.opposite, board: board)
    }

    private static func findKing(_ color: PieceColor, board: [[ChessPiece?]]) -> BoardSquare? {
        for row in 0..<8 {
            for col in 0..<8 where board[row][col] == ChessPiece(kind: .king, color: color) {
                return BoardSquare(row: row, col: col)
            }
        }
        return nil
    }

    private static func isSquare(_ square: BoardSquare, attackedBy color: PieceColor, board: [[ChessPiece?]]) -> Bool {
        let pawnDirection = color == .white ? -1 : 1
        for dc in [-1, 1] {
            let pawn = BoardSquare(row: square.row - pawnDirection, col: square.col + dc)
            if piece(at: pawn, board: board) == ChessPiece(kind: .pawn, color: color) { return true }
        }
        for (dr, dc) in [(1, 2), (2, 1), (-1, 2), (-2, 1), (1, -2), (2, -1), (-1, -2), (-2, -1)] {
            let target = BoardSquare(row: square.row + dr, col: square.col + dc)
            if piece(at: target, board: board) == ChessPiece(kind: .knight, color: color) { return true }
        }
        for (dr, dc) in [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)] {
            let target = BoardSquare(row: square.row + dr, col: square.col + dc)
            if piece(at: target, board: board) == ChessPiece(kind: .king, color: color) { return true }
        }
        return rayAttacked(square, by: color, directions: [(1, 1), (1, -1), (-1, 1), (-1, -1)], kinds: [.bishop, .queen], board: board)
            || rayAttacked(square, by: color, directions: [(1, 0), (-1, 0), (0, 1), (0, -1)], kinds: [.rook, .queen], board: board)
    }

    private static func rayAttacked(_ square: BoardSquare, by color: PieceColor, directions: [(Int, Int)], kinds: Set<PieceKind>, board: [[ChessPiece?]]) -> Bool {
        for (dr, dc) in directions {
            var row = square.row + dr
            var col = square.col + dc
            while inBounds(row, col) {
                if let occupant = piece(at: BoardSquare(row: row, col: col), board: board) {
                    if occupant.color == color && kinds.contains(occupant.kind) { return true }
                    break
                }
                row += dr
                col += dc
            }
        }
        return false
    }
}

enum Codex {
    static func note(for kind: PieceKind, region: RegionTheme) -> String {
        switch kind {
        case .pawn:
            "In \(region.shortName), pawn structure is the map under the map. Every pawn move redraws future roads."
        case .knight:
            "Knights make history sideways. In \(region.shortName), outposts become local legends."
        case .bishop:
            "A bishop is only as strong as its diagonal. Open the road before asking it to rule."
        case .rook:
            "Rooks want files the way empires want trade routes: open, direct, and hard to contest."
        case .queen:
            "The modern queen changed chess history. Spend that power late enough that it cannot be chased."
        case .king:
            "The king is a lesson in timing: hide in the middle game, march in the ending."
        }
    }
}
