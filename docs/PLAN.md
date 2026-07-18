# Plan: Offline Chord Coach (Yousician-lite)

## Goal

Сделать **офлайн-first** приложение для игры песен **по аккордам** с:

- отображением аккордов/текста в тайминге;
- оценкой игры (микрофон → pitch detection) и **live feedback** (попал / рано / поздно);
- музыкальным сопровождением (аудио-трек и/или синтез);
- загрузкой произвольных песен из **текстовых файлов** (без in-app редактора);
- стартовым набором зашитых песен.

**Платформы:** сначала **macOS** (основная dev-машина), позже Android / iOS / Windows тем же Flutter-кодом.

Позже (не в MVP): онлайн-каталог и загрузка своих песен.

План в репозитории: `docs/PLAN.md` — source of truth, идём по фазам.

---

## Product scope

### MVP (Phase 0–3) — «полный офлайн», macOS first

| Возможность | MVP | Позже |
|---|---|---|
| Библиотека песен (зашитый pack) | ✅ | — |
| Просмотр текста + аккордов | ✅ | — |
| Play-along: scrolling chords + clock | ✅ | — |
| Сопровождение: **audio file** (проще) и/или synth | ✅ audio first | synth styles |
| Импорт **текстовых** песен (ChordPro / `.song.json`) | ✅ file pick | — |
| In-app редактор тайминга | ❌ | optional |
| Live feedback: hit / early / late / miss | ✅ | — |
| Итоговый score | ✅ | — |
| Авто-тайминг из audio (beat/chord align) | ❌ research | Phase 4+ |
| Android / iOS / Windows targets | ❌ | Phase 4 |
| Онлайн-каталог | ❌ | Phase 5+ |

### UX-идея

1. Выбор песни → play (tempo override optional если нет locked audio).
2. Countdown → play mode: лента аккордов + текст + **мгновенный индикатор** (рано / хорошо / поздно / мимо).
3. Сопровождение: backing audio **или** метроном/synth.
4. В конце — score summary.

---

## Сопровождение: audio vs синтез

**Вопрос:** синтезировать аккомпанемент из аккордов или просто играть аудио?

| Подход | Плюсы | Минусы |
|---|---|---|
| **A. Backing audio** (mp3/ogg/wav рядом с песней) | Проще всего; «как оригинал»; low risk latency | Нужен файл; tempo change = time-stretch (сложно) или без change |
| **B. Синтез из аккордов** (pattern + soundfont) | Любая песня без audio; tempo ± freely; маленький pack | Звучит «MIDI-ish»; больше engine work |
| **C. Hybrid** (рекомендация) | Лучшее из двух | Два code path |

### Решение для MVP: **hybrid, audio-first**

1. Если у песни есть `audio` (путь к файлу) → **играем его** как master clock (position → current beat через `tempoBpm` + offset, или через explicit `audioOffsetSec`).
2. Если audio нет → **метроном + простой chord pad/strum** (минимальный synth/samples).
3. Позже: richer synth styles, optional time-stretch.

Это закрывает «просто проще» (audio) и «синтез из формата» (fallback + future).

В `.song.json`:

```json
"audio": {
  "file": "audio/wonderwall-backing.ogg",
  "offsetSec": 0.0,
  "durationSec": 210.5
}
```

`null` / отсутствует → synth/metronome path.

---

## Формат песен — без in-app редактора

Авторство и правка — **в любом текстовом редакторе**. Приложение только читает файлы.

### Два слоя

```
┌──────────────────────────────────────────┐
│  Authoring (text files)                  │
│  • ChordPro .cho  — lyrics + chords      │
│  • .song.json     — full timed playable  │
│  • optional audio file                   │
└──────────────────┬───────────────────────┘
                   │ load / import (no editor UI)
                   ▼
┌──────────────────────────────────────────┐
│  Runtime Song model                      │
└──────────────────────────────────────────┘
```

### ChordPro (удобный human format)

```chordpro
{title: Wonderwall}
{artist: Oasis}
{key: F#m}
{tempo: 87}
{time: 4/4}
{duration: 4}

[F#m]Today is gonna be the day that they're [A]gonna throw it back to you
```

**Тайминг без редактора:**

