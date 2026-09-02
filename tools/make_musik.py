# Werkzeug: bereitet die CC0-Musik fürs Spiel auf.
#
# Quelle ist der GitHub-Korpus SoundSafari/CC0-1.0-Music (CC0 1.0,
# Sammlungen von freepd.com, chosic.com, freemusicarchive.org) — der
# Blob-lose Klon liegt im Scratchpad, ausgecheckt werden nur die fünf
# gewählten Stücke. Jedes wird auf 32 kHz Stereo gebracht (Vorbis
# ~0,77 MB/min — 44,1 kHz Stereo stürzt in dieser libsndfile ab),
# auf Ziellänge geschnitten und als **Crossfade-Loop** gebaut: die
# letzten Sekunden blenden auf den Anfang über, damit die Schleife
# nicht hörbar anschlägt. Pegel normalisiert auf −1 dB Spitze.
#
#   python3 tools/make_musik.py

import os

import numpy as np
import soundfile as sf

SR = 32000
KLON = ("/tmp/claude-0/-home-user-random/"
        "77c066ea-c61b-542f-b037-cab2bed7c7f3/scratchpad/musik_probe")

# Ziel, Quelldatei im Korpus, Schnittlänge in Sekunden (None = ganz),
# Crossfade-Länge für die Loop-Naht.
STUECKE = [
    ("titel", "freepd.com/Lovely Piano Song.mp3", None, 3.0),
    ("berlin", "chosic.com/Komiku_-_01_-_Level_10__Finally_together(chosic.com).mp3", 120.0, 3.0),
    ("frankfurt", "freepd.com/A Waltz For Naseem.mp3", 130.0, 3.0),
    ("hochzeit", "freemusicarchive.org/Ava Drumm - Canon in D Major (piano only).mp3", 150.0, 4.0),
    ("finale", "freepd.com/Romantic Inspiration.mp3", None, 4.0),
]


def resample(y: np.ndarray, sr_alt: int) -> np.ndarray:
    if sr_alt == SR:
        return y
    n_neu = int(len(y) * SR / sr_alt)
    t_alt = np.arange(len(y)) / sr_alt
    t_neu = np.arange(n_neu) / SR
    return np.stack([np.interp(t_neu, t_alt, y[:, k]) for k in range(2)], axis=1)


def loop_bauen(y: np.ndarray, fade_s: float) -> np.ndarray:
    """Crossfade-Loop: die letzten fade_s Sekunden werden auf den Anfang
    gemischt und dann abgeschnitten — die Naht liegt mitten im Klang."""
    f = int(fade_s * SR)
    rampe = np.linspace(0.0, 1.0, f)[:, None]
    y = y.copy()
    y[:f] = y[:f] * rampe + y[-f:] * (1.0 - rampe)
    return y[:-f]


def main(nur: int = -1) -> None:
    """`nur` >= 0 verarbeitet ein einzelnes Stück — die Vorbis-Schicht
    dieser libsndfile stürzt gelegentlich beim Prozessende ab, darum
    ruft der Sammellauf unten jedes Stück in einem eigenen Prozess auf."""
    os.makedirs("audio/musik", exist_ok=True)
    auswahl = STUECKE if nur < 0 else [STUECKE[nur]]
    for name, quelle, laenge, fade in auswahl:
        x, sr = sf.read(os.path.join(KLON, quelle))
        if x.ndim == 1:
            x = np.stack([x, x], axis=1)
        if laenge is not None:
            x = x[: int(laenge * sr)]
        y = resample(x, sr)
        y = loop_bauen(y, fade)
        y = y / max(np.max(np.abs(y)), 1e-9) * 0.89
        ziel = "audio/musik/%s.ogg" % name
        # Blockweise schreiben: ein einzelner grosser Write laesst den
        # Vorbis-Encoder dieser libsndfile abstuerzen.
        with sf.SoundFile(ziel, "w", SR, 2, format="OGG",
                          subtype="VORBIS") as datei:
            bloecke = np.array_split(
                y.astype(np.float32), max(len(y) // 65536, 1))
            for block in bloecke:
                datei.write(block)
        print("%s: %.0f s, %.2f MB" % (ziel, len(y) / SR,
                                       os.path.getsize(ziel) / 1048576))


if __name__ == "__main__":
    import subprocess
    import sys
    if len(sys.argv) > 1:
        main(int(sys.argv[1]))
    else:
        for i in range(len(STUECKE)):
            r = subprocess.run([sys.executable, __file__, str(i)])
            if r.returncode != 0:
                print("Stueck %d: Exit %d" % (i, r.returncode))
