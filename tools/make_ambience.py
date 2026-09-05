# Werkzeug: synthetisiert drei Ambience-Klänge als WAV.
#
#   audio/wellen_moewen.wav  — 24-s-Loop: Spree-Wellen mit Schwall-Zischen
#                              und vier Möwenrufen (Hochzeitskapitel).
#   audio/zug_rumpeln.wav    —  8-s-Loop: tiefes Fahrwerk-Rumpeln mit
#                              Schienenstoß-Doppelklack (Zugszene).
#   audio/brems_zisch.wav    — One-Shot: Druckluft-Zischen beim Halt.
#
# Alle Filter laufen über die FFT — zirkulare Faltung, dadurch sind die
# Loops an der Nahtstelle mathematisch nahtlos. LFOs nutzen nur ganze
# Zyklen pro Loop-Länge, Rufe/Klacks liegen fest im Loop-Fenster.
#
#   python3 tools/make_ambience.py

import numpy as np
import soundfile as sf

SR = 44100
RNG = np.random.default_rng(20230922)  # das Hochzeitsdatum als Saat


def bandpass_loop(x: np.ndarray, lo: float, hi: float, glaette: float = 0.4) -> np.ndarray:
    """Bandpass ueber die FFT — zirkular, also loop-sicher. Flanken weich
    auf der Log-Frequenzachse (glaette in Oktaven)."""
    spektrum = np.fft.rfft(x)
    freq = np.fft.rfftfreq(len(x), 1.0 / SR)
    freq = np.maximum(freq, 0.1)
    oktave = np.log2(freq)
    maske = (1.0 / (1.0 + np.exp(-(oktave - np.log2(lo)) / glaette))
             * 1.0 / (1.0 + np.exp((oktave - np.log2(hi)) / glaette)))
    return np.fft.irfft(spektrum * maske, n=len(x))


def normieren(x: np.ndarray, pegel: float = 0.85) -> np.ndarray:
    return x / max(np.max(np.abs(x)), 1e-9) * pegel


def lfo(dauer_s: float, n: int, zyklen: int, phase: float = 0.0) -> np.ndarray:
    """Sinus-LFO mit ganzen Zyklen ueber den Loop — nahtlos per Bau."""
    t = np.arange(n) / SR
    return np.sin(2.0 * np.pi * zyklen / dauer_s * t + phase)


def moewenruf(laenge_s: float, f_start: float, f_ende: float) -> np.ndarray:
    """Ein einzelner Moewenschrei: fallender FM-Ton mit Vibrato und
    rauem Rand, Huellkurve mit hartem Ansatz."""
    n = int(laenge_s * SR)
    t = np.arange(n) / SR
    verlauf = f_start + (f_ende - f_start) * (t / laenge_s) ** 0.7
    vibrato = 1.0 + 0.035 * np.sin(2.0 * np.pi * 38.0 * t)
    phase = 2.0 * np.pi * np.cumsum(verlauf * vibrato) / SR
    ton = np.sin(phase) + 0.35 * np.sin(2.0 * phase) + 0.12 * np.sin(3.0 * phase)
    rauheit = 1.0 + 0.20 * RNG.standard_normal(n)
    huelle = np.minimum(t / 0.012, 1.0) * np.exp(-t / (laenge_s * 0.38))
    huelle *= np.sin(np.pi * np.minimum(t / laenge_s, 1.0)) ** 0.25
    return ton * rauheit * huelle


