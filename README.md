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

## Play-along

From a song detail screen tap **Play**:

1. One-bar count-in with metronome
2. Horizontal chord scroller + lyrics in time
3. Live scoring badge (Good / Early / Late / Miss) when mic scoring is on
4. Pause / resume / restart
5. End screen with accuracy and hit breakdown

Toggle scoring and **recognition mode** in **Settings** (library gear icon).  
**Mic Lab** (waveform icon): play a chord, compare modes, and **calibrate room / guitar** so the app gates ambient noise and adapts thresholds.  
**My chords** (Settings): limit free recognition to the chords you practice (e.g. C–G–Am–F).

macOS will ask for microphone access.

## Roadmap (short)

| Phase | Status |
|---|---|
| 0 Foundation (library, format, macOS) | done |
| 1 Play-along + audio/metronome | done |
| 2 Import `.cho` / `.song.json` files | deferred |
| 3 Mic scoring + live early/late feedback | done |
| 4 More platforms + polish | next |
| 5 Online catalog | later |

See [docs/PLAN.md](docs/PLAN.md) for details.
