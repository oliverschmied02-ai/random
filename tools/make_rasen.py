# Werkzeug: erzeugt einen kachelbaren Rasen-Textursatz
# (assets/texturen/rasen/{albedo,normal,rauheit}.jpg, 512 px).
#
# Alles laeuft ueber FFT-gefiltertes Rauschen — zirkulare Faltung macht
# die Kacheln von selbst nahtlos. Drei Schichten:
#   * grosse weiche Farbflecken (satteres und ausgeblichenes Gruen),
#   * feine Halm-Strichel (hochfrequent, leicht gerichtet),
#   * ein paar erdige Stellen, wo der Rasen duenn ist.
# Die Normal-Map kommt aus der Halm-Hoehe, die Rauheit bleibt hoch.
#
#   python3 tools/make_rasen.py

import os

import numpy as np
from PIL import Image

N = 512
RNG = np.random.default_rng(2209)


def _tief(sigma_px: float) -> np.ndarray:
    """Kachelbares, weiches Rauschen: weisses Rauschen, im Frequenzraum
    mit einer Gauss-Glocke gefiltert (zirkular -> nahtlos), auf 0..1."""
    rausch = RNG.standard_normal((N, N))
    fx = np.fft.fftfreq(N)[:, None]
    fy = np.fft.fftfreq(N)[None, :]
    glocke = np.exp(-((fx ** 2 + fy ** 2) * (sigma_px ** 2) * 19.7))
    glatt = np.real(np.fft.ifft2(np.fft.fft2(rausch) * glocke))
    glatt -= glatt.min()
    return glatt / max(glatt.max(), 1e-9)


def main() -> None:
    ziel = "assets/texturen/rasen"
    os.makedirs(ziel, exist_ok=True)

    flecken = _tief(48.0)
    halme = _tief(2.2)
    # Gerichtete zweite Halmschicht: gestauchtes Rauschen wirkt gemaeht.
    halme2 = np.roll(_tief(1.6), N // 3, axis=1)
    erde = _tief(90.0)

    # Albedo: zwischen sattem und ausgeblichenem Gruen, Halme hellen
    # punktuell auf, duenne Stellen kippen ins Erdige.
    gruen_a = np.array([0.22, 0.34, 0.12])
    gruen_b = np.array([0.38, 0.46, 0.20])
    erdig = np.array([0.36, 0.30, 0.18])
    basis = gruen_a[None, None] + (gruen_b - gruen_a)[None, None] * flecken[..., None]
    basis += (halme[..., None] - 0.5) * 0.16 + (halme2[..., None] - 0.5) * 0.10
    # Gepflegter Fest-Rasen: nur ein Hauch erdiger Stellen, sonst wirkt
    # die Flaeche wie Tarnmuster.
    duenn = np.clip((erde - 0.88) * 4.0, 0.0, 0.45)
    basis = basis * (1.0 - duenn[..., None]) + erdig[None, None] * duenn[..., None]
    albedo = np.clip(basis, 0.0, 1.0)
    Image.fromarray((albedo * 255).astype(np.uint8)).save(
        os.path.join(ziel, "albedo.jpg"), quality=90)

    # Normal-Map aus der Halm-Hoehe (zentrale Differenzen, zirkular).
    hoehe = halme * 0.7 + halme2 * 0.3
    dx = (np.roll(hoehe, -1, axis=1) - np.roll(hoehe, 1, axis=1)) * 2.4
    dy = (np.roll(hoehe, -1, axis=0) - np.roll(hoehe, 1, axis=0)) * 2.4
    nz = np.ones_like(hoehe)
    laenge = np.sqrt(dx ** 2 + dy ** 2 + nz ** 2)
    normal = np.stack([(-dx / laenge + 1.0) / 2.0,
                       (dy / laenge + 1.0) / 2.0,
                       (nz / laenge + 1.0) / 2.0], axis=-1)
    Image.fromarray((normal * 255).astype(np.uint8)).save(
        os.path.join(ziel, "normal.jpg"), quality=92)

    # Rauheit: Gras ist matt; die erdigen Stellen einen Hauch glatter.
    rauheit = np.clip(0.90 - duenn * 0.12 + (halme - 0.5) * 0.06, 0.0, 1.0)
    Image.fromarray((rauheit * 255).astype(np.uint8)).save(
        os.path.join(ziel, "rauheit.jpg"), quality=88)
    print("rasen: albedo/normal/rauheit @ %d px" % N)


if __name__ == "__main__":
    main()
