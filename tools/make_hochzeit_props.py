#!/usr/bin/env python3
"""Baut die Requisiten für Kapitel 3 — die Hochzeit an der Spree.

    python3 tools/make_hochzeit_props.py

Nach assets/props/:

* `strauss.glb`     — der Brautstrauß: Blütenkuppel, Grün, Stielbund,
                      Satinband. Das Wurfgeschoss des Minispiels, ~24 cm.
* `trauerweide.glb` — die Weide am Ufer: hängende Zweige aus je drei
                      Segmenten. Sie rahmt das Bild wie auf der Vorlage.
* `traubogen.glb`   — der Traubogen: zwei Pfosten, geschwungener Sturz,
                      weißes Tuch, Blüten an den Ecken.
* `stuhl_weiss.glb` — weißer Klappstuhl für die Gästereihen.
* `biertisch.glb`   — Stehtisch mit weißer Husse für den Empfang.
* `girlande.glb`    — Lichterkette, ein Bogen mit sieben Birnen.

Achsen wie immer: Z hoch, -Y vorn.
"""

import math
from pathlib import Path

import bpy

PROPS = Path(__file__).resolve().parent.parent / "assets" / "props"


def _linear(kanal: float) -> float:
    if kanal <= 0.04045:
        return kanal / 12.92
    return ((kanal + 0.055) / 1.055) ** 2.4


def _material(name, farbe, rauheit=0.9, metall=0.0, leuchten=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = tuple(
        _linear(k) for k in farbe) + (1.0,)
    bsdf.inputs["Roughness"].default_value = rauheit
    bsdf.inputs["Metallic"].default_value = metall
    if leuchten > 0.0:
        bsdf.inputs["Emission Color"].default_value = tuple(
            _linear(k) for k in farbe) + (1.0,)
        bsdf.inputs["Emission Strength"].default_value = leuchten
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


def _rohr(radius, laenge, ort, material, achse="Z", seiten=10, name="rohr",
          r_oben=None):
    drehung = {"Z": (0, 0, 0),
               "X": (0, math.radians(90), 0),
               "Y": (math.radians(90), 0, 0)}[achse]
    bpy.ops.mesh.primitive_cone_add(
        radius1=radius, radius2=radius if r_oben is None else r_oben,
        depth=laenge, location=ort, rotation=drehung, vertices=seiten)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return obj


def _kugel(radius, ort, material, unterteilung=2, name="kugel"):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=unterteilung,
                                          radius=radius, location=ort)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(material)
    bpy.ops.object.shade_smooth()
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


# --- Der Brautstrauß ----------------------------------------------------------


