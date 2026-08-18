#!/usr/bin/env python3
"""Backt Graffiti-Tags für die Erdgeschosse: Sprühzüge als Zufallskurven.

    python3 tools/make_graffiti.py

Drei Varianten nach assets/texturen/graffiti/{a,b,c}.png (RGBA, 512×256).
Kein Text, keine Wörter — nur die Geste: geschwungene Züge mit dickem
Kern und weichem Sprühnebel, wie man sie aus jeder Berliner Seitenstraße
mit zusammengekniffenen Augen kennt.
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

WURZEL = Path(__file__).resolve().parent.parent / "assets" / "texturen" / "graffiti"
B, H = 512, 256

FARBEN = {
    "a": [(212, 48, 66), (230, 226, 218)],
    "b": [(58, 112, 200), (228, 224, 214)],
    "c": [(226, 222, 212), (40, 40, 46)],
}


def _zug(zeichnung: ImageDraw.ImageDraw, rng: np.random.Generator,
         farbe: tuple, dicke: int) -> None:
    """Ein Sprühzug: kubische Zufallskurve aus vielen kurzen Segmenten."""
    punkte = rng.random((4, 2)) * [B * 0.8, H * 0.75] + [B * 0.1, H * 0.12]
    letzte = None
    for t in np.linspace(0, 1, 60):
        s = 1 - t
        p = (s ** 3 * punkte[0] + 3 * s * s * t * punkte[1]
             + 3 * s * t * t * punkte[2] + t ** 3 * punkte[3])
        if letzte is not None:
            zeichnung.line([tuple(letzte), tuple(p)], fill=farbe, width=dicke)
            zeichnung.ellipse([p[0] - dicke / 2, p[1] - dicke / 2,
                               p[0] + dicke / 2, p[1] + dicke / 2], fill=farbe)
        letzte = p


def backen(name: str, seed: int) -> None:
    rng = np.random.default_rng(seed)
    bild = Image.new("RGBA", (B, H), (0, 0, 0, 0))
    zeichnung = ImageDraw.Draw(bild)
    haupt, akzent = FARBEN[name]
    for i in range(rng.integers(3, 5)):
        _zug(zeichnung, rng, haupt + (255,), int(rng.integers(10, 18)))
    _zug(zeichnung, rng, akzent + (230,), 5)
    # Sprühnebel: weichgezeichnete Kopie unter das scharfe Original legen.
    nebel = bild.filter(ImageFilter.GaussianBlur(7))
    nebel = Image.eval(nebel, lambda v: v)
    a = np.asarray(nebel).astype(np.float32)
    a[..., 3] *= 0.45
    nebel = Image.fromarray(a.astype(np.uint8))
    fertig = Image.alpha_composite(nebel, bild)
    # Insgesamt halbtransparent — alte, verwitterte Farbe.
    a = np.asarray(fertig).astype(np.float32)
    a[..., 3] *= 0.82
    fertig = Image.fromarray(a.astype(np.uint8))
    WURZEL.mkdir(parents=True, exist_ok=True)
    fertig.save(WURZEL / f"{name}.png")
    print(f"  graffiti/{name}.png")


if __name__ == "__main__":
    for name, seed in [("a", 5), ("b", 17), ("c", 29)]:
        backen(name, seed)
    print("fertig")
