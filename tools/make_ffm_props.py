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


def _schriftzug_material():
    """Firmenschriftzug für den Koffer — klein gerendert, hochskaliert,
    dadurch wirkt er gedruckt statt pixelig."""
    seite_b, seite_h = 720, 200
    bild = Image.new("RGB", (180, 50), (225, 225, 222))
    tinte = ImageDraw.Draw(bild)
    tinte.text((6, 8), "SCHMIED UMZÜGE", fill=(28, 48, 110))
    tinte.text((6, 28), "Berlin - Frankfurt", fill=(120, 40, 30))
    bild = bild.resize((seite_b, seite_h), Image.LANCZOS)
    pfad = PROPS / "lkw_schriftzug.png"
    bild.save(pfad)
    mat = _material("schriftzug", (1.0, 1.0, 1.0), rauheit=0.6)
    knoten = mat.node_tree.nodes
    tex = knoten.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(pfad))
    mat.node_tree.links.new(tex.outputs["Color"],
                            knoten["Principled BSDF"].inputs["Base Color"])
    return mat


def lkw():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    weiss = _material("koffer", (0.88, 0.88, 0.86), rauheit=0.6)
    kabine_lack = _material("kabine", (0.75, 0.20, 0.14), rauheit=0.4)
    dunkel = _material("fahrwerk", (0.10, 0.10, 0.11), rauheit=0.9)
    glas = _material("glas", (0.55, 0.62, 0.68), rauheit=0.08, metall=0.2)
    # Die Scheibe muss durchsichtig sein: die Autobahnsequenz filmt aus der
    # Kabine, und durch ein blaugraues Blech sieht man keine Straße.
    glas.blend_method = "BLEND"
    _glas_bsdf = glas.node_tree.nodes["Principled BSDF"]
    _glas_bsdf.inputs["Base Color"].default_value = (0.62, 0.70, 0.76, 0.30)
    _glas_bsdf.inputs["Alpha"].default_value = 0.30
    gummi = _material("gummi", (0.11, 0.11, 0.12), rauheit=0.9)
    streifen = _material("streifen", (0.85, 0.45, 0.15), rauheit=0.6)

    teile = []
    # --- Fahrerhaus als Hülle, nicht als Klotz -------------------------------
    # Die erste Fassung war ein massiver Würfel. Das sieht von außen richtig
    # aus und ist von innen unbrauchbar: die Autobahnsequenz filmt aus der
    # Kabine und sah gegen die *Innenseite* der Vorderwand. Das Fahrerhaus
    # besteht deshalb aus Boden, Dach, Seiten, Rückwand und einem
    # Frontrahmen mit echter Fensteröffnung.
    innen = _material("kabine_innen", (0.13, 0.12, 0.13), rauheit=0.85)
    for masse, ort, mat, name in [
            # Außenhaut in Lackrot.
            ((2.4, 1.9, 0.10), (0, -3.4, 0.95), kabine_lack, "kabinenboden"),
            ((2.4, 1.9, 0.10), (0, -3.4, 2.58), kabine_lack, "kabinendach"),
            ((0.10, 1.9, 1.70), (-1.15, -3.4, 1.76), kabine_lack, "kabinenwand"),
            ((0.10, 1.9, 1.70), (1.15, -3.4, 1.76), kabine_lack, "kabinenwand"),
            ((2.4, 0.10, 1.70), (0, -2.50, 1.76), kabine_lack, "kabinenrueck"),
            # Frontrahmen: Brüstung unten, Dachkante oben, zwei A-Säulen.
            ((2.4, 0.12, 0.52), (0, -4.32, 1.28), kabine_lack, "front_bruestung"),
            ((2.4, 0.12, 0.22), (0, -4.32, 2.42), kabine_lack, "front_dachkante"),
            ((0.26, 0.12, 1.70), (-1.07, -4.32, 1.76), kabine_lack, "a_saeule"),
            ((0.26, 0.12, 1.70), (1.07, -4.32, 1.76), kabine_lack, "a_saeule"),
            # Dunkle Innenauskleidung, damit von innen kein Rot leuchtet.
            ((2.0, 1.74, 0.03), (0, -3.4, 1.02), innen, "innenboden"),
            ((2.0, 1.74, 0.03), (0, -3.4, 2.51), innen, "innendach"),
            ((0.03, 1.74, 1.42), (-1.08, -3.4, 1.76), innen, "innenwand"),
            ((0.03, 1.74, 1.42), (1.08, -3.4, 1.76), innen, "innenwand"),
            ((2.0, 0.03, 1.42), (0, -2.56, 1.76), innen, "innenrueck")]:
        teil = _kasten(masse, ort, fase=0.02, name=name)
        teil.data.materials.append(mat)
        teile.append(teil)
    # Frontscheibe in der Öffnung — durchsichtig, damit die Fahrt sichtbar ist.
    scheibe = _kasten((1.94, 0.04, 0.85), (0, -4.30, 1.87), name="scheibe")
    scheibe.data.materials.append(glas)
    teile.append(scheibe)
    for seite in (-1, 1):
        fenster = _kasten((0.04, 1.0, 0.55), (seite * 1.14, -3.55, 2.05),
                          name="seitenfenster")
        fenster.data.materials.append(glas)
        teile.append(fenster)
    kuehler = _kasten((1.7, 0.08, 0.30), (0, -4.36, 1.02), name="kuehler")
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

    # --- Anbauteile, die einen LKW erst zum LKW machen ------------------------
    # Wichtig: die Fensteröffnung des Frontrahmens bleibt unangetastet —
    # auf ihr ist die Kamera des Fahrspiels kalibriert (y 1,54 bis 2,31).
    chrom = _material("chrom", (0.65, 0.66, 0.68), rauheit=0.25, metall=0.8)
    # Sonnenblende über der Scheibe.
    blende = _kasten((2.44, 0.30, 0.14), (0, -4.36, 2.56), fase=0.03, name="blende")
    blende.data.materials.append(kabine_lack)
    teile.append(blende)
    # Kühlergrill-Lamellen und Chromleiste.
    for z in (0.92, 1.06, 1.20):
        lamelle = _kasten((1.6, 0.04, 0.08), (0, -4.40, z), name="lamelle")
        lamelle.data.materials.append(dunkel)
        teile.append(lamelle)
    leiste = _kasten((1.7, 0.03, 0.05), (0, -4.41, 1.32), name="leiste")
    leiste.data.materials.append(chrom)
    teile.append(leiste)
    # Große Transporterspiegel an den A-Säulen, beidseitig.
    for seite in (-1, 1):
        arm = _kasten((0.30, 0.05, 0.05), (seite * 1.28, -4.20, 2.30), name="arm")
        arm.data.materials.append(dunkel)
        teile.append(arm)
        spiegel = _kasten((0.06, 0.24, 0.42), (seite * 1.42, -4.16, 2.10),
                          fase=0.015, name="spiegel")
        spiegel.data.materials.append(dunkel)
        teile.append(spiegel)
    # Schmutzfänger hinter den Rädern, Seitenschürze zwischen den Achsen.
    for seite in (-1, 1):
        for y in (-2.82, 2.98):
            lappen = _kasten((0.36, 0.04, 0.42), (seite * 1.05, y, 0.30),
                             name="lappen")
            lappen.data.materials.append(gummi)
            teile.append(lappen)
        schuerze = _kasten((0.08, 3.2, 0.35), (seite * 1.10, -0.9, 0.42),
                           name="schuerze")
        schuerze.data.materials.append(dunkel)
        teile.append(schuerze)
    # Tank und Staukasten unterm Rahmen.
    tank = _kasten((0.34, 1.1, 0.5), (-0.95, -1.6, 0.62), fase=0.06, name="tank")
    tank.data.materials.append(chrom)
    teile.append(tank)
    stau = _kasten((0.30, 0.9, 0.45), (0.95, -1.6, 0.60), fase=0.03, name="stau")
    stau.data.materials.append(dunkel)
    teile.append(stau)
    # Warnmarkierung hinten: rot-weiß schraffierte Ecken.
    for seite in (-1, 1):
        warn = _kasten((0.4, 0.02, 0.12), (seite * 0.9, 3.02, 0.95), name="warn")
        warn.data.materials.append(streifen)
        teile.append(warn)

    # Schriftzug auf dem Koffer: eigene dünne Tafel je Seite, Textur aus PIL.
    schrift_mat = _schriftzug_material()
    for seite in (-1, 1):
        tafel = bpy.ops.mesh.primitive_plane_add(
            size=1.0, location=(seite * 1.215, 0.3, 2.35),
            rotation=(math.radians(90), 0, math.radians(90 * seite)))
        tafel = bpy.context.active_object
        tafel.name = "schriftzug"
        tafel.scale = (3.6, 1.0, 1.0)
        bpy.ops.object.transform_apply(scale=True, rotation=True)
        tafel.data.materials.append(schrift_mat)
        teile.append(tafel)

    # --- Fahrerhaus von innen ------------------------------------------------
    # Für die Einstellung aus der Kabine (Kapitel 2, Autobahnsequenz) muss
    # hinter der Scheibe etwas sein. Alles hier ist nur von innen zu sehen.
    kunststoff = _material("armaturen", (0.10, 0.10, 0.11), rauheit=0.8)
    polster = _material("polster", (0.16, 0.15, 0.17), rauheit=0.95)
    for masse, ort, mat in [
            ((2.0, 0.34, 0.30), (0, -4.06, 1.72), kunststoff),   # Armaturenbrett
            ((2.0, 0.10, 0.16), (0, -4.20, 1.94), kunststoff),   # Kombiinstrument
            ((0.60, 0.36, 0.44), (-0.52, -3.20, 1.30), polster), # Sitz links
            ((0.60, 0.36, 0.44), (0.52, -3.20, 1.30), polster),  # Sitz rechts
            ((0.60, 0.12, 0.52), (-0.52, -3.00, 1.72), polster), # Lehne links
            ((0.60, 0.12, 0.52), (0.52, -3.00, 1.72), polster)]:
        teil = _kasten(masse, ort, fase=0.03, name="kabine_innen")
        teil.data.materials.append(mat)
        teile.append(teil)
    # Lenkrad: Kranz, Nabe, drei Speichen. Leicht geneigt wie im LKW.
    bpy.ops.mesh.primitive_torus_add(major_radius=0.22, minor_radius=0.022,
                                     location=(-0.52, -3.86, 1.66),
                                     rotation=(math.radians(68), 0, 0),
                                     major_segments=24, minor_segments=8)
    kranz = bpy.context.active_object
    kranz.name = "lenkradkranz"
    kranz.data.materials.append(kunststoff)
    bpy.ops.object.shade_smooth()
    teile.append(kranz)
    nabe = _rohr(0.05, 0.05, (-0.52, -3.83, 1.65), kunststoff, achse="Y",
                 name="lenkradnabe")
    teile.append(nabe)
    for winkel in (0, 120, 240):
        speiche = _rohr(0.014, 0.21, (-0.52, -3.84, 1.65), kunststoff,
                        seiten=6, name="speiche")
        speiche.rotation_euler = (math.radians(68), 0, math.radians(winkel))
        speiche.location = (
            -0.52 + 0.10 * math.cos(math.radians(winkel + 90)),
            -3.84,
            1.65 + 0.10 * math.sin(math.radians(winkel + 90)))
        teile.append(speiche)
    # Innenspiegel unter dem Dach.
    spiegelblech = _kasten((0.34, 0.05, 0.10), (0, -3.92, 2.34), fase=0.02,
                           name="innenspiegel")
    spiegelblech.data.materials.append(kunststoff)
    teile.append(spiegelblech)

    karosserie = _verbinden(teile, "karosserie")

    # --- Räder als eigene Objekte -------------------------------------------
    # Sie müssen sich drehen können, also dürfen sie nicht mit der
    # Karosserie verschmelzen. Godot findet sie später über den Namen.
    felge = _material("felge", (0.55, 0.56, 0.58), rauheit=0.35, metall=0.5)
    raeder = []
    for nummer, (seite, y) in enumerate(
            [(-1, -3.4), (1, -3.4), (-1, 1.2), (1, 1.2), (-1, 2.4), (1, 2.4)]):
        bpy.ops.mesh.primitive_cylinder_add(
            radius=0.52, depth=0.34, location=(seite * 1.05, y, 0.52),
            rotation=(0, math.radians(90), 0), vertices=20)
        reifen = bpy.context.active_object
        reifen.data.materials.append(gummi)
        bpy.ops.object.shade_smooth()
        # Felge und vier Radbolzen auf **beiden** Radseiten: ohne sie ist die
        # Drehung unsichtbar, ein schwarzer Zylinder sieht stehend wie
        # fahrend aus. Auf nur einer Seite genügt nicht — bei der linken
        # Radreihe lag sie innen und war von außen nie zu sehen.
        naben = []
        for aussen in (-0.16, 0.16):
            naben.append(_rohr(0.30, 0.05,
                               (seite * 1.05 + aussen, y, 0.52),
                               felge, achse="X", seiten=18, name="felge"))
            for i in range(5):
                w = math.tau * i / 5
                naben.append(_rohr(0.030, 0.07,
                                   (seite * 1.05 + aussen * 1.25,
                                    y + 0.17 * math.cos(w),
                                    0.52 + 0.17 * math.sin(w)),
                                   dunkel, achse="X", seiten=6, name="bolzen"))
        rad = _verbinden([reifen] + naben, "rad_%d" % nummer)
        # Drehung ins Netz backen: der Zylinder wurde um 90° gedreht
        # erzeugt. Bleibt diese Drehung am Objekt, trägt sie der glTF-Knoten
        # — und `rotate_x` in Godot dreht dann um eine schräge Achse, das
        # Rad taumelt sichtbar statt zu rollen.
        bpy.context.view_layer.objects.active = rad
        rad.select_set(True)
        bpy.ops.object.transform_apply(rotation=True, location=False,
                                       scale=False)
        rad.select_set(False)
        # Der Ursprung muss in der Radmitte liegen, sonst dreht das Rad um
        # den Weltnullpunkt statt um seine Achse.
        bpy.context.view_layer.objects.active = rad
        rad.select_set(True)
        bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="MEDIAN")
        rad.select_set(False)
        raeder.append(rad)

    _export([karosserie] + raeder, "lkw")


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
    """Salzglasiertes Steinzeug: grau gesprenkelt, mit dem klassischen
    kobaltblauen Rautenband um den Bauch.

    Die erste Fassung war zu hell und hatte nur Ringe — sie las sich als
    Porzellanpüppchen. Ein echter Bembel ist deutlich dunkler (Salzglasur
    ist gräulich, nicht weiß), das Blau sitzt satt und das Rautenband ist
    das Erkennungszeichen."""
    TEXTUREN.mkdir(parents=True, exist_ok=True)
    breite, hoehe = 512, 512
    rng = np.random.default_rng(7)
    # Grundton mit Sprenkeln und Wolken — Salzglasur ist ungleichmäßig.
    grund = np.full((hoehe, breite), 118.0)
    grund += rng.normal(0, 11.0, (hoehe, breite))
    grob = rng.normal(0, 16.0, (hoehe // 16, breite // 16))
    grund += np.kron(grob, np.ones((16, 16)))
    bild = Image.fromarray(np.clip(grund, 0, 255).astype(np.uint8), "L").convert("RGB")
    z = ImageDraw.Draw(bild)

    BLAU = (38, 54, 122)
    # Zwei schmale Ringe oben, zwei unten, dazwischen das Rautenband.
    for v_anteil, dicke in ((0.13, 5), (0.24, 3), (0.74, 4), (0.82, 3)):
        y = int(hoehe * (1.0 - v_anteil))
        z.rectangle([0, y - dicke, breite, y + dicke], fill=BLAU)
    # Rautenband: liegende Karos, oben und unten von einer Linie gefasst.
    mitte = int(hoehe * 0.50)
    spanne = int(hoehe * 0.10)
    for y in (mitte - spanne, mitte + spanne):
        z.rectangle([0, y - 2, breite, y + 2], fill=BLAU)
    rauten = 10
    for i in range(rauten):
        x = breite * (i + 0.5) / rauten
        halb = breite / rauten * 0.42
        z.polygon([(x, mitte - spanne + 4), (x + halb, mitte),
                   (x, mitte + spanne - 4), (x - halb, mitte)], fill=BLAU)
    # Glasurläufer: ein paar senkrechte, dunklere Schlieren.
    for _ in range(14):
        x = int(rng.uniform(0, breite))
        y0 = int(rng.uniform(0, hoehe * 0.8))
        laenge = int(rng.uniform(20, 90))
        z.line([(x, y0), (x + rng.integers(-3, 4), y0 + laenge)],
               fill=(126, 126, 130), width=int(rng.integers(1, 3)))
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


# --- Inventar der Kneipenstube ------------------------------------------------


def gerippte():
    """Das Geripptes: das gerippte 0,3-l-Glas, aus dem in Frankfurt der
    Apfelwein getrunken wird. Kein Detail dieser Kneipe ist so
    wiedererkennbar wie dieses Glas — es lohnt die zwei Dutzend Flächen.

    Die Rippen sind echte Geometrie (ein Zylinder mit 14 Kanten, die
    Seitenflächen leicht herausgezogen): eine Rippen-*Textur* verschwindet
    aus zwei Metern, eine Rippen-*Silhouette* nicht."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    glas = _material("glas", (0.86, 0.90, 0.88), rauheit=0.08)
    glas.blend_method = "BLEND"
    bsdf = glas.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.80, 0.86, 0.84, 0.42)
    bsdf.inputs["Alpha"].default_value = 0.42
    apfelwein = _material("apfelwein", (0.78, 0.60, 0.16), rauheit=0.12)

    teile = []
    bpy.ops.mesh.primitive_cylinder_add(radius=0.037, depth=0.115,
                                        location=(0, 0, 0.0575), vertices=14)
    koerper = bpy.context.active_object
    koerper.name = "glaskoerper"
    # Jede zweite Seitenfläche einen Millimeter heraus: das ergibt die
    # typische Rippung, ohne die Fläche zu verdoppeln.
    netz = koerper.data
    for poly in netz.polygons:
        if abs(poly.normal.z) > 0.5:
            continue
        if poly.index % 2:
            continue
        for ecke in poly.vertices:
            v = netz.vertices[ecke]
            v.co.x *= 1.085
            v.co.y *= 1.085
    koerper.data.materials.append(glas)
    teile.append(koerper)
    # Der Inhalt: eine Handbreit unter dem Rand, sonst sieht es aus wie
    # ein Vollglas aus Plastik.
    bpy.ops.mesh.primitive_cylinder_add(radius=0.034, depth=0.082,
                                        location=(0, 0, 0.045), vertices=14)
    inhalt = bpy.context.active_object
    inhalt.name = "inhalt"
    inhalt.data.materials.append(apfelwein)
    teile.append(inhalt)
    _export(teile, "gerippte")


def tresen():
    """Der Schanktresen: Korpus mit Holzfront, überstehende Platte,
    Messing-Fußreling. Die Flaschen stellt die Kulisse dazu."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    holz = _material("tresenholz", (0.29, 0.18, 0.11), rauheit=0.5)
    platte = _material("tresenplatte", (0.22, 0.13, 0.08), rauheit=0.28)
    messing = _material("messing", (0.72, 0.56, 0.22), rauheit=0.3, metall=0.8)

    teile = []
    korpus = _kasten((2.9, 0.66, 1.02), (0, 0, 0.51), fase=0.02, name="korpus")
    korpus.data.materials.append(holz)
    teile.append(korpus)
    # Kassettenfelder in der Front — ein glatter Kasten liest sich als Kiste.
    for i in (-1, 0, 1):
        feld = _kasten((0.80, 0.04, 0.62), (i * 0.92, -0.34, 0.52),
                       fase=0.015, name="kassette")
        feld.data.materials.append(platte)
        teile.append(feld)
    deck = _kasten((3.06, 0.78, 0.07), (0, 0.02, 1.055), fase=0.02, name="deck")
    deck.data.materials.append(platte)
    teile.append(deck)
    reling = _rohr(0.022, 2.7, (0, -0.42, 0.18), messing, achse="X",
                   name="fussreling")
    teile.append(reling)
    for x in (-1.2, 0.0, 1.2):
        halter = _rohr(0.018, 0.20, (x, -0.40, 0.10), messing, name="halter")
        teile.append(halter)
    _export([_verbinden(teile, "tresen")], "tresen")


def wandbilder():
    """Drei gerahmte Bilder für die Stube. Sepia, körnig, absichtlich
    unscharf im Motiv — sie sollen wie alte Wirtshausfotos lesen, nicht
    wie Poster."""
    TEXTUREN.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(31)
    for nummer in (1, 2, 3):
        breite, hoehe = 256, 320
        feld = np.full((hoehe, breite, 3), 0.0)
        feld[:, :, 0] = 196
        feld[:, :, 1] = 176
        feld[:, :, 2] = 138
        bild = Image.fromarray(feld.astype(np.uint8), "RGB")
        z = ImageDraw.Draw(bild)
        if nummer == 1:
            # Dachlinie mit Türmen — „Alt-Sachsenhausen".
            y = int(hoehe * 0.62)
            for i in range(9):
                x = i * breite / 9
                h = rng.integers(30, 90)
                z.rectangle([x, y - h, x + breite / 9 - 3, y], fill=(96, 82, 62))
                z.polygon([(x - 3, y - h), (x + breite / 18, y - h - 22),
                           (x + breite / 9, y - h)], fill=(84, 70, 52))
            z.rectangle([0, y, breite, hoehe], fill=(150, 132, 100))
        elif nummer == 2:
            # Ein Bembel als Stillleben.
            z.ellipse([70, 150, 186, 260], fill=(120, 106, 84))
            z.rectangle([108, 96, 148, 160], fill=(120, 106, 84))
            z.ellipse([100, 84, 156, 110], fill=(108, 94, 74))
            z.arc([170, 176, 214, 232], start=270, end=90, fill=(120, 106, 84),
                  width=9)
            z.rectangle([40, 258, 216, 266], fill=(104, 90, 70))
        else:
            # Gruppenbild: Silhouetten an einem langen Tisch.
            z.rectangle([20, 214, 236, 226], fill=(104, 90, 70))
            for i in range(5):
                x = 34 + i * 44
                z.ellipse([x, 150, x + 26, 176], fill=(96, 82, 62))
                z.rectangle([x - 4, 176, x + 30, 216], fill=(96, 82, 62))
        # Korn und Vignette machen aus der Zeichnung ein Foto.
        feld = np.asarray(bild).astype(float)
        feld += rng.normal(0, 12.0, feld.shape)
        yy, xx = np.mgrid[0:hoehe, 0:breite]
        rand = np.sqrt(((xx - breite / 2) / (breite / 2)) ** 2
                       + ((yy - hoehe / 2) / (hoehe / 2)) ** 2)
        feld *= np.clip(1.12 - 0.36 * rand, 0, 1.3)[:, :, None]
        Image.fromarray(np.clip(feld, 0, 255).astype(np.uint8), "RGB")\
            .save(TEXTUREN / f"wandbild_{nummer}.png")
    print("  texturen/ffm/wandbild_1..3.png")


def bilderrahmen():
    """Der Rahmen zu den Bildern: Leiste ringsum, Bildfläche innen.
    Die Bildfläche bekommt eigene UVs, damit die Kulisse jedem Rahmen
    eine andere Textur geben kann."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    leiste = _material("rahmenleiste", (0.20, 0.13, 0.08), rauheit=0.45)
    bildflaeche = _material("bildflaeche", (1.0, 1.0, 1.0), rauheit=0.7)

    teile = []
    for masse, ort in [((0.52, 0.04, 0.05), (0, 0, 0.32)),
                       ((0.52, 0.04, 0.05), (0, 0, -0.32)),
                       ((0.05, 0.04, 0.69), (-0.235, 0, 0)),
                       ((0.05, 0.04, 0.69), (0.235, 0, 0))]:
        teil = _kasten(masse, ort, fase=0.008, name="leiste")
        teil.data.materials.append(leiste)
        teile.append(teil)
    rahmen = _verbinden(teile, "rahmen")

    # Die Bildfläche als eigenes Objekt: eigenes Material, eigene UVs.
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, 0.019, 0),
                                     rotation=(math.radians(90), 0, 0))
    flaeche = bpy.context.active_object
    flaeche.name = "bild"
    flaeche.scale = (0.44, 0.60, 1.0)
    bpy.ops.object.transform_apply(scale=True)
    flaeche.data.materials.append(bildflaeche)
    _export([rahmen, flaeche], "bilderrahmen")


def pendellampe():
    """Wirtshauslampe: Kabel, Baldachin, Emailleschirm. Der Schirm leuchtet
    von innen — die Kulisse hängt das eigentliche Licht darunter.

    Sichtbare Leuchten sind der billigste Realismus-Gewinn in einem Raum:
    ein warmer Fleck ohne Lampe darüber wirkt wie ein Fehler."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    dunkel = _material("lampenblech", (0.11, 0.10, 0.09), rauheit=0.4)
    innen = _material("lampeninnen", (1.0, 0.94, 0.80), rauheit=0.6)
    bsdf = innen.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Emission Color"].default_value = (1.0, 0.86, 0.62, 1.0)
    bsdf.inputs["Emission Strength"].default_value = 2.4

    teile = [
        _rohr(0.016, 0.06, (0, 0, -0.02), dunkel, seiten=12, name="baldachin"),
        _rohr(0.005, 0.42, (0, 0, -0.24), dunkel, seiten=6, name="kabel"),
    ]
    bpy.ops.mesh.primitive_cone_add(radius1=0.17, radius2=0.055, depth=0.15,
                                    location=(0, 0, -0.52), vertices=24)
    schirm = bpy.context.active_object
    schirm.name = "schirm"
    schirm.data.materials.append(dunkel)
    bpy.ops.object.shade_smooth()
    teile.append(schirm)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.055, segments=16, ring_count=8,
                                         location=(0, 0, -0.575))
    birne = bpy.context.active_object
    birne.name = "birne"
    birne.data.materials.append(innen)
    bpy.ops.object.shade_smooth()
    teile.append(birne)
    _export([_verbinden(teile, "pendellampe")], "pendellampe")


def wurfball():
    """Der Jahrmarktsball: rotes Leder mit umlaufenden Nähten. Die Nähte
    sind zwei flache Ringe — an ihnen sieht man, dass der Ball *rollt*.
    Eine glatte Kugel dreht sich unsichtbar."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    leder = _material("leder", (0.62, 0.16, 0.13), rauheit=0.65)
    naht = _material("naht", (0.86, 0.80, 0.68), rauheit=0.8)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.055, segments=20, ring_count=12)
    ball = bpy.context.active_object
    ball.name = "ball"
    ball.data.materials.append(leder)
    bpy.ops.object.shade_smooth()
    teile = [ball]
    for drehung in ((0, 0, 0), (math.radians(90), 0, 0)):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.0545, minor_radius=0.0035,
                                         rotation=drehung,
                                         major_segments=24, minor_segments=6)
        ring = bpy.context.active_object
        ring.name = "naht"
        ring.data.materials.append(naht)
        bpy.ops.object.shade_smooth()
        teile.append(ring)
    _export([_verbinden(teile, "wurfball")], "wurfball")


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
    gerippte()
    tresen()
    wandbilder()
    bilderrahmen()
    pendellampe()
    wurfball()
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
