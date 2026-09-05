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
    """Drei Resonanzen im Spektrum — das Ohr hoert einen Vokal.

    Die Baender sind bewusst BREIT (130-320 Hz): schmale Gauss-Spitzen
    klingeln wie eine Glocke — genau das „Metallische" der ersten
    Fassung. Dazu ein sanfter Hoehenabfall ab 3,5 kHz und ein Rest
    Grundspektrum, damit die Stimme einen Koerper behaelt."""
    spektrum = np.fft.rfft(x)
    freq = np.fft.rfftfreq(len(x), 1.0 / SR)
    maske = np.full_like(freq, 0.06)
    for staerke, (mitte, breite) in zip(
            (1.0, 0.55, 0.22),
            ((formanten[0] * faktor, 130.0),
             (formanten[1] * faktor, 220.0),
             (formanten[2] * faktor, 320.0))):
        maske += staerke * np.exp(-((freq - mitte) ** 2) / (2.0 * breite ** 2))
    maske *= 1.0 / (1.0 + np.exp((freq - 3500.0) / 700.0)) + 0.02
    return np.fft.irfft(spektrum * maske, n=len(x))


def _vokal(dauer: float, f0: float, formanten: tuple, faktor: float) -> np.ndarray:
    n = int(dauer * SR)
    t = np.arange(n) / SR
    # Tonhoehenbogen plus Jitter: echte Stimmen halten keinen Ton exakt —
    # das langsame Zittern (~3 Hz Rauschband) nimmt der Silbe das Maschinelle.
    jitter = np.interp(t, np.linspace(0.0, dauer, 12),
                       RNG.normal(0.0, 0.012, 12))
    bogen = f0 * (1.0 + RNG.uniform(-0.14, 0.20) * (t / dauer) + jitter) \
        * (1.0 + 0.006 * np.sin(2.0 * np.pi * 5.0 * t))
    phase = 2.0 * np.pi * np.cumsum(bogen) / SR
    # Obertonreihe mit steilerem 1/k^1.5-Abfall — eine weiche Quelle;
    # die alte 1/k-Reihe war saegezahnhell und klang nach Summer.
    quelle = np.zeros(n)
    for k in range(1, 24):
        quelle += np.sin(phase * k) / (k ** 1.5)
    # Hauch: leises Rauschen durch dieselben Formanten — Atem in der Stimme.
    hauch = RNG.standard_normal(n) * 0.10
    laut = _formant_filter(quelle + hauch, formanten, faktor)
    # Amplituden-Schimmer: kleine, langsame Lautstaerkewellen.
    schimmer = 1.0 + 0.10 * np.interp(t, np.linspace(0.0, dauer, 8),
                                      RNG.normal(0.0, 1.0, 8))
    huelle = np.minimum(t / 0.03, 1.0) * np.minimum((dauer - t) / 0.07, 1.0)
    return laut * schimmer * np.clip(huelle, 0.0, 1.0)


def _konsonant() -> np.ndarray:
    """Kurzer Ansatz vor dem Vokal: mal Zischlaut, mal dumpfer Lippenlaut."""
    if RNG.random() < 0.45:
        n = int(RNG.uniform(0.015, 0.032) * SR)
        rauschen = RNG.standard_normal(n)
        spektrum = np.fft.rfft(rauschen)
        freq = np.fft.rfftfreq(n, 1.0 / SR)
        # Weicher und tiefer als vorher — ein „sch/f" statt Zischspitze.
        spektrum *= np.exp(-((freq - 2400.0) ** 2) / (2.0 * 1600.0 ** 2))
        laut = np.fft.irfft(spektrum, n=n)
        laut *= np.linspace(1.0, 0.3, n)
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
    k = _konsonant() * 0.7
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
