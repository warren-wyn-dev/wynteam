#!/usr/bin/env python3
"""WYN-200: generate the Wynos Merchant new-order sound.

Founder (2026-10-04): "เพิ่มเสียงการแจ้งเตือน ที่เป็นของตัวเอง ไม่ติดลิขสิทธิ์".

The sound is synthesized from scratch here (plain sine tones, no samples or
third-party audio), so WYN owns it outright and it carries no copyright
claims. Re-run to rebuild the exact same file:

    python3 web/scripts/generate-merchant-order-sound.py

Output: web/public/sounds/wynos-merchant-order.wav (mono, 16-bit, 32 kHz).
"""
import math
import struct
import wave
from pathlib import Path

RATE = 32_000
OUT = Path(__file__).resolve().parent.parent / "public" / "sounds" / "wynos-merchant-order.wav"

# A bright rising "Wy-nos, or-der!" motif: E5 G#5 B5, then a held E6.
NOTES = [
    (0.00, 659.25, 0.42, 0.55),
    (0.13, 830.61, 0.42, 0.55),
    (0.26, 987.77, 0.42, 0.60),
    (0.42, 1318.51, 0.95, 0.75),
]
LENGTH = 1.45  # seconds


def bell(t: float, freq: float, decay: float) -> float:
    """A soft marimba-like tone: fundamental, a quiet octave, a quick sparkle."""
    env = math.exp(-t / (decay / 4.0))
    attack = min(1.0, t / 0.006)  # 6 ms fade-in avoids clicks
    tone = (
        math.sin(2 * math.pi * freq * t)
        + 0.30 * math.sin(2 * math.pi * freq * 2 * t) * math.exp(-t / 0.08)
        + 0.12 * math.sin(2 * math.pi * freq * 4.01 * t) * math.exp(-t / 0.03)
    )
    return tone * env * attack


def main() -> None:
    frames = int(RATE * LENGTH)
    samples = [0.0] * frames
    for start, freq, decay, gain in NOTES:
        first = int(start * RATE)
        for i in range(first, min(frames, first + int((decay * 2.5) * RATE))):
            samples[i] += gain * bell((i - first) / RATE, freq, decay)
    peak = max(abs(s) for s in samples) or 1.0
    scale = 0.85 / peak
    fade = int(0.05 * RATE)
    data = bytearray()
    for i, s in enumerate(samples):
        if i > frames - fade:
            s *= (frames - i) / fade
        data += struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(bytes(data))
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
