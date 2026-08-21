#!/usr/bin/env python3
"""Baut die Requisiten für Kapitel 2 — Frankfurt.

    python3 tools/make_ffm_props.py

Nach assets/props/:

* `lkw.glb`      — der Umzugs-LKW: Fahrerhaus, weißer Koffer mit
                   Seitenstreifen, sechs Räder. Vorn ist -Y (Godot: +Z).
* `bembel.glb`   — der Apfelweinkrug: graues Steinzeug, blaue Bänder,
                   Henkel. Ziel des Kneipen-Minispiels, ~26 cm hoch.

Nach assets/texturen/ffm/ (PIL):

* `schild_1..3.png` — blaue Autobahnschilder mit Kilometerangaben
* `fachwerk.png`    — Sachsenhausen-Fachwerk (Putz + Balken), kachelbar
* `skyline.png`     — Hochhausfassade (Glasraster) für die Silhouetten
* `holz.png`        — Dielenboden der Kneipe

Achsen wie immer: Z hoch, -Y vorn.
"""

import math
from pathlib import Path

import bpy
import numpy as np
from PIL import Image, ImageDraw

PROPS = Path(__file__).resolve().parent.parent / "assets" / "props"
TEXTUREN = Path(__file__).resolve().parent.parent / "assets" / "texturen" / "ffm"


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


def _kasten(masse, ort, fase=0.0, name="teil"):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=ort)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = masse
    bpy.ops.object.transform_apply(scale=True)
    if fase > 0.0:
        mod = obj.modifiers.new("fase", "BEVEL")
        mod.width = fase
        mod.segments = 2
    return obj


def _verbinden(teile, name):
    bpy.ops.object.select_all(action="DESELECT")
    for teil in teile:
        teil.select_set(True)
    bpy.context.view_layer.objects.active = teile[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    return obj


def _export(objekte, name):
    PROPS.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objekte:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(PROPS / f"{name}.glb"),
                              export_apply=True, export_yup=True,
                              use_selection=True)
    print(f"  props/{name}.glb")


# --- Der Umzugs-LKW -----------------------------------------------------------


def lkw():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    weiss = _material("koffer", (0.88, 0.88, 0.86), rauheit=0.6)
    kabine_lack = _material("kabine", (0.75, 0.20, 0.14), rauheit=0.4)
    dunkel = _material("fahrwerk", (0.10, 0.10, 0.11), rauheit=0.9)
    glas = _material("glas", (0.25, 0.32, 0.40), rauheit=0.1, metall=0.3)
    gummi = _material("gummi", (0.05, 0.05, 0.055), rauheit=0.95)
    streifen = _material("streifen", (0.85, 0.45, 0.15), rauheit=0.6)

    teile = []
    # Fahrerhaus vorn (-Y), leicht gefast.
    kabine = _kasten((2.2, 1.9, 1.7), (0, -3.4, 1.75), fase=0.08, name="kabine")
    kabine.data.materials.append(kabine_lack)
    teile.append(kabine)
    # Frontscheibe: bündig in der oberen Front, ohne Drehung — eine gedrehte
    # Platte landete nach dem Join sichtbar auf dem Dach.
    scheibe = _kasten((1.9, 0.10, 0.72), (0, -4.33, 2.12), name="scheibe")
    scheibe.data.materials.append(glas)
    teile.append(scheibe)
    for seite in (-1, 1):
        fenster = _kasten((0.10, 1.0, 0.55), (seite * 1.08, -3.55, 2.12),
                          name="seitenfenster")
        fenster.data.materials.append(glas)
        teile.append(fenster)
    kuehler = _kasten((1.7, 0.08, 0.30), (0, -4.34, 1.15), name="kuehler")
    kuehler.data.materials.append(dunkel)
    teile.append(kuehler)
    # Koffer: der weiße Kasten mit Streifen.
    koffer = _kasten((2.4, 5.2, 2.6), (0, 0.4, 2.15), fase=0.05, name="koffer")
    koffer.data.materials.append(weiss)
    teile.append(koffer)
    for seite in (-1, 1):
        zier = _kasten((0.03, 5.0, 0.35), (seite * 1.22, 0.4, 1.6), name="zier")
        zier.data.materials.append(streifen)
        teile.append(zier)
    # Chassis und Stoßstange.
    rahmen = _kasten((2.2, 7.4, 0.35), (0, -0.35, 0.72), name="rahmen")
    rahmen.data.materials.append(dunkel)
    teile.append(rahmen)
    stoss = _kasten((2.3, 0.25, 0.35), (0, -4.35, 0.55), fase=0.04, name="stoss")
    stoss.data.materials.append(dunkel)
    teile.append(stoss)

    # Sechs Räder: vorn zwei, hinten Zwillingsachse.
    for y in (-3.4, 1.2, 2.4):
        for seite in (-1, 1):
            bpy.ops.mesh.primitive_cylinder_add(
                radius=0.52, depth=0.34,
                location=(seite * 1.05, y, 0.52),
                rotation=(0, math.radians(90), 0), vertices=20)
            rad = bpy.context.active_object
            rad.name = "rad"
            rad.data.materials.append(gummi)
            bpy.ops.object.shade_smooth()
            teile.append(rad)

    modell = _verbinden(teile, "lkw")
    _export([modell], "lkw")


