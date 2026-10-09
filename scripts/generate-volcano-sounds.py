#!/usr/bin/env python3
"""Reproduce the volcano quest's synthesized effects without external services."""
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / 'assets/audio/heart_of_volcano'
RATE = 22050

def generate():
    ROOT.mkdir(parents=True, exist_ok=True)
    durations = {'checkpoint': .7, 'retry': .6, 'short_call': .4, 'long_call': 1.2,
                 'crack': .9, 'launch': 1.0, 'deflect': .5, 'warning': .8, 'rumble': 1.5, 'opening': .7}
    for name, duration in durations.items():
        rng = random.Random(name)
        data = bytearray()
        filtered = 0.0
        for i in range(int(duration * RATE)):
            t = i / RATE
            env = min(1, t / .03) * min(1, (duration - t) / .1)
            filtered = filtered * .9 + rng.uniform(-1, 1) * .1
            if name in ['short_call', 'long_call']:
                value = sum(math.sin(2 * math.pi * (180 + n * 45) * t) / (n + 1) for n in range(3)) * .18
            elif name in ['checkpoint', 'opening']:
                freq = [523.25, 659.25, 783.99][min(2, int(t / .22))]
                value = math.sin(2 * math.pi * freq * t) * .22
            elif name == 'retry': value = math.sin(2 * math.pi * (400 * t - 160 * t * t)) * .2
            elif name == 'warning': value = math.sin(2 * math.pi * 330 * t) * (1 if int(t * 6) % 2 == 0 else 0) * .2
            elif name == 'deflect': value = math.sin(2 * math.pi * (700 * t + 300 * t * t)) * .2
            elif name == 'crack': value = rng.uniform(-.65, .65) * math.exp(-t * 6)
            else: value = filtered * 2 + math.sin(2 * math.pi * 55 * t) * .08
            data.extend(struct.pack('<h', int(max(-1, min(1, value * env)) * 32767)))
        with wave.open(str(ROOT / f'{name}.wav'), 'wb') as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(RATE)
            output.writeframes(data)

if __name__ == '__main__': generate()
