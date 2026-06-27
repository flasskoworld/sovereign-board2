import XCTest
@testable import SovereignBoard2App

final class ChessEngineTests: XCTestCase {
    func testInitialPositionHasTwentyWhiteMoves() {
        let game = ChessGame()
        XCTAssertEqual(game.allLegalMoves(for: .white).count, 20)
    }

    func testPawnDoubleStepSetsEnPassantTarget() {
        let game = ChessGame()
        let from = BoardSquare(row: 6, col: 4)
        let to = BoardSquare(row: 4, col: 4)
        let move = game.legalMoves(from: from).first { $0.to == to }
        XCTAssertNotNil(move)
        game.apply(move: move!, actor: "White", region: WorldCatalog.region(id: "india"))
        XCTAssertEqual(game.enPassantTarget, BoardSquare(row: 5, col: 4))
    }

    func testKnightCanJumpFromOpeningPosition() {
        let game = ChessGame()
        let from = BoardSquare(row: 7, col: 6)
        let targets = Set(game.legalMoves(from: from).map(\.to))
        XCTAssertTrue(targets.contains(BoardSquare(row: 5, col: 5)))
        XCTAssertTrue(targets.contains(BoardSquare(row: 5, col: 7)))
    }
}
