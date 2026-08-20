#!/usr/bin/env python3
"""Baut die FFP2-Maske für das Minispiel — nach Foto-Vorlage.

    python3 tools/make_maske.py

Vorbild ist das hochgeladene Produktfoto einer Körbchen-FFP2 (Moldex-Typ):
weißes **Rautennetz-Vlies**, rundes **Ausatemventil** mit blauem
Rundaufdruck („CE 0121 · EN149:2001 · FFP2 NR D", mittig „FFP2"),
zwei graue **Kopfbänder**. Der Markenname bleibt weg — der Rest der
Anmutung wird nachgebaut: Ellipsoid-Körbchen mit frontprojizierter
PIL-Textur (Netzstruktur, Schattierung, Ventilaufdruck), Ventilkuppel
aus Geometrie, Bänder als Ringe.

Achsen wie bei allen Requisiten: Z hoch, -Y ist vorn.
"""

import math
from pathlib import Path

import bpy
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ZIEL = Path(__file__).resolve().parent.parent / "assets" / "props"
TEXTUR = ZIEL / "atemmaske_vlies.png"

BREITE = 0.132   # Körbchen: Breite, Höhe, Tiefe in Metern
HOEHE = 0.116
TIEFE = 0.092
BLAU = (78, 88, 152)


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


def _ringtext(zeichner, mitte, radius, text, farbe, basis_bild):
    """Setzt `text` Zeichen für Zeichen auf einen Kreisbogen — wie der
    gestempelte Rundaufdruck auf dem Ventil des Fotos."""
    schritt = 2.0 * math.asin(5.5 / radius)  # Bogenmaß je Zeichen
    start = -math.pi / 2 - schritt * (len(text) - 1) / 2
    for lauf, zeichen in enumerate(text):
        if zeichen == " ":
            continue
        winkel = start + lauf * schritt
        kachel = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
        ImageDraw.Draw(kachel).text((7, 6), zeichen, fill=farbe + (255,))
        kachel = kachel.rotate(-math.degrees(winkel) - 0.0, resample=Image.BICUBIC)
        x = int(mitte[0] + radius * math.sin(winkel)) - 12
        y = int(mitte[1] - radius * math.cos(winkel)) - 12
        basis_bild.paste(kachel, (x, y), kachel)


