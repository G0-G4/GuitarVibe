# Song format (v1)

Canonical playable format: **`.song.json`**.  
Human-friendly authoring: **ChordPro `.cho`** (imported or precompiled to JSON).  
No in-app editor — edit files in any text editor.

## `.song.json` schema

```json
{
  "schemaVersion": 1,
  "id": "training-c-g-am-f",
  "title": "Training: C–G–Am–F",
  "artist": "ChordCoach",
  "key": "C",
  "capo": 0,
  "tempoBpm": 90,
  "timeSignature": [4, 4],
  "tags": ["training"],
  "audio": null,
  "sections": [
    {
      "id": "loop",
      "name": "Loop",
      "events": [
        {
          "beat": 0,
          "durationBeats": 4,
          "chord": "C",
          "lyrics": ""
        }
      ]
    }
  ],
  "accompaniment": {
    "style": "metronome_and_pad",
    "volume": 0.7
  }
}
```

### Fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `schemaVersion` | int | yes | Currently `1` |
| `id` | string | yes | Stable id, filename-friendly |
| `title` | string | yes | |
| `artist` | string | yes | |
| `key` | string | no | e.g. `C`, `F#m` |
| `capo` | int | no | Default `0` |
| `tempoBpm` | number | yes | Beats per minute |
| `timeSignature` | `[int, int]` | yes | e.g. `[4, 4]` |
| `tags` | string[] | no | |
| `audio` | object \| null | no | Backing track; see below |
| `sections` | Section[] | yes | At least one |
| `accompaniment` | object | no | Synth/metronome prefs when no audio |

### `audio` (optional)

```json
"audio": {
  "file": "audio/loop.ogg",
  "offsetSec": 0.0,
  "durationSec": 32.0
}
```

- Relative to song pack directory or app documents.
- When present, playback position is the master clock.
- `offsetSec`: song beat 0 maps to this time in the file.

### `Section`

| Field | Type | Notes |
|---|---|---|
| `id` | string | |
| `name` | string | Display name |
| `events` | ChordEvent[] | Ordered by `beat` |

### `ChordEvent`

| Field | Type | Notes |
|---|---|---|
| `beat` | number | Start in beats from section start (or absolute from song start — v1: **absolute from song start** after flatten; in file can be section-local — see loader) |
| `durationBeats` | number | Length in beats |
| `chord` | string | e.g. `Am`, `F#m`, `G7`, `N.C.` |
| `lyrics` | string | Optional lyric fragment for this span |

**v1 convention:** `beat` is **absolute from the start of the song** (not reset per section). Sections only group for display.

### Accompaniment styles (v1)

| `style` | Behavior |
|---|---|
| `metronome` | Clicks only |
| `metronome_and_pad` | Click + sustained chord tones (when implemented) |
| `none` | Silent (user plays alone; UI still scrolls) |

If `audio` is set, audio is preferred; `accompaniment` is ignored or used as click track overlay later.

---

## ChordPro import (`.cho`)

Supported directives:

```
{title: ...}
{artist: ...}
{key: ...}
{capo: N}
{tempo: N}
{time: 4/4}
{duration: 4}          default beats per chord
{start_of_verse}
{end_of_verse}
{start_of_chorus}
{end_of_chorus}
{comment: ...}
```

Inline chords: `lyrics [Am]more [G]text`.

### Timing without an editor

1. Set `{tempo: 90}` and `{duration: 4}` (one bar per chord in 4/4).
2. Optional extension: `[Am@2]` means chord `Am` for 2 beats (documented extension; not standard ChordPro).
3. For precise control, write `.song.json` directly.

Missing tempo → default `120`. Missing duration → `4` beats.

### Example `.cho`

```chordpro
{title: Training Progression}
{artist: ChordCoach}
{key: C}
{tempo: 90}
{time: 4/4}
{duration: 4}

{start_of_verse}
[C] [G] [Am] [F]
{end_of_verse}
```

---

## Chord names

- Root: `A`–`G` with optional `#` / `b`
- Quality: `m`, `maj7`, `7`, `sus4`, `dim`, `aug`, …
- `N.C.` / `NC` = no chord
- Capo is metadata for display/scoring; stored chords are as written (as-fingered or concert — v1: **as written in file**)

Chord tone sets for scoring live in `assets/chords/chords.json` (Phase 3).

---

## File layout (bundled)

```
assets/songs/
  training-c-g-am-f/
    song.json
  swing-low/
    song.json
    source.cho          # optional reference
  some-with-audio/
    song.json
    audio/backing.ogg
```

User imports copy into application support directory with the same shape.
