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


# --- Straßenmöbel für Sachsenhausen -------------------------------------------


def _rohr(radius, laenge, ort, material, achse="Z", seiten=10, name="rohr"):
    """Ein Rohr entlang einer Weltachse. Für Stuhlbeine, Rahmen, Ausleger —
    alles, was in dieser Gasse aus Rundstahl oder Holzstab besteht."""
    drehung = {"Z": (0, 0, 0),
               "X": (0, math.radians(90), 0),
               "Y": (math.radians(90), 0, 0)}[achse]
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=laenge,
                                        location=ort, rotation=drehung,
                                        vertices=seiten)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return obj


def bistrotisch():
    """Runder Wirtshaustisch: Gussfuß, Säule, Holzplatte. 72 cm hoch."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    guss = _material("guss", (0.13, 0.13, 0.14), rauheit=0.7)
    platte_holz = _material("tischholz", (0.42, 0.28, 0.17), rauheit=0.55)

    teile = [
        _rohr(0.24, 0.03, (0, 0, 0.015), guss, name="fuss"),
        _rohr(0.035, 0.70, (0, 0, 0.35), guss, name="saeule"),
        _rohr(0.34, 0.04, (0, 0, 0.70), platte_holz, seiten=24, name="platte"),
    ]
    _export([_verbinden(teile, "bistrotisch")], "bistrotisch")


def bistrostuhl():
    """Wirtshausstuhl: vier Beine, Sitzfläche, Lehne mit zwei Sprossen.
    Rückenlehne zeigt nach +Y, damit der Stuhl mit Blick nach -Y (Godot: +Z)
    am Tisch steht wie alle anderen Requisiten."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    holz = _material("stuhlholz", (0.38, 0.25, 0.15), rauheit=0.6)

    teile = []
    for x in (-0.17, 0.17):
        for y in (-0.17, 0.17):
            teile.append(_rohr(0.018, 0.45, (x, y, 0.225), holz, name="bein"))
    teile.append(_kasten((0.42, 0.42, 0.035), (0, 0, 0.465), fase=0.01,
                         name="sitz"))
    teile[-1].data.materials.append(holz)
    # Lehne: zwei Pfosten und zwei waagerechte Sprossen.
    for x in (-0.17, 0.17):
        teile.append(_rohr(0.018, 0.50, (x, 0.19, 0.72), holz, name="pfosten"))
    for z in (0.78, 0.92):
        teile.append(_rohr(0.016, 0.36, (0, 0.19, z), holz, achse="X",
                           name="sprosse"))
    _export([_verbinden(teile, "bistrostuhl")], "bistrostuhl")


