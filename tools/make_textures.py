#!/usr/bin/env python3
"""Backt die PBR-Texturen der Berliner Kulisse.

Erzeugt je Materialsatz drei Karten (albedo/normal/rauheit) nach
assets/texturen/<satz>/ — nahtlos kachelbar, weil die Synthese über das
Frequenzspektrum läuft (FFT ist von Natur aus periodisch). Kein Foto,
keine Fremddaten: alles entsteht aus Rauschen, Blotches und Adern.

    python3 tools/make_textures.py

Die Sätze ersetzen die früheren Ein-Kanal-Rauschtexturen aus kulisse.gd.
Echte Foto-Sets (z. B. ambientCG, CC0) können die Dateien später eins zu
eins ersetzen — gleicher Name, gleicher Ort, fertig.
"""

from pathlib import Path

import numpy as np
from PIL import Image

WURZEL = Path(__file__).resolve().parent.parent / "assets" / "texturen"
N = 1024


def _spektrum_rauschen(n, seed, beta, cmin=1, cmax=None):
    """Kachelbares Rauschen: Amplitude ~ 1/f^beta, Bandpass in Zyklen/Bild."""
    rng = np.random.default_rng(seed)
    fy = np.fft.fftfreq(n)[:, None]
    fx = np.fft.fftfreq(n)[None, :]
    zyklen = np.sqrt(fy * fy + fx * fx) * n
    amp = np.zeros((n, n))
    maske = zyklen >= max(cmin, 0.5)
    if cmax is not None:
        maske &= zyklen <= cmax
    amp[maske] = zyklen[maske] ** (-beta)
    phase = np.exp(2j * np.pi * rng.random((n, n)))
    feld = np.fft.ifft2(amp * phase).real
    feld -= feld.min()
    spanne = feld.max()
    return feld / spanne if spanne > 0 else feld


def _normieren(feld):
    feld = feld - feld.min()
    m = feld.max()
    return feld / m if m > 0 else feld


def _warp(feld, staerke, seed):
    """Verbiegt ein Feld mit einem zweiten Rauschfeld — organischere Formen."""
    n = feld.shape[0]
    dx = (_spektrum_rauschen(n, seed, 2.2, 1, 6) - 0.5) * staerke * n
    dy = (_spektrum_rauschen(n, seed + 1, 2.2, 1, 6) - 0.5) * staerke * n
    yy, xx = np.mgrid[0:n, 0:n]
    yi = np.mod(yy + dy, n).astype(int)
    xi = np.mod(xx + dx, n).astype(int)
    return feld[yi, xi]


def _voronoi_abstaende(n, seed, anzahl):
    """F1/F2-Abstände und Zellenindex eines kachelbaren Voronoi-Felds."""
    rng = np.random.default_rng(seed)
    punkte = rng.random((anzahl, 2)) * n
    lagen = []
    for dy in (-n, 0, n):
        for dx in (-n, 0, n):
            lagen.append(punkte + np.array([dy, dx]))
    alle = np.concatenate(lagen)
    f1 = np.empty((n, n), dtype=np.float32)
    f2 = np.empty((n, n), dtype=np.float32)
    zelle = np.empty((n, n), dtype=np.int32)
    xs = np.arange(n, dtype=np.float32)
    for zeile in range(0, n, 32):
        ys = np.arange(zeile, min(zeile + 32, n), dtype=np.float32)
        gitter = np.stack(np.meshgrid(ys, xs, indexing="ij"), axis=-1)
        d = np.linalg.norm(gitter[:, :, None, :] - alle[None, None, :, :], axis=-1)
        sortiert = np.sort(d, axis=2)
        f1[zeile:zeile + 32] = sortiert[:, :, 0]
        f2[zeile:zeile + 32] = sortiert[:, :, 1]
        zelle[zeile:zeile + 32] = d.argmin(axis=2)
    return f1, f2, zelle


def _risse(n, seed, anzahl, breite=2.5, anteil=0.5):
    """Polygonales Rissnetz: Voronoi-Kanten (F2−F1 klein), leicht verbogen,
    und nur ein Teil der Kanten überlebt — Risse ziehen nicht überall."""
    f1, f2, zelle = _voronoi_abstaende(n, seed, anzahl)
    kante = np.clip(1.0 - (f2 - f1) / breite, 0, 1) ** 1.5
    kante = _warp(kante, 0.008, seed + 7)
    rng = np.random.default_rng(seed + 13)
    lebt = rng.random(zelle.max() + 1) < anteil
    return kante * lebt[zelle]