# --- Der Bembel ----------------------------------------------------------------


def _zylinder_uvs(obj, hoehe, boden):
    """Zylindrische Projektion, damit die blauen Bänder ringsum laufen."""
    netz = obj.data
    ebene = netz.uv_layers.new(name="UVMap") if not netz.uv_layers else netz.uv_layers[0]
    for poly in netz.polygons:
        for schleife in poly.loop_indices:
            co = netz.vertices[netz.loops[schleife].vertex_index].co
            u = math.atan2(co.x, co.y) / math.tau + 0.5
            v = (co.z - boden) / hoehe
            ebene.data[schleife].uv = (u, v)


def bembel_textur():
    TEXTUREN.mkdir(parents=True, exist_ok=True)
    seite = 256
    rng = np.random.default_rng(7)
    feld = np.full((seite, seite), 196.0) + rng.normal(0, 5.0, (seite, seite))
    bild = Image.fromarray(np.clip(feld, 0, 255).astype(np.uint8), "L").convert("RGB")
    z = ImageDraw.Draw(bild)
    # Blaue Ringe wie beim echten Bembel: unten breit, oben schmal.
    for v_anteil, dicke in ((0.16, 7), (0.30, 4), (0.72, 5), (0.80, 3)):
        y = int(seite * (1.0 - v_anteil))
        z.rectangle([0, y - dicke, seite, y + dicke], fill=(46, 62, 130))
    # Ein paar blaue Tupfen im Mittelfeld.
    for i in range(9):
        x = int(seite * (0.05 + 0.105 * i))
        y = int(seite * 0.48)
        z.ellipse([x - 6, y - 9, x + 6, y + 9], fill=(46, 62, 130))
    bild.save(TEXTUREN / "bembel.png")


def bembel():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bembel_textur()
    steinzeug = _material("steinzeug", (1.0, 1.0, 1.0), rauheit=0.55)
    knoten = steinzeug.node_tree.nodes
    bild = knoten.new("ShaderNodeTexImage")
    bild.image = bpy.data.images.load(str(TEXTUREN / "bembel.png"))
    steinzeug.node_tree.links.new(
        bild.outputs["Color"], knoten["Principled BSDF"].inputs["Base Color"])

    teile = []
    # Bauch: gestauchte Kugel, Fuß und Hals als Zylinder.
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.085, segments=28, ring_count=16,
                                         location=(0, 0, 0.115))
    bauch = bpy.context.active_object
    bauch.scale = (1.0, 1.0, 0.95)
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.shade_smooth()
    teile.append(bauch)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.052, depth=0.05,
                                        location=(0, 0, 0.025), vertices=24)
    fuss = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    teile.append(fuss)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.035, depth=0.07,
                                        location=(0, 0, 0.215), vertices=24)
    hals = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    teile.append(hals)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.038, minor_radius=0.007,
                                     location=(0, 0, 0.248),
                                     major_segments=24, minor_segments=8)
    lippe = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    teile.append(lippe)
    # Henkel seitlich.
    bpy.ops.mesh.primitive_torus_add(major_radius=0.045, minor_radius=0.010,
                                     location=(0.095, 0, 0.15),
                                     rotation=(math.radians(90), 0, 0),
                                     major_segments=20, minor_segments=8)
    henkel = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    teile.append(henkel)

    krug = _verbinden(teile, "bembel")
    _zylinder_uvs(krug, 0.26, 0.0)
    krug.data.materials.append(steinzeug)
    _export([krug], "bembel")


