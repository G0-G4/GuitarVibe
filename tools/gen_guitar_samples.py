#!/usr/bin/env python3
"""Generate bundled guitar-ish samples for ChordCoach guide audio.

Usage (from repo root):
  python3 tools/gen_guitar_samples.py

Writes mono 44.1 kHz PCM WAV under app/assets/audio/guitar/:
  n40.wav … n72.wav   open-string range E2–C5 plucks
  mute.wav            palm-mute / dead-stroke chuck (multi-layer)
  mute_up.wav         thinner upstroke chuck
"""

from __future__ import annotations

import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "app", "assets", "audio", "guitar")
SR = 44100

# Standard-ish open string fundamentals (Hz) for mute body.
OPEN_STRING_HZ = [82.4, 110.0, 146.8, 196.0, 246.9, 329.6]  # E2 A2 D3 G3 B3 E4


def write_wav(path: str, samples: list[float], sr: int = SR) -> None:
    peak = max((abs(x) for x in samples), default=1.0) or 1.0
    scale = 0.92 / peak
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        frames = bytearray()
        for s in samples:
            v = max(-1.0, min(1.0, s * scale))
            frames += struct.pack("<h", int(v * 32767))
        w.writeframes(frames)


def midi_to_hz(m: int) -> float:
    return 440.0 * (2 ** ((m - 69) / 12.0))


def _one_pole(x: list[float], a: float) -> list[float]:
    y = 0.0
    out = [0.0] * len(x)
    for i, s in enumerate(x):
        y += a * (s - y)
        out[i] = y
    return out


def _mix(a: list[float], b: list[float], ga: float = 1.0, gb: float = 1.0) -> list[float]:
    n = max(len(a), len(b))
    out = [0.0] * n
    for i in range(n):
        va = a[i] if i < len(a) else 0.0
        vb = b[i] if i < len(b) else 0.0
        out[i] = va * ga + vb * gb
    return out


def _fade_edges(samples: list[float], attack_s: float = 0.002, release_s: float = 0.04) -> None:
    n = len(samples)
    att = max(1, int(attack_s * SR))
    rel = max(1, int(release_s * SR))
    for i in range(min(att, n)):
        samples[i] *= i / att
    for i in range(rel):
        j = n - rel + i
        if 0 <= j < n:
            samples[j] *= 1.0 - (i / rel)


