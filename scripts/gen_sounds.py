#!/usr/bin/env python3
"""
Better Shell — Sound Generator
Generates all 27 bundled WAV files using Python's wave and math modules.
No external dependencies required.

Each sound is synthesized from basic waveforms (sine, square, triangle, sawtooth)
with optional effects (fade, envelope, frequency sweep).

License: CC0 1.0 Universal — generated works, no copyrighted material.
"""

import wave
import math
import struct
import os

SAMPLE_RATE = 22050  # 22 kHz — small files, adequate quality for short bleeps
CHANNELS = 1         # mono
SAMPLE_WIDTH = 2     # 16-bit PCM
MAX_AMPLITUDE = 32767


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def sine(freq, t):
    return math.sin(2 * math.pi * freq * t)


def square(freq, t):
    return 1.0 if math.sin(2 * math.pi * freq * t) >= 0 else -1.0


def triangle(freq, t):
    phase = (freq * t) % 1.0
    return 4.0 * abs(phase - 0.5) - 1.0


def sawtooth(freq, t):
    return 2.0 * ((freq * t) % 1.0) - 1.0


def fade_envelope(i, total, fade_in=0.05, fade_out=0.2):
    """Returns amplitude multiplier [0..1] based on position."""
    fi = int(fade_in * total)
    fo = int(fade_out * total)
    if i < fi:
        return i / fi if fi > 0 else 1.0
    elif i >= total - fo:
        remaining = total - i
        return remaining / fo if fo > 0 else 1.0
    return 1.0


def freq_sweep(freq_start, freq_end, i, total):
    """Linear frequency interpolation."""
    t = i / total if total > 0 else 0
    return freq_start + (freq_end - freq_start) * t