# --- Texturen für Autobahn, Fachwerk, Skyline, Kneipe ---------------------------


def schilder():
    TEXTUREN.mkdir(parents=True, exist_ok=True)
    zeilen = [
        ("schild_1", ["Frankfurt am Main", "548"]),
        ("schild_2", ["Frankfurt", "253"]),
        ("schild_3", ["Frankfurt-Sachsenhausen", "Ausfahrt  1000 m"]),
    ]
    for name, texte in zeilen:
        bild = Image.new("RGB", (512, 256), (18, 65, 145))
        z = ImageDraw.Draw(bild)
        z.rectangle([6, 6, 505, 249], outline=(240, 242, 246), width=6)
        # Text klein rendern und hochskalieren — kräftige Schildschrift.
        for lauf, text in enumerate(texte):
            klein = Image.new("RGBA", (200, 18), (0, 0, 0, 0))
            ImageDraw.Draw(klein).text((2, 2), text, fill=(245, 246, 250, 255))
            gross = klein.resize((460, 62), Image.LANCZOS)
            bild.paste(gross, (28, 42 + lauf * 96), gross)
        bild.save(TEXTUREN / f"{name}.png")
    print("  texturen/ffm/schild_1..3.png")


def fachwerk():
    seite = 512
    rng = np.random.default_rng(11)
    feld = np.full((seite, seite), 228.0) + rng.normal(0, 5.0, (seite, seite))
    bild = Image.fromarray(np.clip(feld, 0, 255).astype(np.uint8), "L").convert("RGB")
    z = ImageDraw.Draw(bild)
    balken = (74, 50, 34)
    # Schwelle, Rähm, Ständer, Streben — eine Etage, kachelbar.
    z.rectangle([0, 0, seite, 26], fill=balken)
    z.rectangle([0, seite - 26, seite, seite], fill=balken)
    for x in (0, 168, 336, 486):
        z.rectangle([x, 0, x + 26, seite], fill=balken)
    z.line([(26, seite - 26), (168, 26)], fill=balken, width=24)
    z.line([(336, 26), (486, seite - 26)], fill=balken, width=24)
    bild.save(TEXTUREN / "fachwerk.png")
    print("  texturen/ffm/fachwerk.png")


def skyline():
    seite = 256
    bild = Image.new("RGB", (seite, seite), (96, 118, 148))
    z = ImageDraw.Draw(bild)
    # Glasraster: helle Scheiben, dunkle Fugen — bei Tag spiegeln sie Himmel.
    for zeile in range(0, seite, 16):
        for spalte in range(0, seite, 12):
            hell = 118 + ((zeile * 7 + spalte * 13) % 40)
            z.rectangle([spalte + 2, zeile + 2, spalte + 10, zeile + 13],
                        fill=(hell, hell + 14, hell + 30))
    bild.save(TEXTUREN / "skyline.png")
    print("  texturen/ffm/skyline.png")


def holz():
    seite = 256
    rng = np.random.default_rng(13)
    feld = np.zeros((seite, seite, 3), dtype=np.float32)
    grund = np.array([116.0, 82.0, 52.0])
    for reihe in range(0, seite, 32):
        ton = grund * rng.uniform(0.82, 1.1)
        feld[reihe:reihe + 32, :] = ton
        feld[reihe:reihe + 2, :] *= 0.55
    maser = rng.normal(0, 5.0, (seite, seite, 1))
    feld += maser
    Image.fromarray(np.clip(feld, 0, 255).astype(np.uint8), "RGB")\
        .save(TEXTUREN / "holz.png")
    print("  texturen/ffm/holz.png")


if __name__ == "__main__":
    lkw()
    bembel()
    schilder()
    fachwerk()
    skyline()
    holz()
    print("fertig")
