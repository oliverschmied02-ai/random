#!/usr/bin/env python3
"""Malt die Platzhalter-Profilbilder der Tinder-Intro.

    python3 tools/make_tinder_fotos.py            # Scherz-Profile + Bokeh
    python3 tools/make_tinder_fotos.py veredeln   # Olivers Rohrender verarbeiten

Die drei Scherz-Profile sind bewusst stilisierte Silhouetten-Porträts
(Farbverlauf, dunkle Büste, ein Klischee-Requisit pro Kandidat) — genug,
um die Witze zu tragen, ohne echte Gesichter vorzutäuschen:

* Kevin, 29  — hält stolz einen Fisch (der Klassiker)
* Marcel, 31 — Sonnenbrille, Foto im Auto
* Justin, 26 — Spiegel-Selfie im Fitnessstudio, Hantel und Handy vorm Gesicht

`veredeln` nimmt die Xvfb-Renderbilder aus tools/_foto_oliver.gd
(user://shots/oliver_roh_*.png) und macht daraus die drei absichtlich
unterschiedlich aussehenden Profilfotos: eines ordentlich, eines dunkel und
verwackelt, eines schief mit hartem Blitz. Dazu Annes Match-Avatar.
"""

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps

ZIEL = Path(__file__).resolve().parent.parent / "assets" / "intro"
ROH = Path.home() / ".local/share/godot/app_userdata/Our Story/shots"
GROESSE = (640, 800)  # 4:5 wie eine Profilkarte


def _verlauf(oben, unten, groesse=GROESSE):
    """Vertikaler Farbverlauf als Grundfläche."""
    hoehe = groesse[1]
    t = np.linspace(0.0, 1.0, hoehe)[:, None, None]
    farbe = (1 - t) * np.array(oben)[None, None, :] + t * np.array(unten)[None, None, :]
    bild = np.repeat(farbe, groesse[0], axis=1)
    return Image.fromarray(bild.astype(np.uint8), "RGB")


def _bueste(zeichner, mitte_x, kopf_y, ton, kopf_r=95):
    """Kopf und Schultern als weiche Silhouette."""
    zeichner.ellipse([mitte_x - kopf_r, kopf_y - kopf_r,
                      mitte_x + kopf_r, kopf_y + kopf_r], fill=ton)
    zeichner.ellipse([mitte_x - 190, kopf_y + kopf_r - 14,
                      mitte_x + 190, kopf_y + kopf_r + 260], fill=ton)


def _koernung(bild, staerke=8.0):
    rng = np.random.default_rng(2020)
    feld = np.asarray(bild, dtype=np.float32)
    feld = feld + rng.normal(0.0, staerke, feld.shape)
    return Image.fromarray(np.clip(feld, 0, 255).astype(np.uint8), bild.mode)


def kevin():
    """Angler-Klassiker: stolz, Fisch quer vorm Bauch, Käppi."""
    bild = _verlauf((96, 148, 176), (58, 92, 108))
    z = ImageDraw.Draw(bild)
    ton = (38, 44, 52)
    _bueste(z, 320, 300, ton)
    # Käppi mit Schirm.
    z.pieslice([225, 175, 415, 330], 180, 360, fill=(140, 60, 48))
    z.rectangle([225, 248, 460, 276], fill=(140, 60, 48))
    # Der Fisch: Rumpf, Schwanzflosse, Auge, glänzender Rücken.
    z.ellipse([120, 520, 480, 660], fill=(122, 138, 128))
    z.polygon([(470, 590), (560, 528), (560, 652)], fill=(122, 138, 128))
    z.ellipse([150, 545, 260, 640], fill=(134, 152, 140))
    z.ellipse([196, 564, 222, 590], fill=(20, 24, 26))
    z.arc([140, 512, 470, 600], 200, 330, fill=(190, 205, 195), width=6)
    # Zwei Silhouetten-Arme halten ihn — außen, damit das Auge frei bleibt.
    z.ellipse([84, 470, 152, 626], fill=ton)
    z.ellipse([448, 470, 516, 626], fill=ton)
    return _koernung(bild)


