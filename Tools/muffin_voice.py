"""Muffin'in miyavlarını ses kayıtlarından üretir (numpy + scipy).

Kullanım:  python3 Tools/muffin_voice.py <kayıt klasörü>
Klasörde in/rec2.wav, rec5.wav, rec6.wav, rec7.wav (44.1 kHz mono) beklenir; ham kayıtlar
depoda tutulmaz. Çıktılar klasöre yazılır ve Catgrid/Resources/Sounds/muffin_*.wav olarak
kopyalanır: talk (rec5 + rec2), question (rec2, sonu yükselen), joy (rec6 uzun miyav),
oops (rec7 kısa miyav). Perde yükseltme sesi küçük bir kedi gibi inceltir; yankı çok hafif.
"""
import sys, wave, numpy as np
from scipy.signal import butter, sosfilt
RATE = 44100
D = sys.argv[1]

def load(i):
    w = wave.open(f"{D}/in/rec{i}.wav")
    return np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(float) / 32768

def trim(a, start=None, end=None, thresh=0.12):
    env = np.convolve(np.abs(a), np.ones(441) / 441, "same")
    idx = np.where(env > env.max() * thresh)[0]
    s = idx[0] if start is None else int(start * RATE)
    e = idx[-1] if end is None else int(end * RATE)
    return a[max(0, s - 800):min(len(a), e + 1500)]

def clean(a):
    a = sosfilt(butter(3, 160, "highpass", fs=RATE, output="sos"), a)
    a = sosfilt(butter(4, 9000, "lowpass", fs=RATE, output="sos"), a)
    # Yumuşak gürültü kapısı: sessiz kısımlardaki hışırtı kısılır
    env = np.convolve(np.abs(a), np.ones(882) / 882, "same")
    gate = np.clip((env / (env.max() * 0.06)) ** 2, 0, 1)
    return a * gate

def repitch(a, semis):
    """Zamanla değişen perde (yarım ton). Okuma hızı değişir: kedi gibi daha küçük/tiz ses."""
    semis = np.asarray(semis, float)
    out, pos = [], 0.0
    n = len(a)
    while pos < n - 2:
        k = pos / n
        rate = 2 ** (np.interp(k, np.linspace(0, 1, len(semis)), semis) / 12)
        i = int(pos); f = pos - i
        out.append(a[i] * (1 - f) + a[i + 1] * f)
        pos += rate
    return np.array(out)

def fade(a, inn=0.02, out=0.08):
    a = a.copy(); i = int(inn * RATE); o = int(out * RATE)
    a[:i] *= np.linspace(0, 1, i); a[-o:] *= np.linspace(1, 0, o)
    return a

def reverb(a, mix=0.07):
    y = np.concatenate([a, np.zeros(int(0.25 * RATE))])
    for d, g in ((0.021, 0.5), (0.037, 0.4), (0.059, 0.3), (0.089, 0.2), (0.131, 0.12)):
        s = int(d * RATE); y[s:s + len(a)] += mix * g * a
    return y

def write(name, a):
    a = reverb(fade(a)); a = a / np.max(np.abs(a)) * 0.55
    with wave.open(f"{D}/{name}", "wb") as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE)
        f.writeframes((a * 32767).astype(np.int16).tobytes())

r2, r5, r6, r7 = (clean(trim(load(i))) for i in (2, 5, 6, 7))
gap = np.zeros(int(0.08 * RATE))
write("muffin_talk.wav", np.concatenate([fade(repitch(r5, [5, 6, 5, 6, 4])), gap, repitch(r2, [6, 5, 4, 2])]))
write("muffin_question.wav", repitch(r2, [5, 5, 7, 10]))
write("muffin_joy.wav", repitch(r6, [8, 9, 10, 10, 9, 7]))
write("muffin_oops.wav", repitch(r7, [9, 9, 6, 3]))
