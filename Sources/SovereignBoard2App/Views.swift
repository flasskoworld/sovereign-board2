import SwiftUI

struct RootView: View {
    @State private var selectedRegion: RegionTheme?
    @State private var activeNode: RegionNode?

    var body: some View {
        NavigationStack {
            ZStack {
                PixelBackdrop(accent: selectedRegion?.accent ?? Color(hex: "#C9A227"))
                    .ignoresSafeArea()
                if let selectedRegion {
                    RegionRouteView(region: selectedRegion, activeNode: $activeNode) {
                        withAnimation(.snappy) { self.selectedRegion = nil }
                    }
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                } else {
                    WorldMapView(selectedRegion: $selectedRegion)
                        .transition(.scale(scale: 1.08).combined(with: .opacity))
                }
            }
            .navigationDestination(item: $activeNode) { node in
                let region = selectedRegion ?? WorldCatalog.regions[0]
                if [.match, .optionalAggressive, .optionalConservative, .boss, .online].contains(node.kind) {
                    GameView(region: region, node: node)
                } else {
                    LessonView(region: region, node: node)
                }
            }
        }
    }
}

struct WorldMapView: View {
    @Binding var selectedRegion: RegionTheme?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sovereign Board")
                    .font(.system(size: 34, weight: .black, design: .serif))
                Text("Choose a colored region, then clear its route of lessons, matches, optional styles, online gates, and the grandmaster.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)

            GeometryReader { proxy in
                ZStack {
                    PixelWorldShape()
                        .fill(.black.opacity(0.18))
                        .overlay(PixelWorldShape().stroke(.white.opacity(0.13), lineWidth: 2))

                    ForEach(WorldCatalog.regions) { region in
                        RegionPin(region: region)
                            .position(
                                x: proxy.size.width * region.mapPosition.x,
                                y: proxy.size.height * region.mapPosition.y
                            )
                            .onTapGesture {
                                withAnimation(.snappy) { selectedRegion = region }
                            }
                    }
                }
                .padding(12)
            }
            .frame(maxHeight: 430)
            .padding(.horizontal, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(WorldCatalog.regions) { region in
                        Button {
                            withAnimation(.snappy) { selectedRegion = region }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(region.shortName.uppercased())
                                    .font(.caption.weight(.bold).monospaced())
                                Text(region.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 112, alignment: .leading)
                            .padding(12)
                            .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(region.accent, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
        .foregroundStyle(.white)
    }
}

struct RegionRouteView: View {
    let region: RegionTheme
    @Binding var activeNode: RegionNode?
    let back: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button(action: back) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 42, height: 42)
                        .background(.black.opacity(0.22), in: Circle())
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 3) {
                    Text(region.name)
                        .font(.system(size: 28, weight: .black, design: .serif))
                    Text(region.openingFocus)
                        .font(.caption.weight(.semibold).monospaced())
                        .foregroundStyle(region.accent)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)

            GeometryReader { proxy in
                ZStack {
                    RoutePath(nodes: region.nodes)
                        .stroke(region.accent.opacity(0.78), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                    ForEach(region.nodes) { node in
                        RouteNodeButton(region: region, node: node)
                            .position(x: proxy.size.width * node.x, y: proxy.size.height * node.y)
                            .onTapGesture { activeNode = node }
                    }
                }
                .padding(18)
                .background(region.darkSquare.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(region.persona)
                            .font(.headline)
                        Text(region.personaDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                }
            }
            .padding(.horizontal, 18)

            Text("The main route leads to the grandmaster. Branches add aggressive, conservative, and online play without blocking the lesson path.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
        }
        .foregroundStyle(.white)
    }
}

struct GameView: View {
    let region: RegionTheme
    let node: RegionNode
    @State private var game = ChessGame()
    @State private var challengeURL: URL?
    @State private var playerName = "Player"
    @State private var creatingLink = false
    private let linkService = LinkRoomService()

    var body: some View {
        ZStack {
            PixelBackdrop(accent: region.accent)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    ChessBoardView(game: game, region: region)
                    statusBar
                    if node.kind == .online { onlinePanel }
                    sidePanel
                }
                .padding(16)
            }
        }
        .navigationTitle(node.title)
        .inlineNavigationTitleWhenAvailable()
        .onAppear {
            game.reset()
            if node.kind == .online { game.playerColor = .white }
        }
        .onChange(of: game.turn) { _, newTurn in
            guard node.kind != .online, newTurn != game.playerColor else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                await MainActor.run { game.performAIMove(region: region) }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(node.kind.label.uppercased())
                .font(.caption.weight(.bold).monospaced())
                .foregroundStyle(region.accent)
            Text(node.title)
                .font(.system(size: 30, weight: .black, design: .serif))
            Text(node.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.white)
    }

    private var statusBar: some View {
        HStack {
            Text(game.gameOverMessage ?? (game.turn == game.playerColor ? "Your move: \(game.playerColor.label)" : "\(region.persona) is thinking"))
                .font(.callout.weight(.semibold).monospaced())
            Spacer()
            Button {
                game.reset(playerColor: game.playerColor)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.bordered)
        }
        .foregroundStyle(.white)
    }

    private var onlinePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Challenge Link")
                .font(.headline)
            TextField("Your name", text: $playerName)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await createChallengeLink() }
            } label: {
                Label(creatingLink ? "Creating" : "Create Challenge", systemImage: "link")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(region.accent)
            .disabled(creatingLink)
            if let challengeURL {
                ShareLink(item: challengeURL) {
                    Label(challengeURL.absoluteString, systemImage: "square.and.arrow.up")
                        .font(.caption.monospaced())
                        .lineLimit(2)
                }
            }
        }
        .padding(14)
        .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
        .foregroundStyle(.white)
    }

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Opponent")
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(region.accent)
                Text(region.persona)
                    .font(.headline)
                Text(region.personaDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider().overlay(.white.opacity(0.18))
            VStack(alignment: .leading, spacing: 5) {
                Text("Codex")
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(region.accent)
                Text(game.codexNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider().overlay(.white.opacity(0.18))
            VStack(alignment: .leading, spacing: 7) {
                Text("Move Log")
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(region.accent)
                if game.moveLog.isEmpty {
                    Text("-")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(game.moveLog.prefix(8)) { entry in
                        Text("\(entry.player) · \(entry.notation)")
                            .font(.caption.monospaced())
                    }
                }
            }
        }
        .padding(14)
        .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
        .foregroundStyle(.white)
    }

    private func createChallengeLink() async {
        creatingLink = true
        defer { creatingLink = false }
        do {
            let result = try await linkService.createRoom(name: playerName, region: region)
            challengeURL = result.url
        } catch {
            challengeURL = URL(string: "https://sovereign-board2.app/challenge?room=OFFLINE")
        }
    }
}

