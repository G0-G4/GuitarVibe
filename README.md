# ChordCoach

Offline-first chord play-along app (Yousician-lite): play songs by chords with timing, accompaniment, and scoring.

**Current focus:** macOS. Android / iOS / Windows later via the same Flutter project.

## Docs

- [Product & implementation plan](docs/PLAN.md) — phases, stack, decisions
- [Song format](docs/SONG_FORMAT.md) — `.song.json` and ChordPro

## Quick start (macOS)

```bash
cd app
flutter pub get
flutter run -d macos
```

Requires [Flutter](https://docs.flutter.dev/get-started/install) stable, Xcode, and [CocoaPods](https://cocoapods.org/) (for audio plugins on macOS).

## How songs work

- Bundled songs live in `app/assets/songs/*/song.json`
- Authoring is **text-only** (no in-app editor): edit `.song.json` or ChordPro `.cho`
- Optional backing audio next to the song; otherwise metronome clicks

## Play-along (Phase 1)

From a song detail screen tap **Play**:

1. One-bar count-in with metronome
2. Horizontal chord scroller + lyrics in time
3. Pause / resume / restart
4. End screen (scoring comes in Phase 3)

## Roadmap (short)

| Phase | Status |
|---|---|
| 0 Foundation (library, format, macOS) | done |
| 1 Play-along + audio/metronome | done |
| 2 Import `.cho` / `.song.json` files | next |
| 3 Mic scoring + live early/late feedback | planned |
| 4 More platforms + polish | planned |
| 5 Online catalog | later |

See [docs/PLAN.md](docs/PLAN.md) for details.