def wellen_moewen() -> None:
    dauer = 24.0
    n = int(dauer * SR)

    # Grundwasser: tief gefiltertes Rauschen, das mit zwei ineinander
    # laufenden LFOs (3 und 5 Zyklen pro Loop) an- und abschwillt.
    grund = bandpass_loop(RNG.standard_normal(n), 60.0, 700.0)
    schwall = 0.55 + 0.28 * lfo(dauer, n, 3) + 0.17 * lfo(dauer, n, 5, 1.3)
    grund *= schwall

    # Der Schaum auf dem Wellenkamm: helleres Rauschen, nur auf den
    # Kaemmen hoerbar (Schwall-Kurve hochpotenziert).
    schaum = bandpass_loop(RNG.standard_normal(n), 900.0, 4200.0)
    kamm = np.clip(0.5 + 0.5 * lfo(dauer, n, 3, 0.5), 0.0, 1.0) ** 3.2
    schaum *= kamm * 0.7

    links = grund * 1.0 + schaum * 0.8
    rechts = grund * 0.92 + schaum * 1.0

    # Vier Moewen, fest im Loop verteilt, jede an anderer Stelle im Panorama.
    rufe = [
        (3.4, 1350.0, 950.0, 0.62, 0.25, 3),
        (9.1, 1500.0, 1050.0, 0.55, 0.85, 2),
        (14.7, 1250.0, 900.0, 0.70, 0.45, 3),
        (20.2, 1420.0, 980.0, 0.50, 0.70, 2),
    ]
    for start, f0, f1, laenge, pan, anzahl in rufe:
        for wiederholung in range(anzahl):
            ruf = moewenruf(laenge * (0.85 ** wiederholung), f0 * (1.02 ** wiederholung), f1)
            ab = int((start + wiederholung * laenge * 0.75) * SR)
            ende = min(ab + len(ruf), n)
            pegel = 0.16 * (0.8 ** wiederholung)
            links[ab:ende] += ruf[: ende - ab] * pegel * (1.0 - pan)
            rechts[ab:ende] += ruf[: ende - ab] * pegel * pan

    # Stereo: seit der Build in Teilstücken ausgeliefert wird, zählt das
    # 100-MiB-Limit pro Datei nicht mehr — die Möwen dürfen wieder wandern.
    stereo = np.stack([normieren(links), normieren(rechts)], axis=1)
    sf.write("audio/wellen_moewen.wav", stereo, SR, subtype="PCM_16")
    print("wellen_moewen.wav:", dauer, "s Loop")


def zug_rumpeln() -> None:
    dauer = 8.0
    n = int(dauer * SR)
    t = np.arange(n) / SR

    # Fahrwerk: sehr tiefes Rauschen plus ein 34-Hz-Brummen, beides mit
    # langsamem Wobble (2 und 3 Zyklen pro Loop).
    rumpeln = bandpass_loop(RNG.standard_normal(n), 28.0, 150.0)
    rumpeln *= 0.75 + 0.18 * lfo(dauer, n, 2) + 0.10 * lfo(dauer, n, 3, 0.7)
    brumm = np.sin(2.0 * np.pi * 34.0 * t) * (0.16 + 0.05 * lfo(dauer, n, 2, 1.9))

    # Fahrtwind an der Scheibe, ganz leise.
    wind = bandpass_loop(RNG.standard_normal(n), 400.0, 2400.0)
    wind *= (0.10 + 0.04 * lfo(dauer, n, 5, 0.3))

    # Schienenstoesse: alle 1,6 s ein Doppelklack („da-dumm"), 5 pro Loop
    # — teilt die Loop-Laenge exakt, darum nahtlos.
    def klack(pegel: float) -> np.ndarray:
        m = int(0.09 * SR)
        tt = np.arange(m) / SR
        stoss = bandpass_loop(RNG.standard_normal(m), 220.0, 950.0)
        return stoss * np.exp(-tt / 0.016) * pegel

    schiene = np.zeros(n)
    for i in range(5):
        ab = int(i * 1.6 * SR)
        erster = klack(1.0)
        zweiter = klack(0.62)
        schiene[ab:ab + len(erster)] += erster
        ab2 = ab + int(0.14 * SR)
        schiene[ab2:ab2 + len(zweiter)] += zweiter
    schiene = normieren(schiene, 0.5)

    mono = normieren(rumpeln + brumm + wind + schiene, 0.88)
    stereo = np.stack([mono, np.roll(mono, int(0.0006 * SR))], axis=1)
    sf.write("audio/zug_rumpeln.wav", stereo, SR, subtype="PCM_16")
    print("zug_rumpeln.wav:", dauer, "s Loop")