extension View {
    @ViewBuilder
    func inlineNavigationTitleWhenAvailable() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

struct ChessBoardView: View {
    let game: ChessGame
    let region: RegionTheme

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                ForEach(0..<8, id: \.self) { row in
                    ForEach(0..<8, id: \.self) { col in
                        square(row: row, col: col, side: side)
                    }
                }
            }
            .frame(width: side, height: side)
            .background(.black.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(region.accent.opacity(0.9), lineWidth: 2))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func square(row: Int, col: Int, side: CGFloat) -> some View {
        let square = BoardSquare(row: row, col: col)
        let isLight = (row + col).isMultiple(of: 2)
        let legal = game.legalTargets.contains { $0.to == square }
        let selected = game.selected == square
        return ZStack {
            Rectangle()
                .fill(isLight ? region.lightSquare : region.darkSquare)
                .overlay(selected ? region.accent.opacity(0.45) : .clear)
                .overlay(legal ? Circle().fill(region.accent.opacity(0.55)).frame(width: side / 34) : nil)
            if let piece = game.piece(at: square) {
                Text(piece.kind.glyph)
                    .font(.system(size: side / 12, weight: .bold))
                    .foregroundStyle(piece.color == .white ? .white : region.accent)
                    .shadow(color: .black.opacity(0.75), radius: 1, x: 0, y: 2)
            }
        }
        .frame(width: side / 8, height: side / 8)
        .position(x: (CGFloat(col) + 0.5) * side / 8, y: (CGFloat(row) + 0.5) * side / 8)
        .onTapGesture { game.tap(square: square, region: region) }
    }
}