def karplus_pluck(
    freq: float,
    duration: float,
    *,
    decay: float = 0.9965,
    brightness: float = 0.55,
    pick_pos: float = 0.18,
    amp: float = 1.0,
) -> list[float]:
    """KS string with pick-position excitation + pick click + body."""
    n = max(4, int(round(SR / freq)))
    # Excitation: noise windowed at pick position (more realistic than flat noise).
    buf = [0.0] * n
    pick = int(n * pick_pos) % n
    width = max(2, n // 8)
    for i in range(n):
        # Distance from pick along the string (circular-ish).
        d = min((i - pick) % n, (pick - i) % n)
        window = math.exp(-((d / width) ** 2))
        noise = random.uniform(-1.0, 1.0)
        # Blend triangle-ish displacement for body.
        tri = 1.0 - abs(2.0 * (i / n) - 1.0)
        buf[i] = (noise * brightness + tri * (1.0 - brightness) * 0.55) * window

    # Seed a bit of energy at ends for lower partials.
    for i in range(n):
        buf[i] += 0.08 * math.sin(math.pi * i / n)

    total = int(SR * duration)
    out = [0.0] * total
    idx = 0
    # Slightly stretch decay over time (string loses HF first via averaging).
    for i in range(total):
        s = buf[idx]
        out[i] = s
        nxt = (idx + 1) % n
        # Dynamic decay: a touch more loss early for quicker pluck bite.
        d = decay - 0.0015 * (1.0 - i / max(1, total))
        d = max(0.985, min(0.9995, d))
        avg = d * 0.5 * (buf[idx] + buf[nxt])
        buf[idx] = avg
        idx = nxt

    # Pick attack click (short noise + HF).
    click_n = int(0.0035 * SR)
    for i in range(min(click_n, total)):
        t = i / max(1, click_n - 1)
        env = (1.0 - t) ** 2
        out[i] += random.uniform(-1, 1) * 0.35 * env * brightness

    # Body resonance ~80–200 Hz (guitar body / air).
    body_f = 95.0 + min(80.0, freq * 0.08)
    body = [0.0] * total
    # Resonator driven by pluck envelope.
    y1 = y2 = 0.0
    w = 2 * math.pi * body_f / SR
    r = 0.985
    for i in range(total):
        x = out[i]
        # Simple resonator
        y0 = x + 2 * r * math.cos(w) * y1 - (r * r) * y2
        y2, y1 = y1, y0
        body[i] = y0
    out = _mix(out, body, 1.0, 0.12)

    # Soft LPF (string / amp): more on low notes.
    lpf_a = 0.22 + 0.18 * min(1.0, (freq - 80) / 400)
    lpf_a = max(0.15, min(0.55, lpf_a))
    soft = _one_pole(out, lpf_a)
    out = _mix(out, soft, 0.4, 0.6)

    for i in range(total):
        out[i] *= amp

    _fade_edges(out, attack_s=0.0015, release_s=0.05)
    return out


def palm_mute_chuck(
    duration: float = 0.14,
    *,
    upstroke: bool = False,
    amp: float = 1.0,
) -> list[float]:
    """Layered dead-stroke: muted strings + hand slap + string scrape."""
    total = int(SR * duration)
    out = [0.0] * total

    # 1) Heavily damped KS on open-string-ish frequencies (all six "hit").
    for si, f in enumerate(OPEN_STRING_HZ):
        # Upstrokes emphasize higher strings.
        if upstroke and si < 2:
            str_amp = 0.12
        elif upstroke:
            str_amp = 0.28 + 0.06 * si
        else:
            str_amp = 0.35 - 0.03 * si
        # Very low decay → short "chk" with faint pitch.
        n = max(4, int(round(SR / f)))
        buf = [random.uniform(-1, 1) for _ in range(n)]
        # Extra damping: pre-filter buffer
        for i in range(1, n):
            buf[i] = 0.5 * (buf[i] + buf[i - 1])
        idx = 0
        decay = 0.92 if upstroke else 0.93
        stagger = int((0.0012 + si * 0.0009) * SR)
        for i in range(total):
            if i < stagger:
                continue
            j = i - stagger
            if j >= total:
                break
            s = buf[idx]
            env = math.exp(-j / SR * (38 if upstroke else 32))
            out[j] += s * env * str_amp
            nxt = (idx + 1) % n
            buf[idx] = decay * 0.5 * (buf[idx] + buf[nxt])
            idx = nxt

    # 2) Hand / palm slap (low thump + mid knock).
    for i in range(total):
        t = i / SR
        env = math.exp(-t * (48 if upstroke else 40))
        thump = math.sin(2 * math.pi * 72 * t) * 0.55
        knock = math.sin(2 * math.pi * 180 * t) * 0.28
        # Soften after first ms.
        out[i] += (thump + knock) * env * (0.45 if upstroke else 0.7)

    # 3) String scrape / fret noise (broadband, short).
    scrape_n = int(0.025 * SR)
    for i in range(min(scrape_n, total)):
        t = i / max(1, scrape_n - 1)
        env = math.exp(-t * 4.0) * (1.0 - 0.3 * t)
        # Band-emphasize mid-high with difference of noise filters.
        n0 = random.uniform(-1, 1)
        n1 = random.uniform(-1, 1)
        scrape = n0 * 0.7 + n1 * 0.3
        gain = 0.55 if upstroke else 0.7
        out[i] += scrape * env * gain

    # 4) Very short HF "click" of pick on muted strings.
    click_n = int(0.0025 * SR)
    for i in range(min(click_n, total)):
        t = i / max(1, click_n - 1)
        out[i] += random.uniform(-1, 1) * (1.0 - t) ** 2 * (0.5 if upstroke else 0.65)

    # Mild LPF so mute isn't pure white noise.
    soft = _one_pole(out, 0.4 if upstroke else 0.32)
    out = _mix(out, soft, 0.35, 0.65)

    for i in range(total):
        out[i] *= amp

    _fade_edges(out, attack_s=0.0008, release_s=0.03)
    return out


def main() -> None:
    random.seed(7)
    os.makedirs(OUT, exist_ok=True)

    # E2 (40) … C5 (72)
    for midi in range(40, 73):
        hz = midi_to_hz(midi)
        # Lower strings ring longer / darker; highs shorter & brighter.
        t = (midi - 40) / (72 - 40)
        duration = 2.4 - 0.6 * t
        decay = 0.9972 - 0.0020 * t
        brightness = 0.38 + 0.35 * t
        pick_pos = 0.15 + 0.08 * t
        samples = karplus_pluck(
            hz,
            duration=duration,
            decay=decay,
            brightness=brightness,
            pick_pos=pick_pos,
            amp=0.9,
        )
        path = os.path.join(OUT, f"n{midi}.wav")
        write_wav(path, samples)
        print(f"wrote {path} {hz:.1f}Hz {os.path.getsize(path)}b")

    # Remove old mid-only bank files outside new range if any leftover — none.

    mute_path = os.path.join(OUT, "mute.wav")
    write_wav(mute_path, palm_mute_chuck(0.13, upstroke=False, amp=1.0))
    print(f"wrote {mute_path} {os.path.getsize(mute_path)}b")

    mute_up_path = os.path.join(OUT, "mute_up.wav")
    write_wav(mute_up_path, palm_mute_chuck(0.11, upstroke=True, amp=0.95))
    print(f"wrote {mute_up_path} {os.path.getsize(mute_up_path)}b")

    print("done")


if __name__ == "__main__":
    main()