def brems_zisch() -> None:
    dauer = 3.2
    n = int(dauer * SR)
    t = np.arange(n) / SR

    # Hauptzischen: heller Druckluftstoss, schneller Ansatz, langes
    # Ausatmen. FFT-Filter ist hier egal (One-Shot), aber praktisch.
    zisch = bandpass_loop(RNG.standard_normal(n), 1800.0, 9000.0)
    huelle = np.minimum(t / 0.03, 1.0) * np.exp(-t / 0.9)
    zisch *= huelle

    # Der zweite, kurze Nachlass-Stoss bei 1,9 s — typisch Pneumatik.
    nach = np.zeros(n)
    ab = int(1.9 * SR)
    m = int(0.5 * SR)
    tt = np.arange(m) / SR
    puff = bandpass_loop(RNG.standard_normal(m), 2200.0, 9500.0)
    nach[ab:ab + m] = puff * np.minimum(tt / 0.02, 1.0) * np.exp(-tt / 0.16) * 0.7

    # Leises Quietschen der Klotzbremse, leicht fallend.
    quietsch_f = 2400.0 - 300.0 * (t / dauer)
    quietsch = np.sin(2.0 * np.pi * np.cumsum(quietsch_f) / SR)
    quietsch *= (0.5 + 0.5 * np.sin(2.0 * np.pi * 9.0 * t)) * huelle * 0.10

    mono = normieren(zisch + nach + quietsch, 0.9)
    stereo = np.stack([mono, mono * 0.94], axis=1)
    sf.write("audio/brems_zisch.wav", stereo, SR, subtype="PCM_16")
    print("brems_zisch.wav: One-Shot,", dauer, "s")


def stadt_fern() -> None:
    """Leises Tages-Stadtrauschen fuer die Hochzeit am Spreeufer: fernes
    Verkehrsgrundrauschen, ab und zu ein weiches Anschwellen (ein Auto
    auf der Bruecke), ein Hauch Luft in den Hoehen. Kein Meer, keine
    Moewen — die Kulisse ist mitten in Berlin. 24-s-Loop, nahtlos wie
    die uebrigen (FFT-Filter, ganze LFO-Zyklen)."""
    dauer = 24.0
    n = int(dauer * SR)

    # Grundteppich: tiefes, breites Rauschen — die Stadt als Ganzes.
    teppich = bandpass_loop(RNG.standard_normal(n), 40.0, 500.0)
    teppich *= 0.55 + 0.10 * lfo(dauer, n, 2) + 0.06 * lfo(dauer, n, 5, 1.1)

    # Hoehen-Luft: sehr leise, nimmt dem Teppich das Dumpfe.
    luft = bandpass_loop(RNG.standard_normal(n), 1200.0, 5000.0) * 0.06

    # Drei weiche Vorbeifahrten, fest im Loop verteilt: ein Anschwellen
    # im Mittenband, ein paar Sekunden lang.
    fahrten = np.zeros(n)
    t = np.arange(n) / SR
    for start, laenge, staerke in [(4.0, 5.0, 0.5), (12.5, 4.2, 0.35),
                                   (18.5, 4.8, 0.45)]:
        fenster = np.exp(-((t - start - laenge / 2.0) ** 2)
                         / (2.0 * (laenge / 4.0) ** 2))
        fahrten += fenster * staerke
    mitten = bandpass_loop(RNG.standard_normal(n), 150.0, 900.0)
    fahrt_klang = mitten * fahrten

    mono = normieren(teppich + luft + fahrt_klang, 0.8)
    stereo = np.stack([mono, np.roll(mono, int(0.0009 * SR))], axis=1)
    sf.write("audio/stadt_fern.wav", stereo, SR, subtype="PCM_16")
    print("stadt_fern.wav:", dauer, "s Loop")


if __name__ == "__main__":
    wellen_moewen()
    zug_rumpeln()
    brems_zisch()
    stadt_fern()