def blumenkasten():
    """Fensterblumenkasten: Holztrog mit Erde und drei Blütenbüscheln.
    Sitzt unter den Fenstermodulen der Putzhäuser."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    trog = _material("trog", (0.34, 0.24, 0.16), rauheit=0.8)
    erde = _material("erde", (0.10, 0.08, 0.06), rauheit=0.95)
    gruen = _material("blattwerk", (0.24, 0.36, 0.15), rauheit=0.9)
    # Zwei Blütentöne — ein Kasten in einer Farbe wirkt wie ein Farbklecks.
    rot = _material("bluete_rot", (0.72, 0.16, 0.14), rauheit=0.85)
    weiss = _material("bluete_weiss", (0.90, 0.88, 0.80), rauheit=0.85)

    teile = [_kasten((0.90, 0.20, 0.18), (0, 0, 0.09), fase=0.01, name="trog")]
    teile[0].data.materials.append(trog)
    teile.append(_kasten((0.84, 0.15, 0.03), (0, 0, 0.185), name="erdreich"))
    teile[-1].data.materials.append(erde)

    import random as zufall
    zufall.seed(5)
    for i in range(9):
        ort = (-0.36 + i * 0.09, zufall.uniform(-0.04, 0.04),
               0.24 + zufall.uniform(-0.02, 0.05))
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,
                                              radius=zufall.uniform(0.05, 0.08),
                                              location=ort)
        busch = bpy.context.active_object
        busch.name = "busch"
        busch.data.materials.append(gruen)
        bpy.ops.object.shade_smooth()
        teile.append(busch)
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=1, radius=0.032,
            location=(ort[0], ort[1], ort[2] + 0.055))
        bluete = bpy.context.active_object
        bluete.name = "bluete"
        bluete.data.materials.append(rot if i % 3 else weiss)
        bpy.ops.object.shade_smooth()
        teile.append(bluete)
    _export([_verbinden(teile, "blumenkasten")], "blumenkasten")


def fahrrad():
    """Abgestelltes Stadtrad: zwei Speichenräder, Rahmen, Lenker, Sattel.
    Steht auf dem Ständer, leicht schräg — senkrecht sieht es aus wie
    hingestellt statt abgestellt. Fahrtrichtung -Y."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    gummi = _material("reifen", (0.06, 0.06, 0.065), rauheit=0.95)
    stahl = _material("rahmen", (0.16, 0.32, 0.42), rauheit=0.45, metall=0.4)
    chrom = _material("chrom", (0.62, 0.63, 0.66), rauheit=0.3, metall=0.6)
    leder = _material("sattel", (0.20, 0.13, 0.09), rauheit=0.7)

    teile = []
    for y in (-0.53, 0.53):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.33, minor_radius=0.022,
            location=(0, y, 0.33), rotation=(0, math.radians(90), 0),
            major_segments=28, minor_segments=8)
        reifen = bpy.context.active_object
        reifen.name = "reifen"
        reifen.data.materials.append(gummi)
        bpy.ops.object.shade_smooth()
        teile.append(reifen)
        for i in range(6):
            w = math.pi * i / 6
            teile.append(_rohr(0.005, 0.62, (0, y, 0.33), chrom, achse="Z",
                               seiten=6, name="speiche"))
            teile[-1].rotation_euler = (w, 0, 0)
    # Rahmen: Unterrohr, Oberrohr, Sattelrohr, Gabel, Steuerrohr.
    for anfang, ende, dicke in [((0, -0.42, 0.30), (0, 0.30, 0.28), 0.020),
                                ((0, -0.36, 0.62), (0, 0.16, 0.58), 0.018),
                                ((0, 0.16, 0.58), (0, 0.36, 0.30), 0.018),
                                ((0, -0.42, 0.30), (0, -0.50, 0.68), 0.020),
                                ((0, 0.36, 0.30), (0, 0.53, 0.33), 0.016)]:
        mitte = tuple((a + b) / 2 for a, b in zip(anfang, ende))
        laenge = math.dist(anfang, ende)
        rohr = _rohr(dicke, laenge, mitte, stahl, name="rahmenrohr")
        rohr.rotation_euler = (
            math.atan2(ende[1] - anfang[1], ende[2] - anfang[2]) * -1.0, 0, 0)
        teile.append(rohr)
    teile.append(_rohr(0.014, 0.44, (0, -0.50, 0.86), chrom, achse="X",
                       name="lenker"))
    teile.append(_kasten((0.10, 0.22, 0.05), (0, 0.20, 0.68), fase=0.02,
                         name="sattel"))
    teile[-1].data.materials.append(leder)

    modell = _verbinden(teile, "fahrrad")
    # Leicht angelehnt — die Neigung macht aus „hingestellt" „abgestellt".
    modell.rotation_euler = (0, math.radians(7), 0)
    _export([modell], "fahrrad")


def wirtshausschild():
    """Auslegerschild über der Kneipentür: Wandhalter, Streben, hängende
    Tafel mit Bembel-Silhouette. Die Tafel steht quer zur Fassade, damit
    man sie schon aus der Gasse liest."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    eisen = _material("schmiedeeisen", (0.09, 0.09, 0.10), rauheit=0.6)
    tafel_holz = _material("tafel", (0.16, 0.13, 0.10), rauheit=0.7)
    gold = _material("gold", (0.72, 0.58, 0.24), rauheit=0.35, metall=0.7)

    teile = [
        _rohr(0.03, 0.30, (0, -0.15, 1.10), eisen, achse="Y", name="wandarm"),
        _rohr(0.022, 0.90, (0, -0.30, 0.70), eisen, achse="Y", name="ausleger"),
        _rohr(0.016, 0.42, (0, -0.16, 0.92), eisen, name="strebe"),
    ]
    teile[-1].rotation_euler = (math.radians(38), 0, 0)
    for y in (-0.12, -0.66):
        teile.append(_rohr(0.008, 0.16, (0, y, 0.62), eisen, name="kettchen"))
    # Die Tafel selbst: quer zur Fassade (Fläche in der YZ-Ebene).
    teile.append(_kasten((0.04, 0.70, 0.46), (0, -0.39, 0.31), fase=0.02,
                         name="tafel"))
    teile[-1].data.materials.append(tafel_holz)
    # Bembel-Silhouette in Gold: Bauch, Hals, Henkel.
    for masse, ort in [((0.03, 0.26, 0.20), (0.03, -0.39, 0.26)),
                       ((0.03, 0.11, 0.10), (0.03, -0.39, 0.41)),
                       ((0.03, 0.05, 0.14), (0.03, -0.25, 0.28))]:
        teile.append(_kasten(masse, ort, fase=0.015, name="zeichen"))
        teile[-1].data.materials.append(gold)
    _export([_verbinden(teile, "wirtshausschild")], "wirtshausschild")


if __name__ == "__main__":
    lkw()
    bembel()
    bistrotisch()
    bistrostuhl()
    blumenkasten()
    fahrrad()
    wirtshausschild()
    schilder()
    fachwerk()
    skyline()
    holz()
    print("fertig")
