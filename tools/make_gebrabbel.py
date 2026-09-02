# Werkzeug: synthetisiert Sims-artiges Dialog-Gebrabbel („Simlish").
#
# Für jede Stimme entstehen zwölf kurze Silben als einzelne Ogg-Dateien
# (audio/gebrabbel/anne_01.ogg … oliver_12.ogg). Die DialogueBox reiht
# sie zur Laufzeit zufällig aneinander, solange der Schreibmaschinen-
# Text läuft — das klingt nach Unterhaltung, ohne je ein Wort zu sagen.
#
# Bauweise je Silbe: ein Konsonanten-Ansatz (kurzer Rauschimpuls oder
# dumpfer Lippenlaut), dann ein Vokal — Obertonreihe auf einer leicht
# gleitenden Grundfrequenz, geformt von drei Formant-Resonanzen (F1–F3
# echter Vokale). Anne liegt um 210 Hz, Oliver um 118 Hz.
#
#   python3 tools/make_gebrabbel.py

import os

import numpy as np
import soundfile as sf

SR = 44100
RNG = np.random.default_rng(1305)

# F1/F2/F3 der fünf Grundvokale (grob nach Lehrbuchwerten, Hz).
VOKALE = {
    "a": (800.0, 1200.0, 2500.0),
    "e": (400.0, 2200.0, 2800.0),
    "i": (280.0, 2300.0, 3000.0),
    "o": (450.0, 800.0, 2600.0),
    "u": (320.0, 700.0, 2500.0),
}


def _formant_filter(x: np.ndarray, formanten: tuple, faktor: float) -> np.ndarray:
    """Drei Gauss-Resonanzen im Spektrum — das Ohr hoert einen Vokal."""
    spektrum = np.fft.rfft(x)
    freq = np.fft.rfftfreq(len(x), 1.0 / SR)
    maske = np.zeros_like(freq)
    for staerke, (mitte, breite) in zip(
            (1.0, 0.63, 0.32),
            ((formanten[0] * faktor, 90.0),
             (formanten[1] * faktor, 130.0),
             (formanten[2] * faktor, 180.0))):
        maske += staerke * np.exp(-((freq - mitte) ** 2) / (2.0 * breite ** 2))
    return np.fft.irfft(spektrum * maske, n=len(x))


def _vokal(dauer: float, f0: float, formanten: tuple, faktor: float) -> np.ndarray:
    n = int(dauer * SR)
    t = np.arange(n) / SR
    # Tonhoehenbogen: jede Silbe steigt oder faellt ein Stueck — Sprachmelodie.
    bogen = f0 * (1.0 + RNG.uniform(-0.16, 0.22) * (t / dauer)) \
        * (1.0 + 0.008 * np.sin(2.0 * np.pi * 5.5 * t))
    phase = 2.0 * np.pi * np.cumsum(bogen) / SR
    # Obertonreihe mit 1/k-Abfall — roh wie eine Stimmritze, die Formanten
    # formen daraus den Vokal.
    quelle = np.zeros(n)
    for k in range(1, 30):
        quelle += np.sin(phase * k) / k
    laut = _formant_filter(quelle, formanten, faktor)
    huelle = np.minimum(t / 0.018, 1.0) * np.minimum((dauer - t) / 0.05, 1.0)
    return laut * np.clip(huelle, 0.0, 1.0)


def _konsonant() -> np.ndarray:
    """Kurzer Ansatz vor dem Vokal: mal Zischlaut, mal dumpfer Lippenlaut."""
    if RNG.random() < 0.5:
        n = int(RNG.uniform(0.018, 0.04) * SR)
        rauschen = RNG.standard_normal(n)
        spektrum = np.fft.rfft(rauschen)
        freq = np.fft.rfftfreq(n, 1.0 / SR)
        spektrum *= np.exp(-((freq - 3200.0) ** 2) / (2.0 * 1400.0 ** 2))
        laut = np.fft.irfft(spektrum, n=n)
    else:
        n = int(RNG.uniform(0.02, 0.035) * SR)
        t = np.arange(n) / SR
        laut = np.sin(2.0 * np.pi * 190.0 * t) * np.exp(-t / 0.01)
    return laut / max(np.max(np.abs(laut)), 1e-9) * 0.5


def silbe(f0: float, faktor: float) -> np.ndarray:
    vokal_name = list(VOKALE.keys())[RNG.integers(0, len(VOKALE))]
    dauer = RNG.uniform(0.11, 0.24)
    v = _vokal(dauer, f0 * RNG.uniform(0.92, 1.10), VOKALE[vokal_name], faktor)
    v /= max(np.max(np.abs(v)), 1e-9)
    k = _konsonant()
    ton = np.concatenate([k, v * 0.9])
    return ton / max(np.max(np.abs(ton)), 1e-9) * 0.8


def stimme(name: str, f0: float, faktor: float, anzahl: int = 12) -> None:
    os.makedirs("audio/gebrabbel", exist_ok=True)
    for i in range(anzahl):
        ton = silbe(f0, faktor)
        sf.write("audio/gebrabbel/%s_%02d.ogg" % (name, i + 1), ton, SR,
                 format="OGG", subtype="VORBIS")
    print(name, ":", anzahl, "Silben um", f0, "Hz")


if __name__ == "__main__":
    # Annes Stimme: hoeher, Formanten ein Stueck nach oben (kuerzerer
    # Vokaltrakt); Olivers: tief, Formanten leicht gesenkt.
    stimme("anne", 210.0, 1.14)
    stimme("oliver", 118.0, 0.94)
