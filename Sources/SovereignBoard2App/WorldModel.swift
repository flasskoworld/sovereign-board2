import SwiftUI

enum NodeKind: String, CaseIterable, Codable, Identifiable {
    case lesson
    case history
    case match
    case optionalAggressive
    case optionalConservative
    case online
    case boss

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lesson: "Lesson"
        case .history: "History"
        case .match: "Match"
        case .optionalAggressive: "Aggressor"
        case .optionalConservative: "Wall"
        case .online: "Online"
        case .boss: "Grandmaster"
        }
    }

    var symbol: String {
        switch self {
        case .lesson: "book.closed.fill"
        case .history: "scroll.fill"
        case .match: "figure.fencing"
        case .optionalAggressive: "flame.fill"
        case .optionalConservative: "shield.fill"
        case .online: "globe"
        case .boss: "crown.fill"
        }
    }
}

struct RegionTheme: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let shortName: String
    let subtitle: String
    let persona: String
    let personaDescription: String
    let openingFocus: String
    let accentHex: String
    let darkHex: String
    let lightHex: String
    let mapPosition: CGPointValue
    let nodes: [RegionNode]

    var accent: Color { Color(hex: accentHex) }
    var darkSquare: Color { Color(hex: darkHex) }
    var lightSquare: Color { Color(hex: lightHex) }
}

struct RegionNode: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let detail: String
    let kind: NodeKind
    let x: Double
    let y: Double
}

struct CGPointValue: Codable, Hashable {
    let x: Double
    let y: Double
}

enum WorldCatalog {
    static let regions: [RegionTheme] = [
        RegionTheme(
            id: "india",
            name: "India",
            shortName: "India",
            subtitle: "Origin tutorial",
            persona: "The Acharya",
            personaDescription: "Teaches piece identity, center control, and the first habits of board vision.",
            openingFocus: "Chaturanga roots, Indian defenses",
            accentHex: "#2FAE76",
            darkHex: "#17312A",
            lightHex: "#C9D2D6",
            mapPosition: .init(x: 0.66, y: 0.55),
            nodes: standardNodes(prefix: "india", lesson: "Chaturanga", opening: "Fianchetto wisdom", boss: "Acharya's Crown")
        ),
        RegionTheme(
            id: "persia",
            name: "Persia and the Arab World",
            shortName: "Persia",
            subtitle: "Tactics and mates",
            persona: "The Shah",
            personaDescription: "Elegant and tactical. Uses diagonals, passed pawns, and long-range threats.",
            openingFocus: "Shatranj, mansubat, checkmate patterns",
            accentHex: "#2FB7C7",
            darkHex: "#183D4C",
            lightHex: "#8ED6CF",
            mapPosition: .init(x: 0.58, y: 0.48),
            nodes: standardNodes(prefix: "persia", lesson: "Mansubat", opening: "Basic mates", boss: "The Shah")
        ),
        RegionTheme(
            id: "north-africa",
            name: "North Africa",
            shortName: "N. Africa",
            subtitle: "The crossing",
            persona: "The Caravan",
            personaDescription: "A bridge region focused on history, routes, and survival under pressure.",
            openingFocus: "Shatranj crosses into Europe",
            accentHex: "#D9622B",
            darkHex: "#2C1D16",
            lightHex: "#E8B48A",
            mapPosition: .init(x: 0.47, y: 0.55),
            nodes: bridgeNodes(prefix: "africa")
        ),
        RegionTheme(
            id: "spain",
            name: "Spain",
            shortName: "Spain",
            subtitle: "Modern chess is born",
            persona: "Ruy Lopez",
            personaDescription: "Principled and direct. Develops cleanly, castles, and pressures the center.",
            openingFocus: "Ruy Lopez",
            accentHex: "#C9A227",
            darkHex: "#3A2E1F",
            lightHex: "#D9B97A",
            mapPosition: .init(x: 0.43, y: 0.45),
            nodes: standardNodes(prefix: "spain", lesson: "Power queen era", opening: "Ruy Lopez", boss: "Ruy's Chapel")
        ),
        RegionTheme(
            id: "italy",
            name: "Italy",
            shortName: "Italy",
            subtitle: "Romantic attacks",
            persona: "The Maestro",
            personaDescription: "Sacrifices for initiative and asks whether your king is truly safe.",
            openingFocus: "Italian Game, Fried Liver, Evans Gambit",
            accentHex: "#B73832",
            darkHex: "#4D2522",
            lightHex: "#D8C2A0",
            mapPosition: .init(x: 0.48, y: 0.44),
            nodes: standardNodes(prefix: "italy", lesson: "Giuoco Piano", opening: "Fried Liver", boss: "The Maestro")
        ),
        RegionTheme(
            id: "france",
            name: "France",
            shortName: "France",
            subtitle: "Pawn strategy",
            persona: "Philidor",
            personaDescription: "Claims that pawns are the soul of chess, then proves it slowly.",
            openingFocus: "French Defense, Philidor Defense",
            accentHex: "#4FC3F7",
            darkHex: "#1A2C42",
            lightHex: "#CFD8E3",
            mapPosition: .init(x: 0.45, y: 0.39),
            nodes: standardNodes(prefix: "france", lesson: "Pawn chains", opening: "French Defense", boss: "Philidor's Salon")
        ),
        RegionTheme(
            id: "england",
            name: "England",
            shortName: "England",
            subtitle: "Tournament culture",
            persona: "The Crown",
            personaDescription: "Reserved and defensive. Fortifies first, then converts small advantages late.",
            openingFocus: "English Opening, Staunton standards",
            accentHex: "#D8B14A",
            darkHex: "#263F51",
            lightHex: "#C5D2D7",
            mapPosition: .init(x: 0.43, y: 0.34),
            nodes: standardNodes(prefix: "england", lesson: "London 1851", opening: "English Opening", boss: "The Crown")
        ),
        RegionTheme(
            id: "central-europe",
            name: "Central Europe",
            shortName: "Vienna",
            subtitle: "Positional school",
            persona: "The Architect",
            personaDescription: "Methodical and exact. Builds structural traps and rarely overextends.",
            openingFocus: "Vienna, Berlin, Caro-Kann",
            accentHex: "#B68AF2",
            darkHex: "#412B5D",
            lightHex: "#D2BEE9",
            mapPosition: .init(x: 0.49, y: 0.36),
            nodes: standardNodes(prefix: "europe", lesson: "Steinitz principles", opening: "Caro-Kann", boss: "The Architect")
        ),
        RegionTheme(
            id: "americas",
            name: "The Americas",
            shortName: "Americas",
            subtitle: "Player heroes",
            persona: "The Prodigy",
            personaDescription: "Fast development, open lines, and sudden tactical clarity.",
            openingFocus: "Morphy, Torre Attack, Mexican Defense, Chess960",
            accentHex: "#FF7A59",
            darkHex: "#16352F",
            lightHex: "#BFE3D8",
            mapPosition: .init(x: 0.22, y: 0.47),
            nodes: standardNodes(prefix: "americas", lesson: "Morphy lines", opening: "Mexican Defense", boss: "The Prodigy")
        ),
        RegionTheme(
            id: "summit",
            name: "Grandmaster Summit",
            shortName: "Summit",
            subtitle: "The loop closes",
            persona: "The Champion",
            personaDescription: "A final gauntlet where old routes meet modern championship chess.",
            openingFocus: "Review gauntlet and title match",
            accentHex: "#F28C28",
            darkHex: "#3F2613",
            lightHex: "#F0C06D",
            mapPosition: .init(x: 0.63, y: 0.43),
            nodes: summitNodes
        )
    ]