- `{tempo: N}` + `{duration: beats}` → каждый аккорд = N долей (default 4 = 1 bar in 4/4).
- Опционально inline: `[Am@2]` = 2 beats (расширение, документируем в SONG_FORMAT).
- Для bundled pack можно сразу коммитить готовый `.song.json`.

**Нет wizard/editor UI в MVP.** Import = «выбрать файл → parse → в библиотеку». Если чего-то не хватает (tempo) — defaults + warning, правка файла снаружи.

### Canonical `.song.json`

Beat-based timeline (tempo меняется без пересчёта структуры; с audio — tempo обычно fixed под трек).

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
  "audio": null,
  "sections": [
    {
      "id": "loop",
      "name": "Loop",
      "events": [
        { "beat": 0, "durationBeats": 4, "chord": "C", "lyrics": "" },
        { "beat": 4, "durationBeats": 4, "chord": "G", "lyrics": "" },
        { "beat": 8, "durationBeats": 4, "chord": "Am", "lyrics": "" },
        { "beat": 12, "durationBeats": 4, "chord": "F", "lyrics": "" }
      ]
    }
  ],
  "accompaniment": {
    "style": "metronome_and_pad",
    "volume": 0.7
  }
}
```

Подробности schema → `docs/SONG_FORMAT.md`.

### Авто-тайминг из audio — можно ли?

**Да, частично, но это отдельная сложная фича, не MVP.**

| Задача | Сложность | Как |
|---|---|---|
| Beat tracking / BPM estimate | средне | librosa-like / aubio / essentia; или ручной BPM |
| Align chord changes to beats | средне–сложно | нужен chord list + onset/beat grid; user-correctable |
| Chord recognition from audio | сложно | ML models, ошибки на dense mix |
| Full «drop audio + get playable song» | очень сложно | product-level R&D |

**MVP:** тайминг задаётся в тексте (`tempo` + duration per chord) или в `.song.json`.  
**Позже (Phase 4+):** optional «estimate BPM from audio» + snap events to beat grid; full auto-chord — research spike, не блокер.

Если есть audio + уже размеченные аккорды в ChordPro — достаточно `{tempo}` подогнать под трек вручную (или estimate BPM later).

---

## Live scoring feedback

Во время игры, не только в конце:

| Feedback | Условие (v1) |
|---|---|
| **Good** | pitch match в hit window (± threshold) |
| **Early** | match, но до ideal time |
| **Late** | match, но после ideal time |
| **Miss** | нет match в window / wrong pitch |

UI: compact badge у текущего аккорда + цвет; combo optional.  
Конец: accuracy %, early/late distribution, streak.

v1 scoring = pitch class ∈ expected chord tones (не full polyphony chord ID).

---

## Стек

| | |
|---|---|
| **Framework** | Flutter + Dart |
| **Primary target now** | **macOS** |
| **Later** | Android, iOS, Windows (тот же project) |
| **State** | riverpod |
| **Routing** | go_router |
| **Songs** | assets + local files (JSON / ChordPro) |
| **Audio play** | `just_audio` / `flutter_soloud` (spike) |
| **Mic / pitch** | platform mic stream + YIN (Dart or FFI) |
| **No** in-app song editor | text files only |

### macOS-first

- `flutter create` с `--platforms=macos` (можно добавить platforms позже: `flutter create --platforms=android,ios,windows .`).
- Каждый phase exit criteria проверяем на Mac.
- Не тратим время на mobile permissions/UI до Phase 4.

### Структура репозитория

```
guitar/
├── docs/
│   ├── PLAN.md
│   ├── SONG_FORMAT.md
│   └── ARCHITECTURE.md      # later
├── app/                     # Flutter project
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/
│   │   ├── domain/
│   │   ├── data/
│   │   ├── features/
│   │   │   ├── library/
│   │   │   ├── player/
│   │   │   ├── scoring/
│   │   │   ├── import/      # file picker only
│   │   │   └── settings/
│   │   └── audio/
│   ├── assets/songs/
│   └── test/
└── README.md
```

---

## Архитектура

```
┌──────────────┐   ┌────────────────┐   ┌─────────────────┐
│ Song Library │──▶│ Play Session   │──▶│ Score Engine    │
│ assets+files │   │ (clock + UI)   │   │ live early/late │
└──────┬───────┘   └───────┬────────┘   └────────▲────────┘
       │                   │                     │
       │                   ▼                     │
       │           ┌───────────────┐      ┌──────┴──────┐
       │           │ Accompaniment │      │ Mic + Pitch │
       │           │ audio | synth │      └─────────────┘
       │           └───────────────┘
       ▼