def _normal_aus_hoehe(hoehe, staerke):
    gy, gx = np.gradient(hoehe)
    nx = -gx * staerke * hoehe.shape[0]
    ny = gy * staerke * hoehe.shape[0]
    nz = np.ones_like(hoehe)
    laenge = np.sqrt(nx * nx + ny * ny + nz * nz)
    karte = np.stack([nx / laenge, ny / laenge, nz / laenge], axis=-1)
    return (karte * 0.5 + 0.5)


def _speichern(satz, albedo, normal, rauheit):
    ordner = WURZEL / satz
    ordner.mkdir(parents=True, exist_ok=True)

    def _jpg(name, feld, qualitaet=88):
        bild = np.clip(feld * 255.0, 0, 255).astype(np.uint8)
        Image.fromarray(bild).save(ordner / name, quality=qualitaet)

    _jpg("albedo.jpg", albedo)
    _jpg("normal.jpg", normal, 92)
    _jpg("rauheit.jpg", rauheit)
    print(f"  {satz}: albedo/normal/rauheit nach {ordner}")


def _grau_zu_rgb(feld, ton=(1.0, 1.0, 1.0)):
    return np.stack([feld * ton[0], feld * ton[1], feld * ton[2]], axis=-1)


def putz(seed=11):
    """Berliner Altbauputz: feine Körnung, Kellenwellen, Flecken, Haarrisse."""
    korn = _spektrum_rauschen(N, seed, 0.6, 80, 512)
    wellen = _spektrum_rauschen(N, seed + 1, 2.0, 3, 14)
    flecken = _warp(_spektrum_rauschen(N, seed + 2, 2.4, 1, 5), 0.05, seed + 3)
    risse = _risse(N, seed + 4, 24, 2.0, 0.3)

    hoehe = _normieren(0.55 * korn + 0.45 * wellen) - risse * 0.15
    albedo_g = 0.84 + 0.09 * korn - 0.05 * (1 - wellen) \
        - 0.10 * np.clip((flecken - 0.62) * 3, 0, 1) - 0.16 * risse
    albedo = _grau_zu_rgb(albedo_g, (1.0, 0.985, 0.955))
    rauheit = 0.84 + 0.08 * korn + 0.06 * np.clip((flecken - 0.62) * 3, 0, 1)
    return albedo, _normal_aus_hoehe(hoehe, 0.004), rauheit


def asphalt(seed=23):
    """Nasser Nachtasphalt: Körnung, Flickstellen, Risse — und Pfützen,
    die in der Rauheitskarte spiegelglatt werden."""
    korn = _spektrum_rauschen(N, seed, 0.5, 110, 512)
    flick = _warp(_spektrum_rauschen(N, seed + 1, 2.3, 2, 7), 0.06, seed + 2)
    risse = _risse(N, seed + 3, 36, 2.2, 0.35)
    pfuetzen_feld = _warp(_spektrum_rauschen(N, seed + 4, 2.6, 1, 4), 0.08, seed + 5)
    pfuetze = np.clip((pfuetzen_feld - 0.66) * 6.0, 0, 1)

    hoehe = _normieren(0.6 * korn + 0.35 * flick) - risse * 0.25
    hoehe = hoehe * (1 - 0.5 * pfuetze)  # Wasser glättet
    albedo_g = 0.26 + 0.17 * korn - 0.06 * np.clip((flick - 0.5) * 2, 0, 1) - 0.14 * risse
    albedo_g *= 1 - 0.45 * pfuetze  # nasse Stellen dunkler
    albedo = _grau_zu_rgb(albedo_g, (0.96, 1.0, 1.08))
    rauheit = 0.86 + 0.1 * korn - 0.1 * np.clip((flick - 0.55) * 2, 0, 1)
    rauheit = rauheit * (1 - pfuetze) + 0.06 * pfuetze
    return albedo, _normal_aus_hoehe(hoehe, 0.0035), rauheit