    static func region(id: String) -> RegionTheme {
        regions.first { $0.id == id } ?? regions[0]
    }

    private static func standardNodes(prefix: String, lesson: String, opening: String, boss: String) -> [RegionNode] {
        [
            .init(id: "\(prefix)-origin", title: "Origins", detail: lesson, kind: .history, x: 0.13, y: 0.78),
            .init(id: "\(prefix)-match-1", title: "Local Rival", detail: "A balanced sparring match.", kind: .match, x: 0.28, y: 0.62),
            .init(id: "\(prefix)-opening", title: opening, detail: "Learn the idea, then play it.", kind: .lesson, x: 0.45, y: 0.52),
            .init(id: "\(prefix)-aggressor", title: "Aggressor", detail: "Optional gambits and sacrifices.", kind: .optionalAggressive, x: 0.48, y: 0.25),
            .init(id: "\(prefix)-wall", title: "The Wall", detail: "Optional conservative grinder.", kind: .optionalConservative, x: 0.62, y: 0.70),
            .init(id: "\(prefix)-online", title: "Online Gate", detail: "Create or join a challenge link.", kind: .online, x: 0.74, y: 0.47),
            .init(id: "\(prefix)-boss", title: boss, detail: "Defeat the regional grandmaster.", kind: .boss, x: 0.88, y: 0.30)
        ]
    }

    private static func bridgeNodes(prefix: String) -> [RegionNode] {
        [
            .init(id: "\(prefix)-route", title: "Caravan Route", detail: "How shatranj moved west.", kind: .history, x: 0.18, y: 0.63),
            .init(id: "\(prefix)-mate", title: "Mate Net", detail: "Practice forcing patterns.", kind: .lesson, x: 0.38, y: 0.52),
            .init(id: "\(prefix)-crossing", title: "The Crossing", detail: "Win a pressure match.", kind: .match, x: 0.58, y: 0.42),
            .init(id: "\(prefix)-senterej", title: "Senterej Echo", detail: "Optional no-theory opener.", kind: .optionalAggressive, x: 0.53, y: 0.76),
            .init(id: "\(prefix)-online", title: "Online Gate", detail: "Challenge a friend.", kind: .online, x: 0.74, y: 0.55),
            .init(id: "\(prefix)-boss", title: "Gatekeeper", detail: "Open the route to Spain.", kind: .boss, x: 0.88, y: 0.33)
        ]
    }

    private static let summitNodes: [RegionNode] = [
        .init(id: "summit-review", title: "Opening Review", detail: "A fast tour through every badge.", kind: .lesson, x: 0.14, y: 0.76),
        .init(id: "summit-tactics", title: "Tactics Trial", detail: "No quiet wins here.", kind: .match, x: 0.30, y: 0.58),
        .init(id: "summit-endgame", title: "Endgame Trial", detail: "Convert the smallest edge.", kind: .optionalConservative, x: 0.48, y: 0.42),
        .init(id: "summit-online", title: "World Gate", detail: "Online matchmaking hub.", kind: .online, x: 0.64, y: 0.61),
        .init(id: "summit-boss", title: "Title Match", detail: "The crown returns to the origin route.", kind: .boss, x: 0.86, y: 0.31)
    ]
}

extension Color {
    init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