def strauss():
    """Der Brautstrauß: eine Kuppel aus Blütenköpfen über einem Stielbund,
    dazwischen Grün, unten ein Satinband.

    Er fliegt und dreht sich dabei — deshalb ist er von allen Seiten
    gebaut und nicht nur von vorn. Der Ursprung liegt in der Mitte des
    Bundes, damit er sich beim Fliegen um sich selbst dreht und nicht um
    einen Punkt daneben."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    creme = _material("bluete_creme", (0.96, 0.93, 0.88), rauheit=0.75)
    rose = _material("bluete_rose", (0.92, 0.72, 0.74), rauheit=0.75)
    gruen = _material("blattwerk", (0.32, 0.44, 0.24), rauheit=0.85)
    stiel = _material("stiele", (0.38, 0.42, 0.26), rauheit=0.9)
    band = _material("satinband", (0.90, 0.88, 0.82), rauheit=0.35)

    import random as zufall
    zufall.seed(23)
    teile = []
    # Stielbund, leicht konisch nach unten.
    teile.append(_rohr(0.028, 0.13, (0, 0, -0.055), stiel, seiten=10,
                       name="bund", r_oben=0.042))
    # Blütenkuppel: Köpfe auf einer Halbkugel verteilt.
    for i in range(26):
        # Fibonacci-artige Verteilung, damit keine Lücken und keine Reihen
        # entstehen — ein Strauß mit Muster sieht aus wie ein Ball.
        y = 1.0 - (i / 25.0) * 0.85
        r = math.sqrt(max(0.0, 1.0 - y * y))
        w = i * 2.399963
        ort = (math.cos(w) * r * 0.105,
               math.sin(w) * r * 0.105,
               0.055 + y * 0.058)
        stoff = creme if i % 3 else rose
        teile.append(_kugel(zufall.uniform(0.026, 0.036), ort, stoff,
                            name="bluete"))
    # Grün zwischen den Blüten, etwas weiter außen.
    for i in range(10):
        w = i * 0.628 + 0.3
        ort = (math.cos(w) * 0.115, math.sin(w) * 0.115,
               0.03 + zufall.uniform(-0.01, 0.03))
        blatt = _kasten((0.075, 0.02, 0.008), ort, name="blatt")
        blatt.rotation_euler = (0, zufall.uniform(-0.5, 0.5), w)
        blatt.data.materials.append(gruen)
        teile.append(blatt)
    # Satinband um den Bund, mit zwei Enden.
    bpy.ops.mesh.primitive_torus_add(major_radius=0.036, minor_radius=0.008,
                                     location=(0, 0, -0.03),
                                     major_segments=16, minor_segments=6)
    schleife = bpy.context.active_object
    schleife.name = "band"
    schleife.data.materials.append(band)
    bpy.ops.object.shade_smooth()
    teile.append(schleife)
    for seite in (-1, 1):
        ende = _kasten((0.014, 0.008, 0.07), (seite * 0.03, 0, -0.075),
                       name="bandende")
        ende.rotation_euler = (0, seite * 0.35, 0)
        ende.data.materials.append(band)
        teile.append(ende)
    _export([_verbinden(teile, "strauss")], "strauss")


# --- Die Weide am Ufer --------------------------------------------------------


def trauerweide():
    """Trauerweide: kurzer Stamm, eine breite flache Krone und darunter ein
    **dichter** Vorhang aus 320 Zweigen.

    **Dritter Versuch, und der Grund fürs Nachzählen.** Versuch eins drehte
    die Segmente mit Euler-Winkeln — ein Kaktus. Versuch zwei hängte 84
    dicke Zweige unter eine kugelige Krone — ein Lolli mit Spaghetti. Was
    eine Weide ausmacht, ist die **Dichte**: viele dünne, lange, ungleich
    lange Strähnen, die aus einer *flachen, breiten* Krone fallen und fast
    bis zum Boden reichen. Also 320 statt 84, dreiseitige Segmente statt
    fünfseitiger (aus zehn Metern ist ein Zweig zwei Pixel breit), und
    Längen zwischen 2 und 4,4 m."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rinde = _material("weidenrinde", (0.26, 0.22, 0.17), rauheit=0.95)
    laub = _material("weidenlaub", (0.24, 0.34, 0.15), rauheit=0.9)
    laub_hell = _material("weidenlaub_hell", (0.33, 0.42, 0.19), rauheit=0.9)

    import random as zufall
    zufall.seed(71)
    teile = [_rohr(0.30, 3.4, (0, 0, 1.7), rinde, seiten=10, name="stamm",
                   r_oben=0.15)]
    # Vier kurze Arme, die die Krone tragen.
    for i in range(4):
        w = math.tau * i / 4 + 0.4
        for schritt in range(2):
            t = (schritt + 0.5) / 2.0
            teile.append(_rohr(0.075 - schritt * 0.02, 1.5,
                               (math.cos(w) * (0.4 + t * 1.6),
                                math.sin(w) * (0.4 + t * 1.6),
                                3.4 + t * 0.7),
                               rinde, seiten=5, name="arm",
                               r_oben=0.055 - schritt * 0.02))

    # Die Krone: flach und breit, damit die Strähnen darunter hervorkommen
    # und nicht daneben.
    for i in range(14):
        w = math.tau * i / 14
        r = 1.2 if i % 3 == 0 else (2.3 if i % 3 == 1 else 3.2)
        ballen = _kugel(zufall.uniform(1.1, 1.7),
                        (math.cos(w) * r, math.sin(w) * r,
                         4.5 + zufall.uniform(-0.25, 0.25)),
                        laub if i % 2 else laub_hell, unterteilung=2,
                        name="laubballen")
        ballen.scale = (1.0, 1.0, 0.38)
        teile.append(ballen)
    mitte = _kugel(2.0, (0, 0, 4.7), laub, unterteilung=2, name="laubmitte")
    mitte.scale = (1.0, 1.0, 0.4)
    teile.append(mitte)

    # Der Vorhang.
    for i in range(320):
        w = math.tau * i / 320 * 7.0 + zufall.uniform(-0.2, 0.2)
        radius = zufall.uniform(0.9, 3.7)
        x = math.cos(w) * radius
        y = math.sin(w) * radius
        z = 4.5 - zufall.uniform(0.0, 0.5)
        stoff = laub if i % 3 else laub_hell
        laenge = zufall.uniform(2.0, 4.4)
        segmente = max(3, int(laenge / 0.6))
        for schritt in range(segmente):
            seg = laenge / segmente
            z -= seg / 2.0
            drift = 0.07 * (segmente - schritt) / segmente
            x += math.cos(w) * drift
            y += math.sin(w) * drift
            teile.append(_rohr(0.020 - schritt * 0.002, seg * 1.05, (x, y, z),
                               stoff, seiten=3, name="zweig",
                               r_oben=0.015 - schritt * 0.002))
            z -= seg / 2.0
    _export([_verbinden(teile, "trauerweide")], "trauerweide")


