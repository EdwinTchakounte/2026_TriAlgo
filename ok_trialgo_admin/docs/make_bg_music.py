"""Generate a calm ambient loop suitable for background while using the admin app.

Style : slow chord progression (Am - F - C - G) on a soft sine-pad with
slight detune, gentle bass, breathing LFO, fade in/out for seamless loop.
Result : ~32 sec mono WAV, ~2.7 MB.

This is way more musical than a single drone : it has movement, a tonic,
and feels intentional rather than test-tone-like.
"""

import numpy as np
import wave
import os

SR = 44100
BPM = 60                       # very slow, calming
BEAT = 60.0 / BPM
CHORD_BARS = 2                 # each chord lasts 2 beats (~2s)
TOTAL_BARS = 8                 # 4 chords x 2 beats = 8 beats total

# Am - F - C - G (vi-IV-I-V in C major, very pleasant rotation)
# We give each chord 4 notes (root + 3rd + 5th + octave) for a richer pad.
CHORDS = [
    [220.00, 261.63, 329.63, 440.00],   # Am
    [174.61, 220.00, 261.63, 349.23],   # F
    [130.81, 164.81, 196.00, 261.63],   # C
    [196.00, 246.94, 293.66, 392.00],   # G
]

# Bass note for each chord (one octave below root)
BASS = [110.00, 87.31, 130.81, 98.00]


def pad_voice(freq: float, duration: float, vel: float = 1.0) -> np.ndarray:
    """Soft pad : sine + slight detune + 2nd harmonic, slow ADSR."""
    t = np.linspace(0, duration, int(SR * duration), endpoint=False)
    # Slight detune (cent ~ 0.6%) for organic, chorused feel.
    base = np.sin(2 * np.pi * freq * t)
    detune = np.sin(2 * np.pi * freq * 1.006 * t)
    h2 = 0.30 * np.sin(2 * np.pi * freq * 2 * t)
    h3 = 0.10 * np.sin(2 * np.pi * freq * 3 * t)
    voice = (base + detune * 0.7 + h2 + h3) / 2.5
    # ADSR adapted to long pad : long attack, sustain, long release.
    attack = int(SR * 0.25)
    release = int(SR * 0.7)
    env = np.ones_like(voice)
    env[:attack] = np.linspace(0, 1, attack)
    env[-release:] = np.linspace(1, 0, release)
    return voice * env * vel


def bass_voice(freq: float, duration: float, vel: float = 0.6) -> np.ndarray:
    """Soft sub-bass : sine + low-end weight."""
    t = np.linspace(0, duration, int(SR * duration), endpoint=False)
    sub = np.sin(2 * np.pi * freq * t)
    fifth = 0.35 * np.sin(2 * np.pi * freq * 1.5 * t)
    voice = sub + fifth
    attack = int(SR * 0.05)
    release = int(SR * 0.4)
    env = np.ones_like(voice)
    env[:attack] = np.linspace(0, 1, attack)
    env[-release:] = np.linspace(1, 0, release)
    return voice * env * vel


def build_track() -> np.ndarray:
    """Concatenate chord blocks with crossfaded transitions for smoothness."""
    chord_dur = CHORD_BARS * BEAT * 2   # 4 sec per chord (8 chords total)
    total_dur = chord_dur * len(CHORDS) * 2   # 2 rotations = 32 sec
    samples = int(SR * total_dur)
    out = np.zeros(samples, dtype=np.float64)

    block_n = int(SR * chord_dur)
    pos = 0
    chord_index = 0
    for _ in range(len(CHORDS) * 2):
        c = CHORDS[chord_index]
        b = BASS[chord_index]
        block = np.zeros(block_n, dtype=np.float64)
        for note in c:
            block += pad_voice(note, chord_dur, vel=0.25)
        block += bass_voice(b, chord_dur, vel=0.35)
        # Insert with overlap to smooth boundaries.
        end = min(pos + block_n, samples)
        out[pos:end] += block[: end - pos]
        pos += block_n
        chord_index = (chord_index + 1) % len(CHORDS)

    # Subtle breathing LFO (slow volume swell).
    t = np.linspace(0, total_dur, samples, endpoint=False)
    lfo = 0.85 + 0.15 * np.sin(2 * np.pi * 0.06 * t)
    out *= lfo

    # Loop-safe edges : tiny fade-in / fade-out (0.4s each side).
    edge = int(SR * 0.4)
    out[:edge] *= np.linspace(0, 1, edge)
    out[-edge:] *= np.linspace(1, 0, edge)

    # Normalize to safe headroom (peak ~ -3 dBFS).
    out = out / (np.max(np.abs(out)) + 1e-9) * 0.70
    return out


def main() -> None:
    samples = build_track()
    pcm = (samples * 32767).astype(np.int16)
    out_path = '/home/tchakounte/Desktop/TriAlgo/trialgo_admin/assets/audio/bg.wav'
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with wave.open(out_path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f'Saved: {out_path}  ({os.path.getsize(out_path) // 1024} KB, {len(samples)/SR:.1f}s)')


if __name__ == '__main__':
    main()
