#!/usr/bin/env python3
"""Baut die FFP2-Maske für das Minispiel — als Faltmaske in Fischform.

    python3 tools/make_maske.py

Die erste Fassung war ein Körbchen nach Produktfoto (Ellipsoid mit
frontprojizierter Textur) — aus der Distanz las sich das als Ei. Die in
Deutschland allgegenwärtige FFP2 ist aber die **gefaltete Fischform**:
zwei weiße Vlies-Paneele, die an einer horizontalen Mittelnaht mit
Knick aufeinandertreffen, zu den Seiten hin flach zusammenlaufen, oben
ein Nasenbügel, seitlich zwei Ohrschlaufen, auf dem Oberpaneel der
Aufdruck „FFP2 NR · CE 2163". Genau diese Silhouette macht die Maske
auf einen Blick erkennbar — also wird sie hier parametrisch aufgebaut:

* Oberes und unteres Paneel als getrennte Gitter (getrennte Ecken an
  der Naht, damit der Faltknick hart bleibt statt weichgeschattet),
* Tiefe und Höhe laufen zu den Seiten mit `s(u)` aus — der Fisch-Umriss,
* Solidify gibt dem Vlies sichtbare Materialstärke an den Rändern,
* Nasenbügel als geneigter Steg, Ohrschlaufen als flache Tori,
* Textur: Vliesfasern, geprägte Schweißpunkt-Reihen an Naht und
  Rändern, blauer Aufdruck auf dem Oberpaneel.

Achsen wie bei allen Requisiten: Z hoch, -Y ist vorn.
"""

import math
from pathlib import Path

import bpy
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ZIEL = Path(__file__).resolve().parent.parent / "assets" / "props"
TEXTUR = ZIEL / "atemmaske_vlies.png"

BREITE = 0.160   # aufgefaltete Maske: Spannweite
HOEHE = 0.110    # Höhe an der Mitte (beide Paneele zusammen)
TIEFE = 0.048    # wie weit die Naht nach vorn steht
BLAU = (64, 78, 148)

SEITE = 768      # Texturkantenlänge


def _linear(kanal: float) -> float:
    if kanal <= 0.04045:
        return kanal / 12.92
    return ((kanal + 0.055) / 1.055) ** 2.4


