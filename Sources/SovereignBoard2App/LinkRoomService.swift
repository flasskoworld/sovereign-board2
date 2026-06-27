import Foundation

struct FirebaseConfig {
    var databaseURL = "https://sovereignboard-74e2c-default-rtdb.firebaseio.com"
    var dynamicLinkBase = "https://sovereign-board2.app/challenge"
}

struct ChallengeRoom: Codable {
    var theme: String
    var status: String
    var turn: String
    var players: [String: String?]
    var createdAt: TimeInterval
}

struct RemoteMove: Codable {
    let from: BoardSquare
    let to: BoardSquare
    let byColor: String
    let promotion: String?
    let createdAt: TimeInterval
}

enum LinkRoomError: Error {
    case invalidURL
    case roomUnavailable
}

final class LinkRoomService {
    private let config: FirebaseConfig
    private let session: URLSession

    init(config: FirebaseConfig = FirebaseConfig(), session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func makeRoomId() -> String {
        String(UUID().uuidString.prefix(6)).uppercased()
    }

    func challengeURL(roomId: String) -> URL {
        URL(string: "\(config.dynamicLinkBase)?room=\(roomId)")!
    }

    func createRoom(name: String, region: RegionTheme) async throws -> (roomId: String, url: URL) {
        let roomId = makeRoomId()
        let room = ChallengeRoom(
            theme: region.id,
            status: "waiting",
            turn: PieceColor.white.rawValue,
            players: ["w": name, "b": nil],
            createdAt: Date().timeIntervalSince1970
        )
        try await put(room, path: "rooms/\(roomId)")
        return (roomId, challengeURL(roomId: roomId))
    }

    func joinRoom(roomId: String, name: String) async throws -> ChallengeRoom {
        var room: ChallengeRoom = try await get(path: "rooms/\(roomId)")
        guard room.players["b"] == nil else { throw LinkRoomError.roomUnavailable }
        room.players["b"] = name
        room.status = "active"
        try await put(room, path: "rooms/\(roomId)")
        return room
    }

    func push(move: ChessMove, by color: PieceColor, roomId: String) async throws {
        let remote = RemoteMove(
            from: move.from,
            to: move.to,
            byColor: color.rawValue,
            promotion: move.promotion?.rawValue,
            createdAt: Date().timeIntervalSince1970
        )
        try await post(remote, path: "rooms/\(roomId)/moves")
    }

    private func url(path: String) throws -> URL {
        guard let url = URL(string: "\(config.databaseURL)/\(path).json") else {
            throw LinkRoomError.invalidURL
        }
        return url
    }

    private func get<T: Decodable>(path: String) async throws -> T {
        let (data, _) = try await session.data(from: try url(path: path))
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func put<T: Encodable>(_ value: T, path: String) async throws {
        var request = URLRequest(url: try url(path: path))
        request.httpMethod = "PUT"
        request.httpBody = try JSONEncoder().encode(value)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try await session.data(for: request)
    }

    private func post<T: Encodable>(_ value: T, path: String) async throws {
        var request = URLRequest(url: try url(path: path))
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(value)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try await session.data(for: request)
    }
}
