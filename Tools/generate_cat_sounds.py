#!/usr/bin/env python3
"""Kedi Bulmaca modunun ses efektleri (numpy gerekir).

Kullanım:  python3 Tools/generate_cat_sounds.py
Çıktılar Catgrid/Resources/Sounds/cat_*.wav. Yardımcı sentez fonksiyonları generate_audio.py'den.
"""
import numpy as np

from generate_audio import OUT, at, glide, meow, mix, noise, t, tone, write_wav, envelope, RATE


def thock(seconds=0.09, freq=55):
    """Yumuşak, tok bir 'tok': alçak sinüs + kısacık tıkırtı."""
    x = t(seconds)
    body = np.sin(2 * np.pi * freq * x * (1 + 0.6 * np.exp(-x * 60))) * envelope(len(x), 0.002, 0.035)
    click = noise(0.012, 0.003, 0.9)
    return mix((0, body), (0, 0.35 * click))


def pluck(freq, seconds=0.22, decay=0.07):
    return tone(freq, seconds, (1, 0.35, 0.12), decay=decay, attack=0.002)


def sparkle(seconds=0.35):
    """Çok tiz, kısa parıltı (yüksek frekanslı tınılar)."""
    notes = [6272, 7040, 7902, 8372]
    return mix(*[(at(i * 0.03), tone(f, 0.18, (1,), decay=0.05)) for i, f in enumerate(notes)])


def cat_effects():
    # X koyma: tok bir dokunuş
    write_wav("cat_x.wav", thock(), 0.35)
    # Kedi bulundu: tok + hızlı yükselen üç nota + parıltı + kısa miyav
    rise = mix(*[(at(0.04 + i * 0.07), pluck(f)) for i, f in enumerate([987.77, 1046.5, 1244.5])])
    write_wav("cat_found.wav", mix((0, thock(0.1, 50)), (0, rise), (at(0.24), 0.18 * sparkle()), (at(0.2), 0.35 * meow(0.2, 820))), 0.6)
    # Yanlış kedi: alçalan, boğuk iki ses
    write_wav("cat_wrong.wav", mix((0, glide(330, 196, 0.22, 0.1)), (at(0.08), 0.8 * tone(150, 0.25, (1, 0.6, 0.3), decay=0.1)), (0, 0.5 * thock(0.1, 45))), 0.55)
    # İpucu ("?"): sihirli yükselen arpej, son nota çınlar
    magic = mix(*[(at(i * 0.045), pluck(f, 0.25 if i < 3 else 0.8, 0.06 if i < 3 else 0.35)) for i, f in enumerate([987.77, 1318.5, 1975.5, 2637])])
    write_wav("cat_hint.wav", mix((0, magic), (at(0.12), 0.25 * tone(1318.5, 0.7, (1, 0.2), decay=0.3))), 0.5)
    # Kombo: tiz, uzun çınlayan çan
    write_wav("cat_combo.wav", mix((0, tone(2093, 0.9, (1, 0.25, 0.08), decay=0.4)), (at(0.05), 0.4 * tone(3136, 0.6, (1,), decay=0.25))), 0.4)
    # Bölüm bitti: neşeli fanfar + iki miyav
    notes = [(0.0, 659.25), (0.1, 783.99), (0.2, 987.77), (0.3, 1318.5), (0.48, 1318.5), (0.48, 987.77), (0.48, 659.25)]
    fan = mix(*[(at(s), tone(f, 1.0 if s >= 0.48 else 0.25, (1, 0.45, 0.2, 0.08), decay=0.5 if s >= 0.48 else 0.1)) for s, f in notes])
    write_wav("cat_win.wav", mix((0, fan), (at(0.48), 0.3 * noise(1.1, 0.45, 0.85)), (at(0.55), 0.5 * meow(0.22, 760)), (at(0.82), 0.55 * meow(0.45, 600))), 0.65)


if __name__ == "__main__":
    cat_effects()
    for f in sorted(OUT.glob("cat_*.wav")):
        print(f"{f.name:16s} {f.stat().st_size // 1024} KB")
