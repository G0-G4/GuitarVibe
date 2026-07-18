#!/usr/bin/env python3
"""Generate bundled guitar-ish pluck samples (Karplus–Strong) for ChordCoach.

Usage (from repo root):
  python3 tools/gen_guitar_samples.py

Writes mono 22.05 kHz PCM WAV files under app/assets/audio/guitar/:
  n48.wav … n72.wav  (MIDI C3–C5)
  mute.wav            (chuck / dead stroke)
"""

from __future__ import annotations

import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "app", "assets", "audio", "guitar")
SR = 22050


def write_wav(path: str, samples: list[float], sr: int = SR) -> None:
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        frames = bytearray()
        for s in samples:
            v = max(-1.0, min(1.0, s))
            frames += struct.pack("<h", int(v * 32767))
        w.writeframes(frames)


def midi_to_hz(m: int) -> float:
    return 440.0 * (2 ** ((m - 69) / 12.0))


def karplus_strong(
    freq: float,
    duration: float,
    decay: float = 0.996,
    brightness: float = 0.5,
    amp: float = 0.85,
) -> list[float]:
    n = max(2, int(SR / freq))
    buf = [random.uniform(-1, 1) for _ in range(n)]
    for i in range(n):
        t = i / n
        buf[i] = buf[i] * brightness + math.sin(math.pi * t) * (1 - brightness) * 0.3
    total = int(SR * duration)
    out = [0.0] * total
    idx = 0
    for i in range(total):
        s = buf[idx]
        out[i] = s
        nxt = (idx + 1) % n
        avg = decay * 0.5 * (buf[idx] + buf[nxt])
        buf[idx] = avg
        idx = nxt
    attack = int(0.004 * SR)
    for i in range(min(attack, total)):
        out[i] *= i / max(1, attack)
    y = 0.0
    a = 0.35
    for i in range(total):
        y = y + a * (out[i] - y)
        out[i] = (out[i] * 0.45 + y * 0.55) * amp
    fade = int(0.04 * SR)
    for i in range(fade):
        j = total - fade + i
        if 0 <= j < total:
            out[j] *= 1.0 - (i / fade)
    peak = max(abs(x) for x in out) or 1.0
    scale = 0.9 / peak
    return [x * scale for x in out]


def mute_thump(duration: float = 0.08) -> list[float]:
    total = int(SR * duration)
    out: list[float] = []
    for i in range(total):
        t = i / SR
        env = math.exp(-t * 55)
        n = random.uniform(-1, 1) * env
        n += 0.4 * math.sin(2 * math.pi * 80 * t) * env
        out.append(n * 0.7)
    peak = max(abs(x) for x in out) or 1.0
    return [x * 0.85 / peak for x in out]


def main() -> None:
    random.seed(42)
    os.makedirs(OUT, exist_ok=True)
    for midi in range(48, 73):
        hz = midi_to_hz(midi)
        decay = 0.994 + min(0.004, (60 - midi) * 0.00015) if midi < 60 else 0.9955
        decay = max(0.992, min(0.998, decay))
        brightness = 0.55 if midi > 60 else 0.45
        samples = karplus_strong(
            hz, duration=2.2, decay=decay, brightness=brightness, amp=0.8
        )
        path = os.path.join(OUT, f"n{midi}.wav")
        write_wav(path, samples)
        print(f"wrote {path} {hz:.1f}Hz")
    mute_path = os.path.join(OUT, "mute.wav")
    write_wav(mute_path, mute_thump())
    print(f"wrote {mute_path}")


if __name__ == "__main__":
    main()
