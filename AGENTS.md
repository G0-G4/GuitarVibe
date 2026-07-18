# AGENTS.md — GuitarVibe

Guidance for AI coding agents working in this repository.

## What this project is

**GuitarVibe** — offline-first chord play-along app (Yousician-lite):

- Play songs by **chords** with timing UI
- Accompaniment: **backing audio first**, metronome/synth fallback
- Scoring via mic + pitch detection with live feedback (good / early / late / miss)
- Import songs as **text files** (no in-app song editor)
- Bundled starter song pack; online catalog is later

Product plan and roadmap: [`docs/PLAN.md`](docs/PLAN.md)  
Song format: [`docs/SONG_FORMAT.md`](docs/SONG_FORMAT.md)

## Source of truth

| Doc | Role |
|---|---|
| `docs/PLAN.md` | Phases, scope, decisions — follow this |
| `docs/SONG_FORMAT.md` | `.song.json` + ChordPro conventions |
| `AGENTS.md` | How to work in this repo (this file) |
| `README.md` | Human quick start |

When scope is unclear, prefer `docs/PLAN.md` over inventing features.

## Current focus

- **Platform:** macOS only (primary dev machine). Do not add Android/iOS/Windows targets until Phase 4 unless explicitly asked.
- **Phase:** see checklist in `docs/PLAN.md`. Complete exit criteria before jumping ahead.
- **App code:** `app/` (Flutter package `guitar_vibe`)

## Stack

| Layer | Choice |
|---|---|
| UI | Flutter 3.x, Material 3 |
| Language | Dart |
| State | `flutter_riverpod` |
| Routing | `go_router` |
| Songs | JSON assets + later local files |
| Tests | `flutter_test` |

Do not introduce another state management or navigation library without a clear reason.

## Repo layout

```
guitar/
├── AGENTS.md
├── README.md
├── docs/
│   ├── PLAN.md
│   └── SONG_FORMAT.md
└── app/                      # Flutter project
    ├── lib/
    │   ├── main.dart
    │   ├── core/             # theme, router
    │   ├── domain/           # pure models (Song, etc.)
    │   ├── data/             # repositories, parsers, I/O
    │   ├── features/         # library, player, scoring, import, settings
    │   └── audio/            # accompaniment + pitch facades (when added)
    ├── assets/songs/         # bundled .song.json (+ optional audio)
    ├── macos/                # only platform enabled for now
    └── test/
```

## Architecture rules

1. **Domain stays pure** — no Flutter UI imports in `domain/`.
2. **Features own UI** — screens/widgets under `features/<name>/`; shared widgets only when reused twice+.
3. **Data layer loads songs** — parsing ChordPro / JSON lives in `data/`, not in widgets.
4. **Play clock is single source of time** — UI scroller, accompaniment, and scoring all read the same beat/position (see plan).
5. **Offline by default** — no network required for MVP; do not add online deps early.
6. **No in-app song editor** — authoring is external text (`.song.json` / `.cho`). Import = file pick + parse only.
7. **Accompaniment policy** — if `audio` is set on a song, prefer playing that file as master clock; otherwise metronome / simple synth.

## Song authoring

- Canonical runtime format: **`.song.json`** (beat-based timeline).
- Human format: **ChordPro `.cho`** with `{tempo}`, `{duration}`, optional `[Am@2]` extension (see `SONG_FORMAT.md`).
- Register bundled songs in `app/assets/songs/index.json` and list asset folders in `app/pubspec.yaml`.
- Prefer public-domain / original training content for demos.

## Coding conventions

- Match existing style: clear names, small focused files, English identifiers and UI strings for now.
- Prefer simple, readable Dart over clever abstractions.
- Keep PRs/changes phase-scoped — do not “also polish Phase 4” while implementing Phase 1.
- Update `docs/PLAN.md` checkboxes when a phase item is actually done.
- If song schema changes, update `docs/SONG_FORMAT.md` and demo songs in the same change.
- Avoid drive-by refactors and unrelated file edits.

## Commands (from `app/`)

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d macos
flutter build macos --debug
```

Always run `flutter analyze` and relevant tests after non-trivial code changes.

## Phase map (do not skip exit criteria)

| Phase | Goal |
|---|---|
| 0 | Foundation: format, library UI, bundled songs, macOS — **done when list + detail work** |
| 1 | Play-along: clock, scroller, audio/metronome |
| 2 | Import `.cho` / `.song.json` via file picker (no editor) |
| 3 | Mic scoring + live good/early/late/miss |
| 4 | Polish, more platforms, optional BPM-from-audio |
| 5 | Online catalog |

## Explicit non-goals (until plan says otherwise)

- In-app visual song editor
- Full polyphonic chord recognition ML in v1
- Auto chord transcription from mixed audio (research only)
- Web target
- Online auth / catalog (Phase 5+)
- Lessons tree, social, subscriptions

## When implementing a feature

1. Read the relevant section of `docs/PLAN.md` and `SONG_FORMAT.md`.
2. Implement the smallest vertical slice that meets the phase exit criteria.
3. Add/adjust unit tests for parsers, models, score math.
4. Verify on macOS (`flutter run -d macos` or at least `flutter test` + `analyze`).
5. Mark completed checklist items in `docs/PLAN.md`.

## Commit / change hygiene

- Do not commit secrets or large copyrighted audio without license notes.
- Keep generated/build artifacts out of git (`app/build/`, `.dart_tool/`, etc.).
- Prefer focused commits: one concern (e.g. “play clock + metronome”).
