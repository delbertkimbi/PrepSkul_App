#!/usr/bin/env python3
"""Synthesise the eight Primar sound effects.

They are generated rather than sourced because the length has to be exact.
Every library sound tried here arrived as a thirty-second music bed — a "soft
tap" that played half a minute over a child touching a tile. The lengths below
are chosen against what the sound has to do, and the durations printed by this
script are the ones recorded in `primar_voice.dart`.

Run:  python3 tool/generate_primar_sfx.py
"""

import math
import os
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")


def env(i, n, attack=0.004, release=0.6):
    """Fast attack, exponential decay. Silence at both ends, so a browser's
    media element has runway and no click on start or stop."""
    t = i / SR
    total = n / SR
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = math.exp(-t / (total * release))
    # Hard taper over the last 3ms so the waveform reaches exactly zero.
    tail = min(1.0, (n - i) / (0.003 * SR))
    return a * r * tail


def tone(freqs, dur, gain=0.5, attack=0.004, release=0.6, noise=0.0):
    n = int(SR * dur)
    out = []
    seed = 12345
    for i in range(n):
        t = i / SR
        v = 0.0
        for f, w in freqs:
            v += w * math.sin(2 * math.pi * f * t)
        if noise:
            seed = (1103515245 * seed + 12345) & 0x7FFFFFFF
            v += noise * ((seed / 0x3FFFFFFF) - 1.0)
        out.append(v * env(i, n, attack, release) * gain)
    return out


def sweep(f0, f1, dur, gain=0.5, release=0.5):
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * (i / n)
        phase += 2 * math.pi * f / SR
        out.append(math.sin(phase) * env(i, n, 0.004, release) * gain)
    return out


def seq(parts):
    """Notes laid end to end, each starting at a given offset in seconds."""
    total = max(int(SR * off) + len(buf) for off, buf in parts)
    out = [0.0] * total
    for off, buf in parts:
        s = int(SR * off)
        for i, v in enumerate(buf):
            out[s + i] += v
    return out


def write(name, samples):
    peak = max(1e-9, max(abs(v) for v in samples))
    scale = 0.89 / peak if peak > 0.89 else 1.0
    frames = b"".join(
        struct.pack("<h", max(-32767, min(32767, int(v * scale * 32767)))) for v in samples
    )
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)
    print(f"{name:16} {len(samples)/SR:.3f}s  {os.path.getsize(path)/1024:.1f} KB")


def main():
    os.makedirs(OUT, exist_ok=True)

    # Countdown tick. The first version was 22ms, which is under two frames and
    # reads as a faint click rather than a tick — on a phone speaker outdoors it
    # was simply not there. 60ms of a woodblock-ish body is heard without ever
    # becoming a distraction.
    write("tick.wav", tone([(1180, 0.7), (2360, 0.25)], 0.060, gain=0.5, release=0.32, noise=0.05))

    # The last three ticks. Same shape, lower and longer, so a child hears time
    # running out rather than being startled by it.
    write("tick_last.wav", tone([(880, 0.8), (1760, 0.3)], 0.085, gain=0.62, release=0.35, noise=0.05))

    # Time is up. Falls rather than stings — the countdown ending is followed by
    # being told the answer, so this must not read as a buzzer.
    write("times_up.wav", sweep(760, 380, 0.240, gain=0.55, release=0.45))

    # Touch. Short enough to feel like the tile itself made the sound.
    write("tap.wav", tone([(620, 0.6), (1240, 0.2)], 0.045, gain=0.34, release=0.3))

    # Correct. A rising third — the interval reads as "yes" almost everywhere.
    write("correct.wav", seq([
        (0.000, tone([(784, 1.0), (1568, 0.22)], 0.110, gain=0.42, release=0.45)),
        (0.075, tone([(1047, 1.0), (2094, 0.22)], 0.130, gain=0.46, release=0.45)),
    ]))

    # A run of correct answers. Three notes, quicker.
    write("streak.wav", seq([
        (0.000, tone([(880, 1.0)], 0.070, gain=0.36, release=0.4)),
        (0.052, tone([(1109, 1.0)], 0.070, gain=0.38, release=0.4)),
        (0.104, tone([(1319, 1.0)], 0.085, gain=0.42, release=0.4)),
    ]))

    # Moving up a level.
    write("level_up.wav", seq([
        (0.000, tone([(784, 1.0), (1568, 0.2)], 0.090, gain=0.40, release=0.42)),
        (0.070, tone([(988, 1.0), (1976, 0.2)], 0.090, gain=0.42, release=0.42)),
        (0.140, tone([(1319, 1.0), (2638, 0.2)], 0.150, gain=0.48, release=0.5)),
    ]))

    # End of the session. The only sound allowed to be longer than a third of a
    # second, because it plays once and nothing follows it.
    write("finish.wav", seq([
        (0.000, tone([(523, 1.0), (1047, 0.25)], 0.130, gain=0.38, release=0.5)),
        (0.105, tone([(659, 1.0), (1319, 0.25)], 0.130, gain=0.40, release=0.5)),
        (0.210, tone([(784, 1.0), (1568, 0.25)], 0.130, gain=0.42, release=0.5)),
        (0.315, tone([(1047, 1.0), (2094, 0.3)], 0.230, gain=0.50, release=0.55)),
    ]))


if __name__ == "__main__":
    main()