def marcel():
    """Auto-Selfie: Sonnenbrille, Kopfstütze, Gurt."""
    bild = _verlauf((96, 90, 100), (48, 45, 56))
    z = ImageDraw.Draw(bild)
    # Seitenfenster mit vorbeiziehendem Licht.
    z.rectangle([340, 60, 640, 420], fill=(120, 130, 150))
    z.polygon([(360, 60), (520, 60), (420, 420), (300, 420)], fill=(150, 162, 184))
    ton = (92, 74, 66)
    # Kopfstütze hinter dem Kopf.
    z.rounded_rectangle([220, 130, 440, 330], 60, fill=(36, 34, 40))
    _bueste(z, 320, 320, ton)
    # Schwarze Jacke über den Schultern, nur der Kopf bleibt Haut.
    z.ellipse([130, 401, 510, 675], fill=(30, 28, 34))
    # Kurzer dunkler Schopf statt Vollhelm.
    z.pieslice([232, 208, 408, 350], 180, 360, fill=(40, 32, 28))
    # Sonnenbrille: zwei Gläser, Steg.
    z.rounded_rectangle([238, 288, 316, 342], 16, fill=(12, 12, 14))
    z.rounded_rectangle([328, 288, 406, 342], 16, fill=(12, 12, 14))
    z.rectangle([312, 306, 332, 318], fill=(12, 12, 14))
    z.line([(238, 300), (222, 292)], fill=(12, 12, 14), width=8)
    z.line([(406, 300), (422, 292)], fill=(12, 12, 14), width=8)
    # Gurt quer über die Brust.
    z.line([(180, 470), (430, 740)], fill=(20, 20, 24), width=42)
    return _koernung(bild)


def justin():
    """Spiegel-Selfie im Studio: Handy vorm Gesicht, Hantel im Bild."""
    bild = _verlauf((132, 128, 122), (86, 84, 82))
    z = ImageDraw.Draw(bild)
    # Spiegelkante und Studioboden.
    z.rectangle([48, 0, 60, 800], fill=(160, 158, 152))
    z.rectangle([0, 640, 640, 800], fill=(72, 74, 70))
    ton = (52, 46, 44)
    _bueste(z, 330, 310, ton)
    # Tanktop hell abgesetzt.
    z.polygon([(210, 470), (450, 470), (470, 800), (190, 800)], fill=(200, 196, 188))
    z.ellipse([250, 380, 410, 500], fill=ton)
    # Arm hält das Handy vors Gesicht — der Klassiker.
    z.ellipse([352, 330, 470, 430], fill=ton)
    z.rounded_rectangle([368, 228, 462, 398], 22, fill=(16, 16, 18))
    z.ellipse([404, 250, 428, 274], fill=(60, 62, 70))  # Blitzfleck
    # Hantelbank-Andeutung am Rand.
    z.rectangle([520, 560, 640, 590], fill=(40, 42, 44))
    z.ellipse([500, 520, 560, 630], fill=(30, 32, 34))
    return _koernung(bild)


