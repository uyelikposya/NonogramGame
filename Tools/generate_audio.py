#!/usr/bin/env python3
"""Oyunun müziğini ve ses efektlerini sentezler (numpy + ffmpeg gerekir).

Kullanım:  pip install numpy && python3 Tools/generate_audio.py

Çıktılar Catgrid/Resources/Sounds/ içine yazılır. Profesyonel seslerle değiştirmek için
aynı dosya adlarını kullanmak yeterli (efektler .wav, müzik .m4a).
"""
import subprocess
import wave
from pathlib import Path

import numpy as np

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "Catgrid/Resources/Sounds"


def t(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def envelope(n, attack=0.005, decay=0.1, curve=4.0):
    x = np.arange(n) / RATE
    env = np.minimum(1, x / max(attack, 1e-4))
    return env * np.exp(-curve * np.maximum(0, x - attack) / max(decay, 1e-4))


def tone(freq, seconds, harmonics=(1, 0.3, 0.1), decay=0.3, attack=0.005):
    x = t(seconds)
    wave_ = sum(a * np.sin(2 * np.pi * freq * (i + 1) * x) for i, a in enumerate(harmonics))
    return wave_ * envelope(len(x), attack, decay)


def glide(f0, f1, seconds, decay=0.15):
    x = t(seconds)
    freq = f0 * (f1 / f0) ** (x / seconds)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    return (np.sin(phase) + 0.25 * np.sin(2 * phase)) * envelope(len(x), 0.004, decay)


def noise(seconds, decay=0.05, cutoff=0.2):
    x = np.random.default_rng(7).standard_normal(int(seconds * RATE))
    # Basit tek kutuplu alçak geçiren filtre
    y = np.zeros_like(x)
    for i in range(1, len(x)):
        y[i] = y[i - 1] + cutoff * (x[i] - y[i - 1])
    return y * envelope(len(x), 0.002, decay)


def mix(*parts):
    length = max(start + len(p) for start, p in parts)
    out = np.zeros(length)
    for start, p in parts:
        out[start:start + len(p)] += p
    return out


def at(seconds):
    return int(seconds * RATE)


def meow(seconds=0.42, base=620):
    """Sevimli, kısa bir 'miyav': yükselip alçalan perde + formant benzeri harmonikler."""
    x = t(seconds)
    shape = np.sin(np.pi * x / seconds) ** 0.6
    freq = base * (1 + 0.45 * np.sin(np.pi * np.minimum(1, x / (seconds * 0.55))) - 0.25 * (x / seconds) ** 2)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    vowel = np.sin(phase) + 0.5 * np.sin(2 * phase) + 0.35 * np.sin(3 * phase) + 0.15 * np.sin(4 * phase)
    vibrato = 1 + 0.06 * np.sin(2 * np.pi * 7 * x)
    return vowel * shape * vibrato


def write_wav(name, samples, peak=0.6):
    samples = samples / (np.max(np.abs(samples)) or 1) * peak
    data = (samples * 32767).astype(np.int16)
    with wave.open(str(OUT / name), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())


def effects():
    write_wav("fill.wav", mix((0, tone(880, 0.09, (1, 0.4, 0.1), decay=0.03)), (0, 0.25 * noise(0.03, 0.008, 0.5))), 0.45)
    write_wav("cross.wav", mix((0, 0.8 * noise(0.05, 0.012, 0.35)), (0, tone(1320, 0.05, (1, 0.2), decay=0.012))), 0.35)
    write_wav("erase.wav", glide(700, 420, 0.08, 0.03), 0.3)
    write_wav("mistake.wav", mix((0, tone(196, 0.28, (1, 0.5, 0.25), decay=0.12)), (at(0.06), tone(185, 0.26, (1, 0.5), decay=0.1))), 0.55)
    write_wav("line.wav", mix((0, tone(1046.5, 0.25, (1, 0.3), decay=0.1)), (at(0.06), tone(1568, 0.3, (1, 0.25), decay=0.12))), 0.4)
    notes = [523.25, 659.25, 783.99, 1046.5]
    jingle = mix(*[(at(i * 0.09), tone(f, 0.5, (1, 0.35, 0.1), decay=0.22)) for i, f in enumerate(notes)])
    write_wav("solved.wav", mix((0, jingle), (at(0.42), 0.55 * meow())), 0.6)
    sad = mix(*[(at(i * 0.16), tone(f, 0.45, (1, 0.4), decay=0.2)) for i, f in enumerate([392, 349.23, 311.13])])
    write_wav("failed.wav", sad, 0.5)
    write_wav("tap.wav", tone(1200, 0.04, (1, 0.2), decay=0.01), 0.25)


def music(path):
    """80 BPM, 16 ölçülük sakin lo-fi döngü: Fmaj7 - Dm7 - Gm7 - C7 (her akor 2 ölçü)."""
    bpm = 80
    beat = 60 / bpm
    bar = beat * 4
    length = bar * 16
    out = np.zeros(at(length) + at(2))
    chords = [
        [174.61, 220.0, 261.63, 329.63],  # Fmaj7
        [146.83, 174.61, 220.0, 261.63],  # Dm7
        [196.0, 233.08, 293.66, 349.23],  # Gm7
        [130.81, 164.81, 196.0, 233.08],  # C7
    ]
    bass = [87.31, 73.42, 98.0, 65.41]
    melody_scale = [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5]  # F majör pentatonik çevresi
    rng = np.random.default_rng(42)

    def add(start, signal, gain):
        s = at(start)
        out[s:s + len(signal)] += gain * signal[:len(out) - s]

    for chord_index in range(8):
        chord = chords[chord_index % 4]
        start = chord_index * bar * 2
        # Elektrik piyano: her ölçünün başında ve 3. vuruşta yumuşak akor
        for hit in (0, 2.5, 4, 6.5):
            for i, f in enumerate(chord):
                add(start + hit * beat + i * 0.012, tone(f, beat * 2.2, (1, 0.45, 0.12), decay=0.9, attack=0.01), 0.16)
        # Bas
        for hit in (0, 3, 4, 7):
            add(start + hit * beat, tone(bass[chord_index % 4], beat * 1.2, (1, 0.3), decay=0.4, attack=0.01), 0.35)
        # Seyrek melodi
        for step in range(8):
            if rng.random() < 0.45:
                f = rng.choice(melody_scale)
                add(start + step * beat + rng.choice([0, 0.5]) * beat, tone(f, beat * 1.4, (1, 0.15), decay=0.5, attack=0.008), 0.09)
    # Hafif hi-hat
    hat = noise(0.05, 0.015, 0.9)
    for step in range(int(length / (beat / 2))):
        add(step * beat / 2, hat, 0.05 if step % 2 else 0.025)
    # Döngünün sonundaki kuyruk başa eklenir: dikişsiz tekrar
    loop = out[:at(length)].copy()
    tail = out[at(length):]
    loop[:len(tail)] += tail
    loop = loop / np.max(np.abs(loop)) * 0.5
    wav = OUT / "music_tmp.wav"
    data = (loop * 32767).astype(np.int16)
    with wave.open(str(wav), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "aac", "-b:a", "96k", str(path)], check=True)
    wav.unlink()


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    effects()
    music(OUT / "music_cozy.m4a")
    for f in sorted(OUT.iterdir()):
        print(f"{f.name:16s} {f.stat().st_size // 1024} KB")