def _material(name, farbe, rauheit=0.9, metall=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = tuple(
        _linear(k) for k in farbe) + (1.0,)
    bsdf.inputs["Roughness"].default_value = rauheit
    bsdf.inputs["Metallic"].default_value = metall
    return mat


# --- Die Form ------------------------------------------------------------
# u läuft von -1 (links) bis 1 (rechts), v von 0 (Naht) bis 1 (Randkante).


def _seit(u: float) -> float:
    """Seitliches Auslaufen: 1 in der Mitte, 0 am Ohrende — der Umriss."""
    return math.cos(u * math.pi / 2.0) ** 0.5


def _punkt(u: float, v: float, oben: bool):
    """Ein Punkt auf dem Ober- (oben=True) oder Unterpaneel."""
    s = _seit(u)
    hoehe = (HOEHE / 2.0) * (0.32 + 0.68 * s)
    # Zu den Ohren hin läuft die Faltung fast flach zusammen — genau
    # dieses Zusammenkneifen macht die Fischform kenntlich.
    tiefe = TIEFE * (0.04 + 0.96 * s ** 1.4)
    x = u * BREITE / 2.0
    z = (v if oben else -v) * hoehe
    # Gerade Paneele: der lineare Verlauf lässt sie an der Naht in
    # einem sichtbaren Winkel aufeinandertreffen — DER Faltknick der
    # Fischform. (Ein Exponent über 1 hätte hier die Steigung an der Naht
    # auf null gezogen und den Knick weggebügelt.)
    y = -tiefe * (1.0 - v)
    # Die Randkante kippt leicht zurück Richtung Gesicht.
    y += 0.010 * (v ** 3) * s
    return (x, y, z)


def _paneel(name: str, oben: bool, mat) -> bpy.types.Object:
    nu, nv = 48, 14
    ecken, flaechen = [], []
    for j in range(nv + 1):
        for i in range(nu + 1):
            ecken.append(_punkt(-1.0 + 2.0 * i / nu, j / nv, oben))
    for j in range(nv):
        for i in range(nu):
            a = j * (nu + 1) + i
            b = a + 1
            c = a + nu + 2
            d = a + nu + 1
            flaechen.append((a, b, c, d) if oben else (a, d, c, b))
    netz = bpy.data.meshes.new(name)
    netz.from_pydata(ecken, [], flaechen)
    netz.update()
    obj = bpy.data.objects.new(name, netz)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.shade_smooth()
    _front_uvs(obj)
    obj.data.materials.append(mat)
    # Materialstärke: macht die Vlieskante an Rändern und Naht sichtbar.
    stark = obj.modifiers.new("stark", "SOLIDIFY")
    stark.thickness = 0.0016
    stark.offset = 0.0
    bpy.ops.object.modifier_apply(modifier="stark")
    obj.select_set(False)
    return obj


def _front_uvs(obj):
    """Frontprojektion: X/Z der Ecken direkt als UV — die Textur liegt wie
    aufprojiziert auf der Faltung."""
    netz = obj.data
    ebene = netz.uv_layers.new(name="UVMap") if not netz.uv_layers else netz.uv_layers[0]
    for poly in netz.polygons:
        for schleife in poly.loop_indices:
            co = netz.vertices[netz.loops[schleife].vertex_index].co
            ebene.data[schleife].uv = (co.x / BREITE + 0.5, co.z / HOEHE + 0.5)


# --- Die Textur ----------------------------------------------------------


def _pix(x: float, z: float):
    """Weltkoordinate (x, z) → Texturpixel der Frontprojektion."""
    return ((x / BREITE + 0.5) * SEITE, (0.5 - z / HOEHE) * SEITE)


def _punktreihe(zeichner, hoehe_von_u, versatz: float, ton, schritt=15):
    """Eine Reihe geprägter Schweißpunkte, die dem Umriss folgt.
    `hoehe_von_u` liefert die Z-Höhe der Linie für ein u in [-1, 1]."""
    for xs in range(20, SEITE - 20, schritt):
        u = (xs / SEITE - 0.5) * 2.0
        z = hoehe_von_u(u) + versatz
        _, ys = _pix(0.0, z)
        # Delle mit heller Oberkante — so liest sich der Punkt als Prägung.
        zeichner.ellipse([xs - 5, ys - 5, xs + 5, ys + 5], fill=ton)
        zeichner.ellipse([xs - 4, ys - 6, xs + 4, ys - 2],
                         fill=(249, 249, 251))


def vlies_textur():
    rng = np.random.default_rng(2021)
    feld = np.full((SEITE, SEITE), 233.0)
    feld += rng.normal(0.0, 2.2, (SEITE, SEITE))

    # Vliesfasern: kurze helle und dunkle Schlieren in Zufallsrichtung.
    yy, xx = np.mgrid[0:SEITE, 0:SEITE].astype(np.float32)
    for winkel, staerke in ((0.3, 3.6), (1.25, 2.8), (2.1, 2.2)):
        laeufer = xx * math.cos(winkel) + yy * math.sin(winkel)
        feld += np.sin(laeufer * 0.9 + rng.uniform(0, 6)) * staerke

    # Paneel-Schattierung: zur Naht hin einen Hauch heller (steht vor),
    # zu den Seiten hin dunkler (läuft flach aus).
    mitte_z = np.abs(yy / SEITE - 0.5)
    feld -= mitte_z * 26.0
    seite_x = np.abs(xx / SEITE - 0.5) * 2.0
    feld -= np.clip(seite_x - 0.72, 0.0, 1.0) * 55.0

    bild = Image.fromarray(np.clip(feld, 0, 255).astype(np.uint8), "L").convert("RGB")
    zeichner = ImageDraw.Draw(bild)

    def rand_oben(u):
        return (HOEHE / 2.0) * (0.24 + 0.76 * _seit(u))

    grau = (186, 187, 194)
    # Naht: Doppelreihe Schweißpunkte knapp über und unter der Mitte,
    # dazwischen eine deutliche Schattenlinie — der Faltknick.
    zeichner.line([0, SEITE // 2, SEITE, SEITE // 2], fill=(188, 189, 196), width=5)
    zeichner.line([0, SEITE // 2 - 3, SEITE, SEITE // 2 - 3],
                  fill=(246, 246, 249), width=2)
    _punktreihe(zeichner, lambda u: 0.0, 0.0050, grau)
    _punktreihe(zeichner, lambda u: 0.0, -0.0050, grau)
    # Randkanten oben und unten: je eine Punktreihe, dem Umriss folgend.
    _punktreihe(zeichner, rand_oben, -0.0062, grau)
    _punktreihe(zeichner, lambda u: -rand_oben(u), 0.0062, grau)

    # Aufdruck auf dem Oberpaneel, links der Mitte — klein rendern und
    # hochskalieren, das wirkt wie gestempelt. Groß genug, dass „FFP2"
    # auch aus Spieldistanz lesbar bleibt.
    stempel = Image.new("RGBA", (66, 30), (0, 0, 0, 0))
    tinte = ImageDraw.Draw(stempel)
    tinte.text((2, 1), "FFP2 NR", fill=BLAU + (255,))
    tinte.text((2, 13), "CE 2163", fill=BLAU + (230,))
    stempel = stempel.resize((290, 132), Image.LANCZOS)
    xs, ys = _pix(-0.026, 0.027)
    bild.paste(stempel, (int(xs) - 145, int(ys) - 66), stempel)

    bild = bild.filter(ImageFilter.GaussianBlur(0.4))
    ZIEL.mkdir(parents=True, exist_ok=True)
    bild.save(TEXTUR)
    print("  props/atemmaske_vlies.png")


# --- Der Aufbau ----------------------------------------------------------


def bauen():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    vlies_textur()

    vlies = _material("vlies", (1.0, 1.0, 1.0), rauheit=0.92)
    knoten = vlies.node_tree.nodes
    bild_knoten = knoten.new("ShaderNodeTexImage")
    bild_knoten.image = bpy.data.images.load(str(TEXTUR))
    vlies.node_tree.links.new(
        bild_knoten.outputs["Color"],
        knoten["Principled BSDF"].inputs["Base Color"])

    teile = [
        _paneel("paneel_oben", True, vlies),
        _paneel("paneel_unten", False, vlies),
    ]

    # --- Nasenbügel: mattes Metallband, dem Oberrand folgend ---------------
    buegel_mat = _material("buegel", (0.62, 0.63, 0.66), rauheit=0.5, metall=0.6)
    ort = _punkt(0.0, 0.86, True)
    bpy.ops.mesh.primitive_cube_add(size=1.0,
                                    location=(0.0, ort[1] - 0.0015, ort[2]))
    buegel = bpy.context.active_object
    buegel.name = "nasenbuegel"
    buegel.scale = (0.021, 0.0018, 0.0042)
    # Das Oberpaneel lehnt nach hinten — der Bügel lehnt mit.
    buegel.rotation_euler = (math.radians(-38.0), 0.0, 0.0)
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
    bpy.ops.object.shade_smooth()
    buegel.data.materials.append(buegel_mat)
    teile.append(buegel)

    # --- Ohrschlaufen: flache weiße Gummiringe an den Enden ----------------
    schlaufe_mat = _material("schlaufe", (0.92, 0.92, 0.93), rauheit=0.75)
    for seite in (-1.0, 1.0):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.030, minor_radius=0.0021,
            location=(seite * (BREITE / 2.0 - 0.004), 0.026, 0.0),
            rotation=(0.0, math.radians(90.0), 0.0),
            major_segments=36, minor_segments=8)
        ring = bpy.context.active_object
        ring.name = "schlaufe"
        ring.scale = (1.0, 1.15, 0.72)
        bpy.ops.object.transform_apply(scale=True, location=False)
        bpy.ops.object.shade_smooth()
        ring.data.materials.append(schlaufe_mat)
        teile.append(ring)

    bpy.ops.object.select_all(action="DESELECT")
    for teil in teile:
        teil.select_set(True)
    bpy.context.view_layer.objects.active = teile[0]
    bpy.ops.object.join()
    maske = bpy.context.active_object
    maske.name = "atemmaske"

    bpy.ops.export_scene.gltf(filepath=str(ZIEL / "atemmaske.glb"),
                              export_apply=True, export_yup=True,
                              use_selection=True)
    print("  props/atemmaske.glb (FFP2, Fischform)")


if __name__ == "__main__":
    bauen()
    print("fertig")
