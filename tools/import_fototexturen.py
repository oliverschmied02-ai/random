#!/usr/bin/env python3
"""Baut hochgeladene ambientCG-Sets (CC0) in die Materialplätze ein.

    python3 tools/import_fototexturen.py <ordner-mit-entpackten-sets>

Erwartet je Set einen Ordner mit den üblichen 1K-JPG-Dateien
(*_Color.jpg, *_NormalGL.jpg, *_Roughness.jpg, optional *_AmbientOcclusion.jpg)
oder das Leadwerks-DDS-Paket (Farbe, _norm, _orm). Schreibt nach
assets/texturen/<satz>/{albedo,normal,rauheit}.jpg — dieselben Plätze, die
tools/make_textures.py füllt; die .import-Einstellungen bleiben erhalten.

Zwei Veredelungen beim Kopieren:
* Ambient Occlusion wird zu 75 % in die Albedo eingerechnet (spart den
  vierten Texturkanal im Material).
* Der Asphalt bekommt die Pfützen zurück, die das Foto nicht hat: dunkle
  Flecken in der Albedo, spiegelglatte in der Rauheitskarte.
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

WURZEL = Path(__file__).resolve().parent.parent / "assets" / "texturen"
N = 1024


def _lies(pfad: Path) -> np.ndarray:
    return np.asarray(Image.open(pfad).convert("RGB"), dtype=np.float32) / 255.0


def _schreib(satz: str, name: str, feld: np.ndarray, qualitaet: int = 88) -> None:
    ordner = WURZEL / satz
    ordner.mkdir(parents=True, exist_ok=True)
    bild = np.clip(feld * 255.0, 0, 255).astype(np.uint8)
    Image.fromarray(bild).save(ordner / name, quality=qualitaet)


def _finde(ordner: Path, endung: str) -> Path | None:
    treffer = sorted(ordner.glob(f"*{endung}"))
    return treffer[0] if treffer else None


def _spektrum_rauschen(n, seed, beta, cmin=1, cmax=None):
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


def standard_set(ordner: Path, satz: str, pfuetzen: bool = False) -> None:
    """Ein normales ambientCG-1K-JPG-Set auf seinen Platz kopieren."""
    albedo = _lies(_finde(ordner, "_Color.jpg"))
    normal = _lies(_finde(ordner, "_NormalGL.jpg"))
    rauheit = _lies(_finde(ordner, "_Roughness.jpg"))[..., 0]
    ao_pfad = _finde(ordner, "_AmbientOcclusion.jpg")
    if ao_pfad is not None:
        ao = _lies(ao_pfad)[..., 0]
        albedo = albedo * (0.25 + 0.75 * ao[..., None])

    if pfuetzen:
        maske = _spektrum_rauschen(N, 90, 2.6, 1, 4)
        # dieselbe Formensprache wie im gebackenen Satz: wenige große Flecken
        maske = np.clip((maske - 0.66) * 6.0, 0, 1)
        if maske.shape != albedo.shape[:2]:
            maske = np.asarray(Image.fromarray(
                (maske * 255).astype(np.uint8)).resize(albedo.shape[1::-1])) / 255.0
        albedo = albedo * (1 - 0.5 * maske[..., None])
        rauheit = rauheit * (1 - maske) + 0.06 * maske
        flach = np.array([0.5, 0.5, 1.0])
        normal = normal * (1 - maske[..., None]) + flach * maske[..., None]

    _schreib(satz, "albedo.jpg", albedo)
    _schreib(satz, "normal.jpg", normal, 92)
    _schreib(satz, "rauheit.jpg", np.repeat(rauheit[..., None], 3, axis=2))
    print(f"  {satz}: aus {ordner.name}  (albedo-mittel {albedo.mean():.3f})")


def leadwerks_set(ordner: Path, satz: str) -> None:
    """Leadwerks-DDS-Paket: Farbe + zweikanalige Normal + ORM."""
    farbe = _finde(ordner, ".dds")
    albedo = _lies(min(ordner.glob("*.dds"), key=lambda p: len(p.name)))
    norm2 = _lies(_finde(ordner, "_norm.dds"))
    orm = _lies(_finde(ordner, "_orm.dds"))

    # Z aus den zwei Kanälen zurückrechnen.
    nx = norm2[..., 0] * 2.0 - 1.0
    ny = norm2[..., 1] * 2.0 - 1.0
    nz = np.sqrt(np.clip(1.0 - nx * nx - ny * ny, 0.0, 1.0))
    normal = np.stack([nx, ny, nz], axis=-1) * 0.5 + 0.5

    ao = orm[..., 0]
    rauheit = orm[..., 1]
    albedo = albedo * (0.25 + 0.75 * ao[..., None])

    _schreib(satz, "albedo.jpg", albedo)
    _schreib(satz, "normal.jpg", normal, 92)
    _schreib(satz, "rauheit.jpg", np.repeat(rauheit[..., None], 3, axis=2))
    print(f"  {satz}: aus {ordner.name} (DDS)  (albedo-mittel {albedo.mean():.3f})")


if __name__ == "__main__":
    quelle = Path(sys.argv[1])
    zuordnung = {
        "Plaster001": ("putz", "dds"),
        "Asphalt025B": ("asphalt", "pfuetzen"),
        "Concrete020": ("beton_rau", ""),
        "Gravel022": ("schotter", ""),
        "Bricks054": ("klinker", ""),
    }
    for ordner in sorted(quelle.iterdir()):
        if not ordner.is_dir():
            continue
        for kennung, (satz, art) in zuordnung.items():
            if kennung not in ordner.name:
                continue
            if art == "dds":
                leadwerks_set(ordner, satz)
            else:
                standard_set(ordner, satz, pfuetzen=(art == "pfuetzen"))
    # Der Gehweg nutzt denselben Beton, nur heller getönt — eigener Platz,
    # damit später ein PavingStones-Set einfach darüberkopiert werden kann.
    import shutil
    for name in ["albedo.jpg", "normal.jpg", "rauheit.jpg"]:
        shutil.copyfile(WURZEL / "beton_rau" / name, WURZEL / "beton_platten" / name)
    print("  beton_platten: Kopie von beton_rau (bis ein PavingStones-Set kommt)")
    print("fertig")