# --- Traubogen, Stuhl, Stehtisch, Lichterkette --------------------------------


def traubogen():
    """Der Traubogen: zwei Pfosten, ein geschwungener Sturz aus zwölf
    Segmenten, weißes Tuch und Blüten in den Ecken."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    holz = _material("bogenholz", (0.72, 0.66, 0.54), rauheit=0.75)
    tuch = _material("tuch", (0.96, 0.95, 0.92), rauheit=0.85)
    creme = _material("bluete_creme", (0.96, 0.93, 0.88), rauheit=0.75)
    rose = _material("bluete_rose", (0.92, 0.74, 0.76), rauheit=0.75)
    gruen = _material("blattwerk", (0.30, 0.42, 0.22), rauheit=0.85)

    teile = []
    for seite in (-1, 1):
        teile.append(_rohr(0.06, 2.4, (seite * 1.35, 0, 1.2), holz,
                           seiten=10, name="pfosten"))
    # Sturz als Bogen: zwölf kurze Segmente auf einem Halbkreis.
    for i in range(12):
        t0 = math.pi * i / 12.0
        t1 = math.pi * (i + 1) / 12.0
        p0 = (-math.cos(t0) * 1.35, 0.0, 2.4 + math.sin(t0) * 0.55)
        p1 = (-math.cos(t1) * 1.35, 0.0, 2.4 + math.sin(t1) * 0.55)
        mitte = tuple((a + b) / 2.0 for a, b in zip(p0, p1))
        laenge = math.dist(p0, p1) * 1.25
        seg = _rohr(0.055, laenge, mitte, holz, seiten=8, name="sturz")
        seg.rotation_euler = (0, math.atan2(p1[0] - p0[0], p1[2] - p0[2]), 0)
        teile.append(seg)
    # Tuch: zwei Bahnen, die von den Ecken herabfallen.
    for seite in (-1, 1):
        bahn = _kasten((0.30, 0.03, 1.5), (seite * 1.28, 0.06, 1.9),
                       name="tuchbahn")
        bahn.data.materials.append(tuch)
        teile.append(bahn)
        raffung = _kasten((0.55, 0.05, 0.28), (seite * 1.05, 0.05, 2.72),
                          fase=0.04, name="tuchraffung")
        raffung.data.materials.append(tuch)
        teile.append(raffung)
    # Blütenbüschel in den Ecken und am Scheitel.
    import random as zufall
    zufall.seed(9)
    for mitte in [(-1.25, 0.0, 2.55), (1.25, 0.0, 2.55), (0.0, 0.0, 2.95)]:
        for i in range(14):
            ort = (mitte[0] + zufall.uniform(-0.26, 0.26),
                   mitte[1] + zufall.uniform(-0.09, 0.09),
                   mitte[2] + zufall.uniform(-0.2, 0.2))
            stoff = [creme, rose, gruen][i % 3]
            teile.append(_kugel(zufall.uniform(0.035, 0.06), ort, stoff,
                                unterteilung=1, name="bluete"))
    _export([_verbinden(teile, "traubogen")], "traubogen")


def stuhl_weiss():
    """Weißer Klappstuhl für die Gästereihen: Sitz, Lehne, vier Beine,
    Querstrebe."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    weiss = _material("stuhlweiss", (0.93, 0.92, 0.89), rauheit=0.55)
    teile = []
    for x in (-0.19, 0.19):
        for y in (-0.18, 0.18):
            teile.append(_rohr(0.017, 0.46, (x, y, 0.23), weiss, seiten=8,
                               name="bein"))
    sitz = _kasten((0.44, 0.42, 0.035), (0, 0, 0.475), fase=0.012, name="sitz")
    sitz.data.materials.append(weiss)
    teile.append(sitz)
    for x in (-0.19, 0.19):
        teile.append(_rohr(0.017, 0.52, (x, 0.20, 0.73), weiss, seiten=8,
                           name="lehnenpfosten"))
    lehne = _kasten((0.42, 0.03, 0.22), (0, 0.20, 0.88), fase=0.012,
                    name="lehne")
    lehne.data.materials.append(weiss)
    teile.append(lehne)
    teile.append(_rohr(0.013, 0.38, (0, 0, 0.16), weiss, achse="X", seiten=6,
                       name="strebe"))
    _export([_verbinden(teile, "stuhl_weiss")], "stuhl_weiss")


