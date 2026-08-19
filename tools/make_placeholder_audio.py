#!/usr/bin/env python3
"""Erzeugt die Platzhalter-Klänge für "Our Story".

    python3 tools/make_placeholder_audio.py

Alle Dateien unter `audio/` entstehen hier — synthetisch, ohne Fremdmaterial,
ohne Abhängigkeiten. Das ist ausdrücklich **kein** Ersatz für echte Aufnahmen:
es sind Töne in der richtigen Länge, Lautstärke und Rolle, damit sich Timing
und Mischung beurteilen lassen. Wer eine Datei ersetzt, muss hier nichts
ändern — das Spiel lädt schlicht die Datei unter demselben Namen.

Warum ein Skript und keine eingecheckten Klänge allein: so lässt sich ein
Schritt kürzer, ein Einschlag trockener, die Musik langsamer machen, ohne
Audio-Werkzeug — eine Zahl ändern und neu erzeugen.
"""

import math
import os
import random
import struct
import wave

RATE = 22050
AUS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio")


# --- Werkzeug --------------------------------------------------------------


def schreibe(name, samples, spitze=0.7):
    """Normiert auf `spitze` und schreibt eine 16-bit-Mono-WAV."""
    hoch = max(abs(s) for s in samples) or 1.0
    faktor = spitze / hoch
    roh = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, s * faktor)) * 32767)) for s in samples
    )
    pfad = os.path.join(AUS, name)
    with wave.open(pfad, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(roh)
    print("%-22s %5.2f s" % (name, len(samples) / RATE))


def tiefpass(samples, cutoff):
    """Einpoliger Tiefpass. Genug, um Rauschen zu formen."""
    dt = 1.0 / RATE
    rc = 1.0 / (2 * math.pi * cutoff)
    alpha = dt / (rc + dt)
    aus, letzter = [], 0.0
    for s in samples:
        letzter += alpha * (s - letzter)
        aus.append(letzter)
    return aus


def hochpass(samples, cutoff):
    dt = 1.0 / RATE
    rc = 1.0 / (2 * math.pi * cutoff)
    alpha = rc / (rc + dt)
    aus, vorher_ein, vorher_aus = [], 0.0, 0.0
    for s in samples:
        vorher_aus = alpha * (vorher_aus + s - vorher_ein)
        vorher_ein = s
        aus.append(vorher_aus)
    return aus


def rauschen(dauer):
    return [random.uniform(-1.0, 1.0) for _ in range(int(dauer * RATE))]


def sinus(frequenz, dauer, phase=0.0):
    n = int(dauer * RATE)
    return [math.sin(2 * math.pi * frequenz * i / RATE + phase) for i in range(n)]


def huellkurve(samples, anstieg, abfall):
    """Weicher Anstieg, exponentieller Abfall — die Form fast aller Klänge."""
    n = len(samples)
    an = max(1, int(anstieg * RATE))
    aus = []
    for i, s in enumerate(samples):
        pegel = min(1.0, i / an)
        pegel *= math.exp(-i / (abfall * RATE))
        aus.append(s * pegel)
    return aus


def mische(*spuren):
    laenge = max(len(s) for s in spuren)
    summe = [0.0] * laenge
    for spur in spuren:
        for i, s in enumerate(spur):
            summe[i] += s
    return summe


def schleife_schliessen(samples, ueberblendung=1.0):
    """Blendet das Ende in den Anfang, damit die Schleife nicht klickt."""
    n = int(ueberblendung * RATE)
    if n * 2 >= len(samples):
        return samples
    kopf = samples[:n]
    rest = samples[n:-n]
    schwanz = samples[-n:]
    verbunden = [
        schwanz[i] * (1.0 - i / n) + kopf[i] * (i / n) for i in range(n)
    ]
    return verbunden + rest


# --- Die einzelnen Klänge --------------------------------------------------


def schritte():
    """Vier Varianten, damit das Gehen nicht tickt wie ein Metronom.

    Ein Schritt ist kein Klopfen, sondern zwei Berührungen: die **Ferse**
    setzt dumpf und kurz auf, der **Ballen** rollt eine Sechzigstelsekunde
    später weicher und breiter nach. Dazu ein Hauch Sohlenreibung auf dem
    Pflaster. Der Abstand und die Färbung variieren je Variante — genau die
    Unordnung, an der das Ohr „echt" erkennt."""
    for nummer in range(1, 5):
        random.seed(100 + nummer)
        luecke = 0.052 + 0.009 * nummer
        n_gesamt = int(0.3 * RATE)

        ferse_rauschen = tiefpass(rauschen(0.09), 360 + nummer * 45)
        ferse_koerper = [
            0.45 * s
            for s in huellkurve(sinus(80 + nummer * 7, 0.09), 0.001, 0.02)
        ]
        ferse = mische(huellkurve(ferse_rauschen, 0.0008, 0.02), ferse_koerper)

        ballen_rauschen = hochpass(tiefpass(rauschen(0.12), 1400 + nummer * 100), 450)
        ballen = [0.5 * s for s in huellkurve(ballen_rauschen, 0.004, 0.042)]

        reibung = hochpass(rauschen(0.14), 1900)
        reibung = [0.09 * s for s in huellkurve(reibung, 0.012, 0.055)]

        spur = [0.0] * n_gesamt
        for i, s in enumerate(ferse):
            if i < n_gesamt:
                spur[i] += s
        start = int(luecke * RATE)
        for quelle in (ballen, reibung):
            for i, s in enumerate(quelle):
                if start + i < n_gesamt:
                    spur[start + i] += s
        schreibe("schritt_%d.wav" % nummer, spur, 0.5)


def einschlag():
    """Der Dart-Treffer: ein trockener Schlag ins Brett."""
    random.seed(7)
    ton = [math.sin(2 * math.pi * (200 * math.exp(-i / (0.03 * RATE)) + 70) * i / RATE)
           for i in range(int(0.3 * RATE))]
    holz = tiefpass(rauschen(0.3), 1600)
    spur = mische(
        huellkurve(ton, 0.001, 0.05),
        [s * 0.5 for s in huellkurve(holz, 0.0005, 0.03)],
    )
    schreibe("einschlag.wav", spur)


def laden():
    """Gehaltener Ton beim Aufladen; das Spiel verschiebt die Tonhöhe."""
    dauer = 0.5
    grund = sinus(220.0, dauer)
    ober = [s * 0.25 for s in sinus(440.0, dauer)]
    spur = schleife_schliessen(mische(grund, ober), 0.05)
    schreibe("laden.wav", spur, 0.35)


def treffer_gut():
    """Kleine Bestätigung für einen guten Ring."""
    spur = mische(
        huellkurve(sinus(880.0, 0.6), 0.002, 0.16),
        [s * 0.5 for s in huellkurve(sinus(1320.0, 0.6), 0.002, 0.1)],
    )
    schreibe("treffer_gut.wav", spur, 0.5)


def gewonnen():
    """Vier Töne aufwärts — kurz, nicht triumphal."""
    noten = [523.25, 659.25, 783.99, 1046.5]
    laenge = int(1.6 * RATE)
    spur = [0.0] * laenge
    for i, note in enumerate(noten):
        start = int(i * 0.16 * RATE)
        klang = huellkurve(
            mische(sinus(note, 1.0), [s * 0.3 for s in sinus(note * 2, 1.0)]),
            0.004, 0.28,
        )
        for j, s in enumerate(klang):
            if start + j < laenge:
                spur[start + j] += s
    schreibe("gewonnen.wav", spur, 0.6)


def klick():
    """Menüklick — so kurz, dass er nicht auffällt, wenn man ihn oft hört."""
    spur = huellkurve(sinus(1180.0, 0.08), 0.001, 0.014)
    schreibe("klick.wav", spur, 0.35)


def stadt():
    """Ferne Stadt: Grundrauschen mit langsamer Bewegung, keine Ereignisse.

    Ereignisse (Autos, Stimmen) fehlen bewusst — eine Schleife mit erkennbarem
    Inhalt verrät sich nach dem zweiten Durchlauf.
    """
    random.seed(11)
    dauer = 14.0
    grund = tiefpass(rauschen(dauer), 220)
    luft = tiefpass(rauschen(dauer), 1400)
    spur = []
    for i in range(len(grund)):
        t = i / RATE
        atmen = 0.75 + 0.25 * math.sin(2 * math.pi * t / 7.0)
        spur.append(grund[i] * atmen + luft[i] * 0.12)
    schreibe("stadt.wav", schleife_schliessen(spur, 1.5), 0.5)


def bude_summen():
    """Das Leuchtschild der Dönerbude — Netzbrummen mit leichtem Flackern."""
    random.seed(3)
    dauer = 2.0
    n = int(dauer * RATE)
    spur = []
    for i in range(n):
        t = i / RATE
        flackern = 1.0 + 0.06 * math.sin(2 * math.pi * 11.0 * t)
        spur.append(
            (math.sin(2 * math.pi * 100.0 * t) * 0.7
             + math.sin(2 * math.pi * 150.0 * t) * 0.3) * flackern
        )
    schreibe("bude_summen.wav", schleife_schliessen(spur, 0.25), 0.4)


def titelmusik():
    """Vier Akkorde, langsam, als Warteschleife für den Titel.

    Bewusst schlicht: ein weicher Klangteppich und wenige Melodietöne darüber.
    Alles aus Sinustönen — das trägt als Platzhalter und nimmt einer echten
    Komposition nichts vorweg.
    """
    random.seed(5)
    akkorde = [
        [220.00, 261.63, 329.63],   # a-moll
        [174.61, 220.00, 261.63],   # F-dur
        [261.63, 329.63, 392.00],   # C-dur
        [196.00, 246.94, 293.66],   # G-dur
    ]
    melodie = [659.25, 523.25, 587.33, 493.88]
    takt = 4.0
    laenge = int(len(akkorde) * takt * RATE)
    spur = [0.0] * laenge

    for nummer, akkord in enumerate(akkorde):
        start = int(nummer * takt * RATE)
        for note in akkord:
            klang = huellkurve(
                mische(
                    sinus(note, takt + 1.0),
                    [s * 0.4 for s in sinus(note * 1.003, takt + 1.0)],
                    [s * 0.15 for s in sinus(note * 2.0, takt + 1.0)],
                ),
                0.8, 2.4,
            )
            for j, s in enumerate(klang):
                if start + j < laenge:
                    spur[start + j] += s * 0.33

        ton = melodie[nummer]
        einsatz = start + int(0.9 * takt * RATE / 2)
        klang = huellkurve(
            mische(sinus(ton, 2.5), [s * 0.2 for s in sinus(ton * 2, 2.5)]),
            0.05, 0.9,
        )
        for j, s in enumerate(klang):
            if einsatz + j < laenge:
                spur[einsatz + j] += s * 0.5

    schreibe("titelmusik.wav", schleife_schliessen(spur, 1.2), 0.55)


if __name__ == "__main__":
    os.makedirs(AUS, exist_ok=True)
    schritte()
    einschlag()
    laden()
    treffer_gut()
    gewonnen()
    klick()
    stadt()
    bude_summen()
    titelmusik()
    print("fertig — %s" % AUS)
