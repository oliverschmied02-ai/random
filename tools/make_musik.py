# Werkzeug: bereitet die CC0-Musik fürs Spiel auf.
#
# Quelle ist der GitHub-Korpus SoundSafari/CC0-1.0-Music (CC0 1.0,
# Sammlungen von freepd.com, chosic.com, freemusicarchive.org) — der
# Blob-lose Klon liegt im Scratchpad, ausgecheckt werden nur die fünf
# gewählten Stücke. Jedes wird auf 48 kHz Stereo gebracht (44,1 kHz
# Stereo stürzt in dieser libsndfile ab, 48 kHz läuft; seit dem Split-
# Versand zählt das 100-MiB-Limit nicht mehr pro Build), auf Ziellänge
# geschnitten und als **Crossfade-Loop** gebaut: die
# letzten Sekunden blenden auf den Anfang über, damit die Schleife
# nicht hörbar anschlägt. Pegel normalisiert auf −1 dB Spitze.
#
#   python3 tools/make_musik.py

import os

import numpy as np
import soundfile as sf

SR = 48000
KLON = ("/tmp/claude-0/-home-user-random/"
        "77c066ea-c61b-542f-b037-cab2bed7c7f3/scratchpad/musik_probe")

# Olivers eigenes Stück für die Hochzeit (AcidPlanet-Archiv, von ihm
# hochgeladen; nur für den privaten Build). Liegt es im Repo, ersetzt es
# den Kanon in D. Der Ordner trägt eine .gdignore, damit die MP3-Quelle
# nicht mit ins Spiel exportiert wird.
EIGENES_HOCHZEIT = "audio/quellen/hochzeit_eigenes.mp3"

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
        eigenes = name == "hochzeit" and os.path.exists(EIGENES_HOCHZEIT)
        pfad = EIGENES_HOCHZEIT if eigenes else os.path.join(KLON, quelle)
        x, sr = sf.read(pfad)
        if x.ndim == 1:
            x = np.stack([x, x], axis=1)
        if eigenes:
            # Das eigene Stück endet mit Fadeout — die stille Schwanzspitze
            # abschneiden, sonst blendet der Loop ins Nichts über.
            fenster = int(0.5 * sr)
            huelle = np.sqrt(np.convolve((x ** 2).mean(axis=1),
                                         np.ones(fenster) / fenster, "same"))
            laut = np.nonzero(huelle > 0.02)[0]
            if len(laut) > 0:
                x = x[: laut[-1]]
            fade = 5.0
        elif laenge is not None:
            x = x[: int(laenge * sr)]
        y = resample(x, sr)
        y = loop_bauen(y, fade)
        if eigenes:
            # Deutlich lauter gemastert als die CC0-Stücke — auf das
            # RMS-Niveau der Musikbetten angleichen statt auf die Spitze.
            rms = float(np.sqrt((y ** 2).mean()))
            y = y * (0.11 / max(rms, 1e-9))
            # Das Intro des Stücks ist leiser als der Rest — die ersten
            # Sekunden bekommen einen sanft auslaufenden Schub (+2,5 dB
            # auf Eins in 18 s), damit der Einstieg trägt.
            t = np.arange(len(y)) / SR
            schub = 1.0 + 0.33 * np.clip(1.0 - t / 18.0, 0.0, 1.0)
            y = y * schub[:, None]
            spitze = float(np.max(np.abs(y)))
            if spitze > 0.95:
                y = y * (0.95 / spitze)
        else:
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