def generate_wav(path, samples):
    """Write a list of float samples [-1..1] to a WAV file."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'w') as wf:
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(SAMPLE_WIDTH)
        wf.setframerate(SAMPLE_RATE)
        for s in samples:
            # Clamp and convert to 16-bit signed int
            v = int(clamp(s * MAX_AMPLITUDE, -MAX_AMPLITUDE, MAX_AMPLITUDE))
            wf.writeframes(struct.pack('<h', v))
    print(f"  wrote {path}")


def make_samples(duration, gen_fn, gain=0.7):
    """Generate samples from a generator function f(i, total, t) -> float."""
    total = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(total):
        t = i / SAMPLE_RATE
        v = gen_fn(i, total, t) * fade_envelope(i, total) * gain
        samples.append(v)
    return samples


# ---------------------------------------------------------------------------
# MEME PACK — dramatic, over-the-top
# ---------------------------------------------------------------------------

def meme_error_light():
    """Short descending buzz (0.3s)."""
    def gen(i, total, t):
        freq = freq_sweep(450, 180, i, total)
        return sine(freq, t) * 0.8 + sine(freq * 2, t) * 0.2
    return make_samples(0.3, gen, gain=0.7)


def meme_error_medium():
    """Longer descending tone with wobble (0.7s)."""
    def gen(i, total, t):
        freq = freq_sweep(500, 120, i, total)
        wobble = sine(8, t) * 20
        return sine(freq + wobble, t) * 0.7 + square(freq / 2, t) * 0.3
    return make_samples(0.7, gen, gain=0.65)


def meme_error_heavy():
    """Dramatic long descend with overdrive character (1.2s)."""
    def gen(i, total, t):
        freq = freq_sweep(600, 60, i, total)
        s = sine(freq, t) * 0.6 + sine(freq * 1.5, t) * 0.3 + sine(freq * 0.5, t) * 0.4
        # Soft clip / overdrive simulation
        s = math.tanh(s * 2) * 0.5
        return s
    return make_samples(1.2, gen, gain=0.7)


def meme_success_light():
    """Quick ascending blip (0.2s)."""
    def gen(i, total, t):
        freq = freq_sweep(500, 900, i, total)
        return sine(freq, t)
    return make_samples(0.2, gen, gain=0.6)


def meme_success_medium():
    """Triumphant ascending rise (0.5s)."""
    def gen(i, total, t):
        freq = freq_sweep(400, 1000, i, total)
        return sine(freq, t) * 0.7 + sine(freq * 1.25, t) * 0.3
    return make_samples(0.5, gen, gain=0.65)


def meme_success_heavy():
    """Full ascending fanfare chord (1.0s)."""
    def gen(i, total, t):
        freq = freq_sweep(300, 900, i, total)
        # Chord: root + major third + fifth
        return (sine(freq, t) + sine(freq * 1.25, t) + sine(freq * 1.5, t)) / 3
    return make_samples(1.0, gen, gain=0.7)


def meme_warning_light():
    """Quick wobble (0.25s)."""
    def gen(i, total, t):
        freq = 600 + sine(15, t) * 100
        return sine(freq, t)
    return make_samples(0.25, gen, gain=0.6)


def meme_warning_medium():
    """Sustained wobble alarm (0.6s)."""
    def gen(i, total, t):
        freq = 550 + sine(10, t) * 150
        return sine(freq, t) * 0.8 + square(freq * 0.5, t) * 0.2
    return make_samples(0.6, gen, gain=0.65)


def meme_warning_heavy():
    """Urgent multi-tone alarm (1.1s)."""
    def gen(i, total, t):
        # Alternating between two frequencies
        phase = (t * 3) % 1.0
        freq = 700 if phase < 0.5 else 500
        return sine(freq, t) * 0.8 + square(freq, t) * 0.2
    return make_samples(1.1, gen, gain=0.65)


# ---------------------------------------------------------------------------
# CHILL PACK — soft, satisfying
# ---------------------------------------------------------------------------

def chill_error_light():
    """Gentle soft thud (0.3s), low frequency."""
    def gen(i, total, t):
        # Low sine with fast decay
        decay = math.exp(-5 * t)
        return sine(120, t) * decay
    return make_samples(0.3, gen, gain=0.5)


def chill_error_medium():
    """Mellow low buzz (0.6s)."""
    def gen(i, total, t):
        freq = freq_sweep(200, 120, i, total)
        return sine(freq, t) * 0.8 + sine(freq * 2, t) * 0.1
    return make_samples(0.6, gen, gain=0.5)


def chill_error_heavy():
    """Deep bass note (1.0s)."""
    def gen(i, total, t):
        # Deep sine with harmonics
        return sine(80, t) * 0.7 + sine(160, t) * 0.2 + sine(240, t) * 0.1
    return make_samples(1.0, gen, gain=0.5)


def chill_success_light():
    """Single gentle ding (0.4s), pure sine."""
    def gen(i, total, t):
        # Bell-like: fast attack, slow decay
        decay = math.exp(-4 * t)
        return sine(880, t) * decay
    return make_samples(0.4, gen, gain=0.55)


def chill_success_medium():
    """Double chime (0.6s)."""
    total_samples = int(SAMPLE_RATE * 0.6)
    half = total_samples // 2
    samples = []
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        if i < half:
            local_t = i / SAMPLE_RATE
            decay = math.exp(-6 * local_t)
            v = sine(880, local_t) * decay
        else:
            local_t = (i - half) / SAMPLE_RATE
            decay = math.exp(-6 * local_t)
            v = sine(1100, local_t) * decay
        env = fade_envelope(i, total_samples, fade_in=0.01, fade_out=0.1)
        samples.append(v * env * 0.55)
    return samples


def chill_success_heavy():
    """Warm harmony chord (1.0s)."""
    def gen(i, total, t):
        decay = math.exp(-1.5 * t)
        # Major chord: C E G
        return (sine(523, t) + sine(659, t) + sine(784, t)) / 3 * decay
    return make_samples(1.0, gen, gain=0.55)


def chill_warning_light():
    """Soft click/tick (0.15s)."""
    def gen(i, total, t):
        decay = math.exp(-20 * t)
        return sine(400, t) * decay
    return make_samples(0.15, gen, gain=0.5)


def chill_warning_medium():
    """Gentle ping (0.45s)."""
    def gen(i, total, t):
        decay = math.exp(-5 * t)
        return sine(660, t) * decay + sine(880, t) * decay * 0.3
    return make_samples(0.45, gen, gain=0.5)


def chill_warning_heavy():
    """Warm alert chord (0.8s)."""
    def gen(i, total, t):
        decay = math.exp(-2 * t)
        # Minor chord for warning feel
        return (sine(440, t) + sine(523, t) + sine(659, t)) / 3 * decay
    return make_samples(0.8, gen, gain=0.55)


# ---------------------------------------------------------------------------
# RETRO PACK — 8-bit, chiptune style
# ---------------------------------------------------------------------------

def retro_error_light():
    """Quick square wave blip down (0.2s)."""
    def gen(i, total, t):
        freq = freq_sweep(400, 150, i, total)
        return square(freq, t)
    return make_samples(0.2, gen, gain=0.5)


def retro_error_medium():
    """Descending square wave scale (0.6s) — like game-over."""
    def gen(i, total, t):
        # Step through descending notes
        notes = [400, 350, 300, 250, 200]
        step = int(i / total * len(notes))
        step = min(step, len(notes) - 1)
        freq = notes[step]
        return square(freq, t) * 0.7 + triangle(freq * 0.5, t) * 0.3
    return make_samples(0.6, gen, gain=0.5)


def retro_error_heavy():
    """Crash sequence (1.0s) — multi-tone descend."""
    def gen(i, total, t):
        notes = [500, 400, 300, 200, 150, 100]
        step = int(i / total * len(notes))
        step = min(step, len(notes) - 1)
        freq = notes[step]
        return square(freq, t) * 0.6 + sawtooth(freq * 2, t) * 0.2
    return make_samples(1.0, gen, gain=0.5)


def retro_success_light():
    """Coin-like blip (0.15s)."""
    def gen(i, total, t):
        # Quick up then down — coin pickup
        if i < total // 2:
            freq = 800
        else:
            freq = 1200
        return square(freq, t)
    return make_samples(0.15, gen, gain=0.5)


def retro_success_medium():
    """Level-up ascending scale (0.5s)."""
    def gen(i, total, t):
        notes = [400, 500, 600, 700, 800, 1000]
        step = int(i / total * len(notes))
        step = min(step, len(notes) - 1)
        freq = notes[step]
        return square(freq, t) * 0.7 + triangle(freq, t) * 0.3
    return make_samples(0.5, gen, gain=0.5)


def retro_success_heavy():
    """Victory jingle (1.2s)."""
    def gen(i, total, t):
        notes = [400, 500, 600, 500, 700, 800, 1000, 1200]
        step = int(i / total * len(notes))
        step = min(step, len(notes) - 1)
        freq = notes[step]
        # Chord for fullness
        return (square(freq, t) + triangle(freq * 1.5, t)) / 2
    return make_samples(1.2, gen, gain=0.5)


def retro_warning_light():
    """Alert pip (0.2s), triangle wave."""
    def gen(i, total, t):
        return triangle(600, t)
    return make_samples(0.2, gen, gain=0.5)


def retro_warning_medium():
    """Warning beep (0.5s), pulsing."""
    def gen(i, total, t):
        # Pulse: on for 0.1s, off for 0.1s
        pulse = 1.0 if (t * 5) % 1.0 < 0.5 else 0.0
        return triangle(500, t) * pulse
    return make_samples(0.5, gen, gain=0.5)


def retro_warning_heavy():
    """Alarm sequence (1.0s) — alternating tones."""
    def gen(i, total, t):
        freq = 700 if (t * 4) % 1.0 < 0.5 else 400
        return square(freq, t) * 0.7 + triangle(freq, t) * 0.3
    return make_samples(1.0, gen, gain=0.5)


# ---------------------------------------------------------------------------
# Generation map
# ---------------------------------------------------------------------------

SOUNDS = {
    "sounds/meme/error/light.wav":    meme_error_light,
    "sounds/meme/error/medium.wav":   meme_error_medium,
    "sounds/meme/error/heavy.wav":    meme_error_heavy,
    "sounds/meme/success/light.wav":  meme_success_light,
    "sounds/meme/success/medium.wav": meme_success_medium,
    "sounds/meme/success/heavy.wav":  meme_success_heavy,
    "sounds/meme/warning/light.wav":  meme_warning_light,
    "sounds/meme/warning/medium.wav": meme_warning_medium,
    "sounds/meme/warning/heavy.wav":  meme_warning_heavy,

    "sounds/chill/error/light.wav":    chill_error_light,
    "sounds/chill/error/medium.wav":   chill_error_medium,
    "sounds/chill/error/heavy.wav":    chill_error_heavy,
    "sounds/chill/success/light.wav":  chill_success_light,
    "sounds/chill/success/medium.wav": chill_success_medium,
    "sounds/chill/success/heavy.wav":  chill_success_heavy,
    "sounds/chill/warning/light.wav":  chill_warning_light,
    "sounds/chill/warning/medium.wav": chill_warning_medium,
    "sounds/chill/warning/heavy.wav":  chill_warning_heavy,

    "sounds/retro/error/light.wav":    retro_error_light,
    "sounds/retro/error/medium.wav":   retro_error_medium,
    "sounds/retro/error/heavy.wav":    retro_error_heavy,
    "sounds/retro/success/light.wav":  retro_success_light,
    "sounds/retro/success/medium.wav": retro_success_medium,
    "sounds/retro/success/heavy.wav":  retro_success_heavy,
    "sounds/retro/warning/light.wav":  retro_warning_light,
    "sounds/retro/warning/medium.wav": retro_warning_medium,
    "sounds/retro/warning/heavy.wav":  retro_warning_heavy,
}


if __name__ == "__main__":
    import sys
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(base)
    print(f"Generating {len(SOUNDS)} WAV files in {base}/sounds/")
    for path, fn in SOUNDS.items():
        samples = fn()
        generate_wav(path, samples)
    print(f"\nDone: {len(SOUNDS)} files generated.")