┌──────────────┐
│ File loaders │  .song.json | .cho  (+ optional audio)
└──────────────┘
```

**Clock source:**

- with audio → audio position is master;
- without → monotonic beat clock from tempo.

---

## Фазы

### Phase 0 — Foundation (macOS)

- [x] Docs: `PLAN.md`, `SONG_FORMAT.md`, `README.md`
- [x] Flutter app, **macos** platform
- [x] Domain models + JSON load
- [x] 2–3 bundled demo songs (text-authored)
- [x] Library list + Song detail (static chords/lyrics)

**Exit:** `flutter run -d macos` → список песен → detail.

### Phase 1 — Play-along

- [x] Beat/audio clock, play/pause
- [x] Chord scroller + lyrics sync
- [x] Accompaniment: **prefer audio file**; else metronome (+ simple pad if easy)
- [x] End screen (no score yet)

**Exit:** demo song play-along offline on Mac.

Notes: metronome clicks via `just_audio` + bundled WAV assets; simple pad deferred. Backing-audio path implemented (no bundled track yet — all demos use metronome).

### Phase 2 — Import files (no editor) — **deferred**

Skipped for now so scoring can ship first. Bundled songs already load from assets.

- [ ] ChordPro parser → song model (tempo/duration directives)
- [ ] File picker: `.cho` / `.song.json` (+ optional audio)
- [ ] Save into local library folder
- [ ] Bundled ∪ user songs

**Exit:** drop in a `.cho`, play it.

### Phase 3 — Scoring + live feedback ← **сейчас**

- [x] Mic + pitch (YIN)
- [x] Hit windows → **Good / Early / Late / Miss** live UI
- [x] Result summary
- [x] Score on/off in settings

**Exit:** real guitar/mic → live feedback + score > 0.

Notes: `record` PCM16 stream + `pitch_detector_dart` (YIN); match = pitch class ∈ chord tones; one grade per chord event; settings toggle via `shared_preferences`.

### Phase 3.1 — Recognition modes + Mic Lab

- [x] Shared analysis pipeline (RMS + YIN + chroma FFT)
- [x] Modes: Single pitch / Held pitch / Chroma / Hybrid
- [x] Mic Lab screen (free recognition UI)
- [x] Settings: mode picker + lab link; play-along uses selected mode
- [x] Room + guitar calibration; chroma noise subtract + adaptive RMS gate

**Exit:** open Mic Lab → play Am/C/G → correct guess most of the time; mode switch affects scoring.

### Phase 3.2 — Practice transport (tempo + scrub)

- [x] Practice tempo override (±5 / ±10 BPM, clamp 40–240, reset to song)
- [x] Scrub seek on progress slider (reopen score windows for retry/skip)
- [x] BeatClock.setTempoBpm re-anchors without jump; audio path uses setSpeed
- [x] Metronome volume 0–100% (persisted; 0 = fully off; player + settings)

### Phase 4 — Polish + more platforms + audio helpers

- [ ] Enable android/ios/windows targets
- [ ] Chord diagrams, transpose/capo
- [ ] Better synth fallback
- [ ] Optional: BPM estimate from audio (spike → feature)
- [ ] Tests, packaging

### Phase 5 — Online catalog

- After offline product is solid.

---

## Demo pack

- Training progression C–G–Am–F (no audio, metronome)
- One short public-domain / original with lyrics in ChordPro-derived JSON
- Optional: one with short backing ogg if we bundle a free loop

Authored as files under `assets/songs/`, no editor.

---

## Риски

| Риск | Митигация |
|---|---|
| Audio latency | Spike players; audio-first path is simpler than synth |
| Pitch noise | Thresholds; score optional; live feedback still useful |
| Auto-align expectation | Document: manual timing in text; auto later |
| Scope | macOS only until Phase 4; no editor; no online |

---

## После каждой фазы

Отмечать checklist в `docs/PLAN.md`. Не перескакивать exit criteria.

## Open

| | Default |
|---|---|
| App name | `ChordCoach` (можно переименовать) |
| UI language | EN strings first |
| Linux / Web | out of scope for now |