def beton_platten(seed=37):
    """Gehwegplatten: geschliffener Beton, Poren, Besenstrich, Regenflecken."""
    poren = _spektrum_rauschen(N, seed, 0.8, 80, 460)
    besen_grund = _spektrum_rauschen(N, seed + 1, 1.2, 4, 90)
    besen = np.repeat(besen_grund.mean(axis=1, keepdims=True), N, axis=1)
    flecken = _warp(_spektrum_rauschen(N, seed + 2, 2.5, 1, 6), 0.07, seed + 3)

    hoehe = _normieren(0.45 * poren + 0.2 * besen)
    albedo_g = 0.72 - 0.06 * poren - 0.12 * np.clip((flecken - 0.58) * 3, 0, 1)
    albedo = _grau_zu_rgb(albedo_g, (1.0, 1.0, 0.985))
    rauheit = 0.78 + 0.1 * poren + 0.08 * np.clip((flecken - 0.58) * 3, 0, 1)
    return albedo, _normal_aus_hoehe(hoehe, 0.002), rauheit


def beton_rau(seed=51):
    """Sockelbeton: grob, mit senkrechten Schmutzfahnen von Jahren Regen."""
    korn = _spektrum_rauschen(N, seed, 0.8, 40, 380)
    grob = _spektrum_rauschen(N, seed + 1, 1.9, 4, 18)
    fahnen_grund = _spektrum_rauschen(N, seed + 2, 1.6, 6, 60)
    # Senkrecht verschmieren: jede Spalte übernimmt ihren Mittelwert nach unten.
    fahnen = np.repeat(fahnen_grund.mean(axis=0, keepdims=True), N, axis=0)
    fahnen = _warp(fahnen, 0.02, seed + 3)

    hoehe = _normieren(0.5 * korn + 0.5 * grob)
    albedo_g = 0.56 - 0.07 * grob - 0.16 * np.clip((fahnen - 0.52) * 2.4, 0, 1)
    albedo = _grau_zu_rgb(albedo_g, (1.0, 0.99, 0.97))
    rauheit = 0.9 + 0.06 * korn
    return albedo, _normal_aus_hoehe(hoehe, 0.005), rauheit


def schotter(seed=67):
    """Gleisbett: Schottersteine als Voronoi-Zellen mit Kantenschatten."""
    rng = np.random.default_rng(seed)
    punkte = rng.random((150, 2)) * N
    # Kacheln: Punkte in alle acht Nachbarlagen spiegeln.
    lagen = []
    for dy in (-N, 0, N):
        for dx in (-N, 0, N):
            lagen.append(punkte + np.array([dy, dx]))
    alle = np.concatenate(lagen)

    abstand = np.empty((N, N), dtype=np.float32)
    naechster = np.empty((N, N), dtype=np.int32)
    xs = np.arange(N, dtype=np.float32)
    for zeile in range(0, N, 32):
        ys = np.arange(zeile, min(zeile + 32, N), dtype=np.float32)
        gitter = np.stack(np.meshgrid(ys, xs, indexing="ij"), axis=-1)
        d = np.linalg.norm(gitter[:, :, None, :] - alle[None, None, :, :], axis=-1)
        abstand[zeile:zeile + 32] = d.min(axis=2)
        naechster[zeile:zeile + 32] = d.argmin(axis=2)

    kante = _normieren(abstand)
    stein_ton = rng.random(len(alle)) * 0.3 + 0.35
    albedo_g = stein_ton[naechster] - 0.35 * kante ** 1.5
    hoehe = _normieren(1 - kante) * 0.8 + 0.2 * _spektrum_rauschen(N, seed + 1, 0.9, 60, 400)
    albedo = _grau_zu_rgb(np.clip(albedo_g, 0.05, 1), (1.0, 0.99, 0.97))
    rauheit = np.full((N, N), 0.95)
    return albedo, _normal_aus_hoehe(hoehe, 0.006), rauheit


if __name__ == "__main__":
    print("Backe Texturen nach", WURZEL)
    for name, ofen in [
        ("putz", putz),
        ("asphalt", asphalt),
        ("beton_platten", beton_platten),
        ("beton_rau", beton_rau),
        ("schotter", schotter),
    ]:
        a, n, r = ofen()
        _speichern(name, a, n, r)
    print("fertig")
