#!/usr/bin/env python3
"""Reproduce the ice quest's synthesized effects; no external service required."""
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / 'assets/audio/frozen_pass'
RATE = 22050

def generate():
    ROOT.mkdir(parents=True, exist_ok=True)
    for name, duration in [('checkpoint', 0.7), ('retry', 0.6), ('wind', 3.0), ('ice_crack', 1.2), ('avalanche', 2.5)]:
        rng = random.Random(name)
        samples = bytearray()
        smooth_noise = 0.0
        for index in range(int(duration * RATE)):
            t = index / RATE
            envelope = min(1.0, t / 0.03) * min(1.0, (duration - t) / 0.12)
            smooth_noise = smooth_noise * 0.92 + rng.uniform(-1, 1) * 0.08
            if name == 'checkpoint':
                frequency = [523.25, 659.25, 783.99][min(2, int(t / 0.22))]
                value = math.sin(2 * math.pi * frequency * t) * 0.24
            elif name == 'retry':
                value = math.sin(2 * math.pi * (400 * t - 160 * t * t)) * 0.2
            elif name == 'wind':
                value = smooth_noise * (1.5 + math.sin(t * 5) * 0.4)
            elif name == 'ice_crack':
                value = rng.uniform(-0.6, 0.6) * math.exp(-t * 7) + math.sin(2 * math.pi * 140 * t) * math.exp(-t * 5) * 0.2
            else:
                value = smooth_noise * 2.2 + math.sin(2 * math.pi * 48 * t) * 0.1
            samples.extend(struct.pack('<h', int(max(-1, min(1, value * envelope)) * 32767)))
        with wave.open(str(ROOT / f'{name}.wav'), 'wb') as out:
            out.setnchannels(1)
            out.setsampwidth(2)
            out.setframerate(RATE)
            out.writeframes(samples)

if __name__ == '__main__':
    generate()
