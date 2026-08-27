#!/usr/bin/env python3
"""Malt Olivers Outfit-Textur zur Wachsjacke um — nur den Jackenteil.

    python3 tools/make_barbour.py

Oliver trägt im Modell ein dunkles Sakko. Für Kapitel 1 (Spaziergang
im Herbst 2020) wünscht sich Oliver seine Barbour: dunkles Wachs-Oliv,
Cordkragen. Ein neues Kleidungs-Mesh auf einem geriggten Modell wäre
ein Großprojekt — die Textur umzumalen nicht. Nur: auf dem Atlas ist
alles fast schwarz, Sakko, Hose und Schuhe sind mit dem Auge nicht zu
trennen.

Deshalb läuft die Trennung über die Geometrie: das Outfit-Mesh steht
in T-Pose, also verrät die **Körperhöhe** jedes Dreiecks, zu welchem
Kleidungsstück es gehört (Oberkörper und Arme = Jacke, darunter Hose,
ganz unten Schuhe). Die Jacken-Dreiecke werden in den UV-Raum
rasterisiert — das ergibt die Maske, in der umgemalt wird:

* dunkle Jackenpixel → Wachs-Oliv, Helligkeitsverlauf bleibt erhalten,
* der Kragenbereich (oberste Zentimeter) → Cord-Braun mit feinen Rippen,
* Hemd (weiße Pixel), Hose und Schuhe bleiben unangetastet.

Ergebnis: assets/kleidung/oliver_barbour.png. Das Kapitel hängt sie zur
Laufzeit als Material-Override an die outfit-Fläche — nur in Berlin,
die anderen Kapitel behalten das Original.
"""

import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

WURZEL = Path(__file__).resolve().parent.parent
ZIEL = WURZEL / "assets" / "kleidung"

## Höhengrenzen in Metern (Modell steht in T-Pose, Ursprung an den Sohlen).
JACKE_AB = 0.94      # darüber: Jacke (Rumpf und Arme)
KRAGEN_AB = 1.475    # oberste Jackenkante: Cordkragen

OLIV = np.array([60.0, 56.0, 42.0])     # Wachs-Oliv, Mittelton
CORD = np.array([74.0, 52.0, 38.0])     # Cordkragen-Braun


def _accessor(j, daten, index):
    acc = j["accessors"][index]
    view = j["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    typen = {"VEC3": 3, "VEC2": 2, "SCALAR": 1}
    breite = typen[acc["type"]]
    formate = {5126: ("f", 4), 5125: ("I", 4), 5123: ("H", 2)}
    fmt, gr = formate[acc["componentType"]]
    zahl = acc["count"] * breite
    werte = struct.unpack_from("<%d%s" % (zahl, fmt), daten, start)
    return np.array(werte, dtype=np.float64).reshape(acc["count"], breite)


def bauen() -> None:
    roh = (WURZEL / "actors" / "models" / "oliver.glb").read_bytes()
    ln = struct.unpack("<I", roh[12:16])[0]
    j = json.loads(roh[20:20 + ln])
    binstart = 20 + ln + 8
    daten = roh[binstart:]

    # Die outfit-Fläche finden.
    prim = None
    for m in j["meshes"]:
        for p in m["primitives"]:
            if j["materials"][p["material"]].get("name") == "outfit":
                prim = p
    assert prim is not None, "outfit-Fläche nicht gefunden"

    orte = _accessor(j, daten, prim["attributes"]["POSITION"])
    uvs = _accessor(j, daten, prim["attributes"]["TEXCOORD_0"])
    kanten = _accessor(j, daten, prim["indices"]).astype(int).reshape(-1, 3)

    # Textur laden (Bild 0 laut Materialzuordnung).
    img = j["images"][j["textures"][
        j["materials"][prim["material"]]["pbrMetallicRoughness"]
        ["baseColorTexture"]["index"]]["source"]]
    view = j["bufferViews"][img["bufferView"]]
    start = view.get("byteOffset", 0)
    import io
    textur = Image.open(io.BytesIO(daten[start:start + view["byteLength"]]))
    textur = textur.convert("RGB")
    seite = textur.width

    # Jacken- und Kragenmaske im UV-Raum rasterisieren. glTF-UVs haben
    # den Ursprung oben links — wie PIL, kein Umklappen nötig.
    jacke = Image.new("L", (seite, seite), 0)
    kragen = Image.new("L", (seite, seite), 0)
    zj, zk = ImageDraw.Draw(jacke), ImageDraw.Draw(kragen)
    for a, b, c in kanten:
        hoehe = (orte[a][1] + orte[b][1] + orte[c][1]) / 3.0
        if hoehe < JACKE_AB:
            continue
        punkte = [tuple(uvs[i] * seite) for i in (a, b, c)]
        zj.polygon(punkte, fill=255)
        # Kragen: hoch UND nah an der Halsachse — die Arme liegen in
        # T-Pose auf derselben Höhe und wären sonst mit Cord bezogen.
        radius = sum(
            (orte[i][0] ** 2 + orte[i][2] ** 2) ** 0.5 for i in (a, b, c)) / 3.0
        if hoehe >= KRAGEN_AB and radius < 0.125:
            zk.polygon(punkte, fill=255)

    bild = np.asarray(textur).astype(np.float64)
    m_jacke = np.asarray(jacke) > 0
    m_kragen = np.asarray(kragen) > 0
    hell = bild.mean(axis=2)

    # Nur dunkle Jackenpixel ummalen — das weiße Hemd im selben
    # Höhenbereich bleibt weiß.
    ziel = m_jacke & (hell < 90.0)
    faktor = np.clip(hell / 19.0, 0.55, 1.9)
    rng = np.random.default_rng(1966)
    wachs = 1.0 + rng.normal(0.0, 0.035, hell.shape)  # stumpfer Wachsglanz
    for k in range(3):
        bild[..., k] = np.where(ziel, OLIV[k] * faktor * wachs, bild[..., k])

    # Cordkragen: Braun mit feinen senkrechten Rippen.
    yy, xx = np.mgrid[0:seite, 0:seite]
    rippen = 1.0 + 0.16 * np.sin(xx * 1.15)
    ziel_k = m_kragen & (hell < 90.0)
    for k in range(3):
        bild[..., k] = np.where(ziel_k, CORD[k] * faktor * rippen, bild[..., k])

    ZIEL.mkdir(parents=True, exist_ok=True)
    aus = ZIEL / "oliver_barbour.png"
    Image.fromarray(np.clip(bild, 0, 255).astype(np.uint8)).save(aus)
    print("  %s (%d Dreiecke Jacke)" % (aus, int(m_jacke.sum() > 0)))


if __name__ == "__main__":
    bauen()
    print("fertig")