def vlies_textur():
    """Rautennetz-Vlies mit Körbchen-Schattierung und Ventilaufdruck."""
    seite = 768
    rng = np.random.default_rng(2021)
    feld = np.full((seite, seite), 234.0)
    feld += rng.normal(0.0, 3.0, (seite, seite))

    # Rautennetz: zwei Familien diagonaler Linien mit heller Gegenkante —
    # so entsteht der geprägte Netz-Eindruck des Fotos.
    yy, xx = np.mgrid[0:seite, 0:seite].astype(np.float32)
    for richtung in (1.0, -1.0):
        laeufer = (xx + richtung * yy * 0.62) % 17.0
        feld -= np.clip(2.0 - np.abs(laeufer - 8.5), 0.0, 2.0) * 12.0
        feld += np.clip(1.2 - np.abs(laeufer - 6.5), 0.0, 1.2) * 9.0

    # Körbchen-Schattierung: zum Rand hin dunkler (frontprojiziert liegt
    # der Rand der Textur auf der Rundung).
    rand = np.sqrt((xx / seite - 0.5) ** 2 + (yy / seite - 0.5) ** 2)
    feld *= np.clip(1.06 - rand * 0.55, 0.62, 1.0)

    bild = Image.fromarray(np.clip(feld, 0, 255).astype(np.uint8), "L").convert("RGB")

    # Ventil: heller Kunststoffteller mit Rundaufdruck, mittig „FFP2".
    mitte = (seite // 2, seite // 2)
    teller = ImageDraw.Draw(bild)
    teller.ellipse([mitte[0] - 118, mitte[1] - 118, mitte[0] + 118, mitte[1] + 118],
                   fill=(224, 225, 228))
    teller.ellipse([mitte[0] - 118, mitte[1] - 118, mitte[0] + 118, mitte[1] + 118],
                   outline=(190, 192, 198), width=3)
    teller.ellipse([mitte[0] - 62, mitte[1] - 62, mitte[0] + 62, mitte[1] + 62],
                   outline=(200, 202, 208), width=2)
    _ringtext(teller, mitte, 92, "· CE 0121 · EN149:2001 · FFP2 NR D ·",
              BLAU, bild)
    # Mittiges „FFP2": klein rendern, hochskalieren — wirkt wie gedruckt.
    stempel = Image.new("RGBA", (46, 16), (0, 0, 0, 0))
    ImageDraw.Draw(stempel).text((2, 2), "FFP2", fill=BLAU + (255,))
    stempel = stempel.resize((115, 40), Image.LANCZOS)
    bild.paste(stempel, (mitte[0] - 52, mitte[1] - 18), stempel)

    bild = bild.filter(ImageFilter.GaussianBlur(0.4))
    ZIEL.mkdir(parents=True, exist_ok=True)
    bild.save(TEXTUR)
    print("  props/atemmaske_vlies.png")


def _front_uvs(obj):
    """Frontprojektion: X/Z der Ecken direkt als UV — das Foto liegt damit
    wie aufprojiziert auf der Wölbung."""
    netz = obj.data
    ebene = netz.uv_layers.new(name="UVMap") if not netz.uv_layers else netz.uv_layers[0]
    for poly in netz.polygons:
        for schleife in poly.loop_indices:
            co = netz.vertices[netz.loops[schleife].vertex_index].co
            ebene.data[schleife].uv = (co.x / BREITE + 0.5, co.z / HOEHE + 0.5)


def bauen():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    vlies_textur()

    vlies = _material("vlies", (1.0, 1.0, 1.0), rauheit=0.9)
    knoten = vlies.node_tree.nodes
    bild_knoten = knoten.new("ShaderNodeTexImage")
    bild_knoten.image = bpy.data.images.load(str(TEXTUR))
    vlies.node_tree.links.new(
        bild_knoten.outputs["Color"],
        knoten["Principled BSDF"].inputs["Base Color"])

    # --- Körbchen -----------------------------------------------------------
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=40, ring_count=22)
    korb = bpy.context.active_object
    korb.name = "korb"
    korb.scale = (BREITE / 2, TIEFE / 2, HOEHE / 2)
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.shade_smooth()
    _front_uvs(korb)
    korb.data.materials.append(vlies)

    # --- Ventilkuppel ---------------------------------------------------------
    # Sitzt vorn mittig auf der Wölbung; dieselbe Frontprojektion, damit der
    # Rundaufdruck der Textur genau über die Kuppel läuft.
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.0205, segments=28, ring_count=14,
                                         location=(0.0, -TIEFE / 2 + 0.004, 0.0))
    ventil = bpy.context.active_object
    ventil.name = "ventil"
    ventil.scale = (1.0, 0.55, 1.0)
    bpy.ops.object.transform_apply(scale=True, location=False)
    bpy.ops.object.shade_smooth()
    _front_uvs_versetzt(ventil)
    ventil.data.materials.append(vlies)

    # --- Kopfbänder -----------------------------------------------------------
    band = _material("band", (0.44, 0.45, 0.48), rauheit=0.85)
    baender = []
    for neigung, hoehe in ((-38.0, 0.022), (28.0, -0.020)):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.072, minor_radius=0.0026,
            location=(0.0, 0.030, hoehe),
            rotation=(math.radians(90 + neigung), 0.0, 0.0),
            major_segments=40, minor_segments=8)
        teil = bpy.context.active_object
        teil.name = "band"
        # Flachgedrückt zur Bandform.
        teil.scale = (1.0, 1.0, 0.45)
        bpy.ops.object.transform_apply(scale=True, location=False)
        bpy.ops.object.shade_smooth()
        teil.data.materials.append(band)
        baender.append(teil)

    bpy.ops.object.select_all(action="DESELECT")
    for teil in [korb, ventil] + baender:
        teil.select_set(True)
    bpy.context.view_layer.objects.active = korb
    bpy.ops.object.join()
    maske = bpy.context.active_object
    maske.name = "atemmaske"

    bpy.ops.export_scene.gltf(filepath=str(ZIEL / "atemmaske.glb"),
                              export_apply=True, export_yup=True,
                              use_selection=True)
    print("  props/atemmaske.glb (FFP2 nach Foto)")


def _front_uvs_versetzt(obj):
    """Frontprojektion für Anbauteile: die Weltlage der Ecken zählt, damit
    die Aufdruck-Stelle der Textur an der richtigen Stelle liegt."""
    netz = obj.data
    ebene = netz.uv_layers.new(name="UVMap") if not netz.uv_layers else netz.uv_layers[0]
    for poly in netz.polygons:
        for schleife in poly.loop_indices:
            co = obj.matrix_world @ netz.vertices[netz.loops[schleife].vertex_index].co
            ebene.data[schleife].uv = (co.x / BREITE + 0.5, co.z / HOEHE + 0.5)


if __name__ == "__main__":
    bauen()
    print("fertig")