def bokeh():
    """Weicher Lichtfleck fürs Hintergrund-Bokeh der 3D-Szene."""
    seite = 256
    y, x = np.mgrid[0:seite, 0:seite].astype(np.float32)
    abstand = np.sqrt((x - seite / 2) ** 2 + (y - seite / 2) ** 2) / (seite / 2)
    hell = np.clip(1.0 - abstand, 0.0, 1.0) ** 1.6
    # Randring, wie ihn unscharfe Blenden zeichnen.
    hell = hell * 0.82 + np.clip(1.0 - np.abs(abstand - 0.82) * 9.0, 0.0, 1.0) * 0.18
    feld = np.zeros((seite, seite, 4), dtype=np.uint8)
    feld[..., 0:3] = 255
    feld[..., 3] = (np.clip(hell, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(feld, "RGBA").save(ZIEL / "bokeh.png")
    print("  intro/bokeh.png")


def veredeln():
    """Aus den Xvfb-Rohbildern die drei Oliver-Fotos + Annes Avatar bauen."""
    laden = lambda name: Image.open(ROH / f"{name}.png").convert("RGB")

    # Foto 1 — das ordentliche: warm, leicht beschnitten, feines Korn.
    foto = laden("oliver_roh_1")
    foto = ImageOps.fit(foto, GROESSE, centering=(0.5, 0.42))
    foto = ImageEnhance.Color(foto).enhance(1.12)
    foto = ImageEnhance.Brightness(foto).enhance(1.06)
    _koernung(foto, 4.0).save(ZIEL / "oliver_foto_1.png")

    # Foto 2 — der Party-Schnappschuss: dunkel, verwackelt, kühl.
    foto = laden("oliver_roh_2")
    foto = ImageOps.fit(foto, GROESSE, centering=(0.42, 0.35))
    klein = foto.resize((GROESSE[0] // 5, GROESSE[1] // 5), Image.BILINEAR)
    foto = klein.resize(GROESSE, Image.BILINEAR).filter(ImageFilter.GaussianBlur(2.2))
    foto = ImageEnhance.Brightness(foto).enhance(0.82)
    feld = np.asarray(foto, dtype=np.float32)
    feld[..., 2] = np.clip(feld[..., 2] * 1.18 + 10, 0, 255)  # Blaustich
    _koernung(Image.fromarray(feld.astype(np.uint8), "RGB"), 14.0)\
        .save(ZIEL / "oliver_foto_2.png")

    # Foto 3 — der harte Blitz: schief, überbelichtet, entsättigt, Vignette.
    foto = laden("oliver_roh_3")
    foto = foto.rotate(-7, resample=Image.BILINEAR, expand=False)
    foto = ImageOps.fit(foto, GROESSE, centering=(0.56, 0.30))
    foto = ImageEnhance.Brightness(foto).enhance(1.28)
    foto = ImageEnhance.Color(foto).enhance(0.55)
    foto = ImageEnhance.Contrast(foto).enhance(1.25)
    y, x = np.mgrid[0:GROESSE[1], 0:GROESSE[0]].astype(np.float32)
    rand = np.sqrt(((x - GROESSE[0] / 2) / GROESSE[0]) ** 2 +
                   ((y - GROESSE[1] / 2) / GROESSE[1]) ** 2)
    vignette = np.clip(1.15 - rand * 1.1, 0.35, 1.0)[..., None]
    feld = np.asarray(foto, dtype=np.float32) * vignette
    _koernung(Image.fromarray(np.clip(feld, 0, 255).astype(np.uint8), "RGB"), 9.0)\
        .save(ZIEL / "oliver_foto_3.png")

    # Annes Match-Avatar: rund zugeschnitten wird er erst in der Oberfläche,
    # hier nur ein freundlich gestimmtes Quadrat.
    foto = laden("anne_roh")
    foto = ImageOps.fit(foto, (512, 512), centering=(0.5, 0.40))
    foto = ImageEnhance.Color(foto).enhance(1.08)
    _koernung(foto, 4.0).save(ZIEL / "anne_match.png")
    print("  intro/oliver_foto_1..3.png, intro/anne_match.png")


if __name__ == "__main__":
    ZIEL.mkdir(parents=True, exist_ok=True)
    if len(sys.argv) > 1 and sys.argv[1] == "veredeln":
        veredeln()
    else:
        kevin().save(ZIEL / "profil_kevin.png")
        marcel().save(ZIEL / "profil_marcel.png")
        justin().save(ZIEL / "profil_justin.png")
        bokeh()
        print("  intro/profil_kevin.png, profil_marcel.png, profil_justin.png")
    print("fertig")