struct LessonView: View {
    let region: RegionTheme
    let node: RegionNode

    var body: some View {
        ZStack {
            PixelBackdrop(accent: region.accent)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Text(node.kind.label.uppercased())
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(region.accent)
                Text(node.title)
                    .font(.system(size: 34, weight: .black, design: .serif))
                Text(node.detail)
                    .font(.title3.weight(.semibold))
                Text("\(region.name) focuses on \(region.openingFocus). This node is the lesson hook for the full curriculum content.")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(22)
        }
    }
}

struct RegionPin: View {
    let region: RegionTheme

    var body: some View {
        VStack(spacing: 5) {
            Circle()
                .fill(region.accent)
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 3))
            Text(region.shortName)
                .font(.caption2.weight(.bold).monospaced())
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 4))
        }
        .foregroundStyle(.white)
    }
}

struct RouteNodeButton: View {
    let region: RegionTheme
    let node: RegionNode

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: node.kind.symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: node.kind == .boss ? 58 : 48, height: node.kind == .boss ? 58 : 48)
                .background(color, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.8), lineWidth: 2))
            Text(node.title)
                .font(.caption2.weight(.bold).monospaced())
                .multilineTextAlignment(.center)
                .frame(width: 86)
        }
        .foregroundStyle(.white)
    }

    private var color: Color {
        switch node.kind {
        case .lesson: .cyan
        case .history: .mint
        case .match: region.accent
        case .optionalAggressive: .red
        case .optionalConservative: .blue
        case .online: .green
        case .boss: .yellow
        }
    }
}

struct RoutePath: Shape {
    let nodes: [RegionNode]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mainNodes = nodes.filter { ![.optionalAggressive, .optionalConservative].contains($0.kind) }
        guard let first = mainNodes.first else { return path }
        path.move(to: CGPoint(x: rect.width * first.x, y: rect.height * first.y))
        for node in mainNodes.dropFirst() {
            path.addLine(to: CGPoint(x: rect.width * node.x, y: rect.height * node.y))
        }
        if let branch = nodes.first(where: { $0.kind == .optionalAggressive }),
           let anchor = nodes.first(where: { $0.kind == .lesson }) {
            path.move(to: CGPoint(x: rect.width * anchor.x, y: rect.height * anchor.y))
            path.addLine(to: CGPoint(x: rect.width * branch.x, y: rect.height * branch.y))
        }
        if let branch = nodes.first(where: { $0.kind == .optionalConservative }),
           let anchor = nodes.first(where: { $0.kind == .match }) {
            path.move(to: CGPoint(x: rect.width * anchor.x, y: rect.height * anchor.y))
            path.addLine(to: CGPoint(x: rect.width * branch.x, y: rect.height * branch.y))
        }
        return path
    }
}

struct PixelBackdrop: View {
    let accent: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: "#080A0F")))
                let tick = timeline.date.timeIntervalSinceReferenceDate
                let spacing: CGFloat = 34
                for x in stride(from: -spacing, through: size.width + spacing, by: spacing) {
                    for y in stride(from: -spacing, through: size.height + spacing, by: spacing) {
                        let shift = CGFloat(Int(tick * 14) % Int(spacing))
                        let rect = CGRect(x: x + shift, y: y, width: 2, height: 2)
                        context.fill(Path(rect), with: .color(accent.opacity(0.35)))
                    }
                }
            }
        }
    }
}

struct PixelWorldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        func block(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
            path.addRect(CGRect(x: rect.width * x, y: rect.height * y, width: rect.width * w, height: rect.height * h))
        }
        block(0.05, 0.28, 0.20, 0.20)
        block(0.14, 0.48, 0.15, 0.24)
        block(0.34, 0.25, 0.18, 0.24)
        block(0.44, 0.43, 0.12, 0.24)
        block(0.55, 0.30, 0.28, 0.28)
        block(0.66, 0.58, 0.12, 0.18)
        block(0.82, 0.62, 0.10, 0.10)
        return path
    }
}