def biertisch():
    """Stehtisch mit weißer Husse — der Empfangstisch. Die Husse ist ein
    Kegel, kein Zylinder: eine Husse fällt nach unten weiter."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    husse = _material("husse", (0.95, 0.94, 0.91), rauheit=0.8)
    platte = _material("tischplatte", (0.88, 0.86, 0.82), rauheit=0.5)
    teile = [
        _rohr(0.30, 1.05, (0, 0, 0.525), husse, seiten=20, name="husse",
              r_oben=0.22),
        _rohr(0.42, 0.05, (0, 0, 1.075), platte, seiten=24, name="platte"),
    ]
    _export([_verbinden(teile, "biertisch")], "biertisch")


def girlande():
    """Ein Bogen Lichterkette mit sieben Birnen. Die Kulisse hängt mehrere
    davon hintereinander; das Licht selbst kommt aus Godot."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kabel = _material("kabel", (0.14, 0.13, 0.12), rauheit=0.8)
    birne = _material("birne", (1.0, 0.86, 0.62), rauheit=0.3, leuchten=3.0)

    teile = []
    spanne = 6.0
    durchhang = 0.9
    letzte = None
    for i in range(19):
        t = i / 18.0
        x = -spanne / 2.0 + spanne * t
        z = -durchhang * math.sin(math.pi * t)
        if letzte is not None:
            mitte = ((x + letzte[0]) / 2.0, 0.0, (z + letzte[1]) / 2.0)
            laenge = math.dist((x, z), letzte) * 1.3
            seg = _rohr(0.011, laenge, mitte, kabel, seiten=5, name="kabel")
            seg.rotation_euler = (0, math.atan2(x - letzte[0], z - letzte[1]), 0)
            teile.append(seg)
        letzte = (x, z)
        if i % 3 == 1:
            teile.append(_kugel(0.055, (x, 0.0, z - 0.085), birne,
                                unterteilung=1, name="birne"))
    _export([_verbinden(teile, "girlande")], "girlande")


if __name__ == "__main__":
    strauss()
    trauerweide()
    traubogen()
    stuhl_weiss()
    biertisch()
    girlande()
    print("fertig")
