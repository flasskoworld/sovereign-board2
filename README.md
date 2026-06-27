# Sovereign Board 2

SwiftUI mobile-first port of `flasskoworld/sovereign-board-2`, reworked around the world-map architecture from the Claude design thread.

## What changed

- The old web game's chess board, themed opponents, codex notes, move log, AI opponent, and challenge-link idea are now represented in Swift.
- The app opens on a color-coded overworld map instead of a plain board.
- Tapping a region zooms into a Mario-style route with lesson, history, match, optional aggressive/conservative, online, and grandmaster nodes.
- Match nodes launch a playable chess board skinned by the selected region.
- Online nodes can create Firebase Realtime Database challenge rooms using the same `/rooms/{roomId}` shape as the original web app.

## Current architecture

- `WorldModel.swift` contains the region catalog, map positions, node routes, personas, and color themes.
- `ChessEngine.swift` contains board state, legal move generation, check detection, castling, en passant, promotion, a light CPU move picker, codex notes, and move logging.
- `LinkRoomService.swift` contains the Firebase REST challenge-link service.
- `Views.swift` contains the SwiftUI overworld, region route, lesson, online, and board screens.
- `Tests/SovereignBoard2Tests` covers core chess behavior.

## Run locally

Open the package in Xcode 16 or newer and run the `SovereignBoard2` scheme on an iPhone simulator.

You can also verify the core code from the command line:

```sh
swift test
```

## Firebase notes

The REST service points at the existing project from the old repo:

```txt
https://sovereignboard-74e2c-default-rtdb.firebaseio.com
```

It expects rules equivalent to:

```json
{
  "rules": {
    "rooms": {
      "$roomId": {
        ".read": true,
        ".write": true
      }
    }
  }
}
```

For App Store shipping, replace the temporary `dynamicLinkBase` in `FirebaseConfig` with the production Universal Link domain for this app.
