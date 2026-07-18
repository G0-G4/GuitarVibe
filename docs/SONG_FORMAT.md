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
  "strum": {
    "name": "Six-stroke",
    "unitBeats": 0.5,
    "steps": ["D", ".", "D", "U", ".", "D", "U", "."]
  },
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
| `strum` | object \| string \| null | no | Optional right-hand pattern ("бой"); see below |
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
- Large / commercial recordings should stay **local** (gitignored under
  `assets/songs/**/audio/*.{mp3,ogg,wav,m4a}`). If the file is missing at
  runtime, the app falls back to metronome + guitar guide.

### `strum` (optional) — right-hand pattern / «бой»

Visual guidance (arrows in the player) and **drives guitar guide audio** when
the synthetic guide is enabled (strum samples on `D`/`U`/`X`). Does **not**
affect scoring.

**Object form (canonical):**

```json
"strum": {
  "name": "Six-stroke",
  "unitBeats": 0.5,
  "steps": ["D", ".", "D", "U", ".", "D", "U", "."]
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string | no | Display label |
| `unitBeats` | number | yes* | Length of one step in beats (`0.5` = 8ths, `1` = quarters). *If omitted, derived as bar length ÷ step count |
| `steps` | string[] | yes | Ordered tokens (see table) |

**Step tokens**

| Token | UI | Meaning |
|---|---|---|
| `D` | ↓ | Downstroke |
| `U` | ↑ | Upstroke |
| `.` | · | Rest / no pick |
| `X` | × | Mute / chuck |
| other | · | Treated as rest (load still succeeds) |

The pattern **loops** from song beat 0:  
`stepIndex = floor(currentBeat / unitBeats) % steps.length`.

Cycle length in beats should usually match one bar (e.g. 8 × 0.5 = 4 in 4/4, or 6 × 0.5 = 3 in 3/4). Mismatch is allowed but may feel off-meter.

**Compact string form:**

```json
"strum": "D.DU.DU."
```

Each character is one step. `unitBeats` defaults to `timeSignature[0] / length` (one bar per cycle). Prefer a step count that divides the bar evenly (e.g. 8 steps in 4/4 → eighth notes).

**Examples**

| Pattern | JSON | Notes |
|---|---|---|
| Down every beat | `{"name":"Downstrums","unitBeats":1,"steps":["D","D","D","D"]}` | Stage-1 training |
| Шестёрка | `"D.DU.DU."` or object with 8 × `unitBeats: 0.5` | Classic beginner бой (full bar) |
| With mutes | `{"unitBeats":0.5,"steps":["D","X","D","U","X","D","U","."]}` | |

Omit `strum` entirely when the song has no prescribed right-hand pattern.

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
| `metronome` | Clicks + optional guitar guide (user volume) |
| `metronome_and_pad` | Clicks + guitar guide (pad on chord change; strum samples if `strum` set) |
| `none` | Silent (user plays alone; UI still scrolls) |

**Guitar guide (synthetic reference):** bundled pluck samples (MIDI C3–C5) play
chord tones so the user can listen and play along. Without `strum`, a soft pad
fires on each chord change. With `strum`, down/up strokes arpeggiate the
voicing; `X` plays a mute chuck. User volume: Settings → Guitar guide volume
(0 = off). Prefer headphones when mic scoring is on (guide can bleed into the mic).

If `audio` is set, backing audio is preferred as master clock; after music starts,
metronome + guide are silent (count-in still uses the metronome).

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

Scoring (Phase 3) resolves chord tones **algorithmically** from the symbol
(root + quality → pitch classes). Unknown qualities fall back to a major or
minor triad. Optional `assets/chords/chords.json` overrides are not required for v1.

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
