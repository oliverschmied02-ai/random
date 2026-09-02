#!/usr/bin/env python3
"""Baut Schatztruhe und Rucksack für das Finale von Kapitel 3.

    python3 tools/make_truhe.py            # truhe.glb + rucksack.glb
    python3 tools/make_truhe.py vorschau   # zusätzlich Cycles-Vorschau

**Truhe** (`assets/hochzeit/truhe.glb`): Holzbretter-Korpus mit dunklen
Metallbeschlägen, gewölbter Deckel, Vorhängeschloss. Drei benannte
Objekte, weil das Spiel sie einzeln bewegt:

* `korpus` — steht still.
* `deckel` — sein Ursprung liegt auf der **Scharnierlinie** (hintere
  Oberkante); im Spiel öffnet ihn eine Drehung um die lokale X-Achse.
* `schloss` — Ursprung an der Öse vorn; es fällt beim Öffnen ab.

**Rucksack** (`assets/hochzeit/rucksack.glb`): Wanderrucksack mit
Deckelklappe, Fronttasche, Schultergurten und Schnallen — er schwebt am
Ende aus der Truhe. Ursprung mittig unten.

Achsen: gebaut in Blender (Z hoch, Front der Truhe nach −Y); der Export
dreht auf Y hoch — in Godot schaut die Truhenfront damit nach +Z.
"""

import math
import sys
from pathlib import Path

import bpy
import mathutils

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_props import (  # noqa: E402
    _fase, _glatt, _kasten, _leeren, _material, _zuweisen, _zylinder,
)

ZIEL = Path(__file__).resolve().parent.parent / "assets" / "hochzeit"

## Truhenmaße (Meter): Breite (X), Tiefe (Y), Korpushöhe (Z).
BREITE = 0.92
TIEFE = 0.54
KORPUS = 0.40


def _verbinden(teile, name):
    bpy.ops.object.select_all(action="DESELECT")
    for teil in teile:
        teil.select_set(True)
    bpy.context.view_layer.objects.active = teile[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    return obj


def _pivot_setzen(obj, pivot):
    """Verschiebt den Objektursprung auf `pivot` (Weltkoordinaten), ohne
    das Netz zu bewegen — die Helfer aus make_props baken ihre Ablage ins
    Netz, deshalb liegt der Ursprung sonst im Weltnullpunkt."""
    p = mathutils.Vector(pivot)
    obj.data.transform(mathutils.Matrix.Translation(-p))
    obj.location = p


def truhe_bauen(holz, metall, dunkel):
    teile = []
    # Korpus aus fünf liegenden Brettern je Seite — die Fugen erzählen
    # „Bretter", eine glatte Kiste erzählt „Karton".
    brett_h = KORPUS / 5.0
    for i in range(5):
        z = brett_h * (i + 0.5)
        teile.append(_kasten((BREITE, TIEFE, brett_h - 0.008),
                             (0, 0, z), holz, fase=0.006))
    # Boden- und Deckrahmen plus Eckwinkel aus dunklem Metall.
    for z in (0.02, KORPUS - 0.02):
        teile.append(_kasten((BREITE + 0.02, TIEFE + 0.02, 0.035),
                             (0, 0, z), metall, fase=0.004))
    for sx in (-1, 1):
        for sy in (-1, 1):
            teile.append(_kasten((0.05, 0.05, KORPUS),
                                 (sx * (BREITE / 2 - 0.01),
                                  sy * (TIEFE / 2 - 0.01), KORPUS / 2),
                                 metall, fase=0.004))
    # Schließblech vorn mittig, mit Öse fürs Schloss.
    teile.append(_kasten((0.16, 0.02, 0.12),
                         (0, -TIEFE / 2 - 0.008, KORPUS - 0.06),
                         metall, fase=0.004))
    korpus = _verbinden(teile, "korpus")
    _pivot_setzen(korpus, (0, 0, 0))

    # Deckel: gewölbt — fünf schmale Bretter als Bogensegmente zwischen
    # zwei halbrunden Seitenwangen. Radius = halbe Tiefe.
    radius = TIEFE / 2.0
    dteile = []
    for i in range(5):
        w0 = math.pi * (i + 0.5) / 5.0
        # Brett am Ursprung bauen (Dicke entlang Z = radial nach der
        # Drehung), dann aufs Bogensegment drehen und an seinen Platz
        # schieben — die make_props-Helfer baken ihre Ablage ins Netz,
        # deshalb läuft beides über die Netzdaten.
        brett = _kasten((BREITE, math.pi * radius / 5.0 * 0.92, 0.05),
                        (0, 0, 0), holz, fase=0.005)
        m = (mathutils.Matrix.Translation(
                (0, math.cos(w0) * radius * 0.82,
                 KORPUS + math.sin(w0) * radius * 0.82))
             @ mathutils.Matrix.Rotation(w0 - math.pi / 2.0, 4, "X"))
        brett.data.transform(m)
        dteile.append(brett)
    # Seitenwangen und Mittelband: **halbe** Scheiben — volle steckten
    # geschlossen unsichtbar im Korpus, aber ein geöffneter Deckel sähe
    # aus wie eine ganze Tonne.
    for sx in (-1, 1):
        wange = _zylinder(radius * 0.82, 0.05,
                          (sx * (BREITE / 2 - 0.028), 0, KORPUS),
                          holz, fase=0.004, seiten=18)
        wange.rotation_euler = (0, math.pi / 2.0, 0)
        _halbieren(wange, KORPUS - 0.01)
        dteile.append(wange)
    band = _zylinder(radius * 0.86, 0.06, (0, 0, KORPUS), metall,
                     fase=0.003, seiten=18)
    band.rotation_euler = (0, math.pi / 2.0, 0)
    _halbieren(band, KORPUS - 0.01)
    dteile.append(band)
    # Deckel-Öse vorn (überlappt das Schließblech, wenn zu).
    dteile.append(_kasten((0.10, 0.02, 0.08),
                          (0, -TIEFE / 2 - 0.006, KORPUS + 0.02),
                          metall, fase=0.003))
    deckel = _rotierte_teile_verbinden(dteile, "deckel")
    _pivot_setzen(deckel, (0, TIEFE / 2.0, KORPUS))

    # Vorhängeschloss: Körper mit Fase, Bügel aus gebogenem Torus-Stück.
    steile = []
    steile.append(_kasten((0.09, 0.035, 0.11),
                          (0, -TIEFE / 2 - 0.03, KORPUS - 0.10),
                          dunkel, fase=0.012))
    steile.append(_kasten((0.016, 0.01, 0.035),
                          (0, -TIEFE / 2 - 0.05, KORPUS - 0.115),
                          metall, fase=0.002))
    buegel = _torus(0.032, 0.009, (0, -TIEFE / 2 - 0.03, KORPUS - 0.045),
                    metall)
    steile.append(buegel)
    schloss = _rotierte_teile_verbinden(steile, "schloss")
    _pivot_setzen(schloss, (0, -TIEFE / 2.0 - 0.03, KORPUS - 0.02))
    return korpus, deckel, schloss


def _rotierte_teile_verbinden(teile, name):
    """Wie _verbinden, aber wendet vorher die Objektrotationen an —
    die Helfer setzen `rotation_euler` erst nach dem Scale-Baken."""
    for teil in teile:
        bpy.ops.object.select_all(action="DESELECT")
        teil.select_set(True)
        bpy.context.view_layer.objects.active = teil
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return _verbinden(teile, name)


def _halbieren(obj, z_schnitt):
    """Schneidet alles unterhalb `z_schnitt` weg (Weltkoordinaten) und
    deckelt die Schnittfläche. Rotation wird vorher angewendet."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.bisect(plane_co=(0.0, 0.0, z_schnitt),
                        plane_no=(0.0, 0.0, -1.0),
                        clear_inner=True, use_fill=True)
    bpy.ops.object.mode_set(mode="OBJECT")


def _torus(radius, dicke, ort, material):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=radius, minor_radius=dicke, location=ort,
        major_segments=20, minor_segments=8)
    obj = bpy.context.active_object
    obj.rotation_euler = (0, math.pi / 2.0, 0)
    _zuweisen(obj, material)
    _glatt(obj)
    return obj


def rucksack_bauen():
    """Der echte Rucksack: ein Kapten & Son in Weiß-Creme — hochkantiger
    Korpus, große glatte Überschlag-Klappe mit Schlaufe darunter,
    Tragegriff, Seitenriemen. Zweifarbig wie das Original: die Klappe
    und das obere Frontpanel glattes Kunstleder, der Rest Canvas."""
    canvas = _material("rucksack_canvas", (0.85, 0.82, 0.75), rauheit=0.88)
    glatt = _material("rucksack_glatt", (0.90, 0.87, 0.81), rauheit=0.48)
    gurt = _material("rucksack_gurt", (0.87, 0.84, 0.77), rauheit=0.9)
    logo_grau = _material("rucksack_logo", (0.38, 0.41, 0.44), rauheit=0.6)
    teile = []
    # Klappenebene zuerst — der Korpus wird gleich daran abgeschrägt.
    klappen_tilt = 0.30
    klappen_mitte = mathutils.Vector((0, -0.02, 0.462))
    klappen_normale = (mathutils.Euler((klappen_tilt, 0, 0)).to_matrix()
                       @ mathutils.Vector((0, 0, 1)))

    # Hauptkorpus: hochkant und kastig, nur weich angefast. Oben wird er
    # entlang der Klappenebene abgeschrägt, damit die Klappe aufliegt wie
    # beim Original, statt dass die vordere Oberkante durchsticht.
    korpus = _kasten((0.34, 0.23, 0.52), (0, 0, 0.26), canvas, fase=0.0)
    _fase(korpus, 0.045, 4)
    bpy.ops.object.select_all(action="DESELECT")
    korpus.select_set(True)
    bpy.context.view_layer.objects.active = korpus
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    # clear_outer entfernt die Seite in Normalenrichtung (empirisch
    # geprüft: clear_inner behält sie) — hier also alles ÜBER der Ebene.
    bpy.ops.mesh.bisect(
        plane_co=tuple(klappen_mitte + klappen_normale * -0.008),
        plane_no=tuple(klappen_normale), clear_outer=True, use_fill=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    teile.append(korpus)
    # Oberes Frontpanel in glattem Kunstleder, minimal vor dem Korpus.
    panel = _kasten((0.315, 0.016, 0.20), (0, -0.118, 0.335), glatt, fase=0.0)
    _fase(panel, 0.007, 3)
    teile.append(panel)
    # Die Überschlag-Klappe: eine große, dünne Platte, die nach vorn
    # abfällt und über die Kanten hinausragt — das Markenzeichen.
    # Hinterkante liegt auf der Korpus-Oberkante auf, die Vorderkante
    # fällt bis auf gut 80 % der Höhe — wie beim Original. Gedrehte Teile
    # werden am Ursprung gebaut und per Objekt-Transform platziert: die
    # _kasten-Helfer baken ihre Ablage ins Netz, eine danach gesetzte
    # Drehung drehte sonst um den Weltursprung.
    klappe = _kasten((0.37, 0.26, 0.022), (0, 0, 0), glatt, fase=0.0)
    _fase(klappe, 0.009, 3)
    klappe.location = klappen_mitte
    klappe.rotation_euler = (klappen_tilt, 0, 0)
    teile.append(klappe)
    # Die kleine Schlaufe unter der Klappenkante.
    teile.append(_kasten((0.036, 0.014, 0.085), (0, -0.175, 0.335),
                         gurt, fase=0.005))
    # Tragegriff: taucht direkt an der Klappen-Hinterkante auf, wie beim
    # Original, und lehnt sich leicht zurück.
    griff = _kasten((0.13, 0.026, 0.024), (0, 0, 0), gurt, fase=0.008)
    griff.location = (0, 0.135, 0.575)
    griff.rotation_euler = (0.35, 0, 0)
    teile.append(griff)
    for sx in (-0.055, 0.055):
        stuetze = _kasten((0.024, 0.026, 0.085), (0, 0, 0), gurt, fase=0.006)
        stuetze.location = (sx, 0.148, 0.528)
        stuetze.rotation_euler = (0.35, 0, 0)
        teile.append(stuetze)
    # Seitenriemen (Kompressionsband), eng am Korpus.
    for sx in (-0.172, 0.172):
        teile.append(_kasten((0.012, 0.24, 0.03), (sx, 0.0, 0.42),
                             gurt, fase=0.004))
    # Schultergurte hinten (+Y): je zwei Segmente, dicht am Korpus.
    for sx in (-0.09, 0.09):
        oben = _kasten((0.07, 0.022, 0.20), (0, 0, 0), gurt, fase=0.008)
        oben.location = (sx, 0.122, 0.40)
        oben.rotation_euler = (math.radians(14), 0, 0)
        teile.append(oben)
        unten = _kasten((0.07, 0.022, 0.18), (0, 0, 0), gurt, fase=0.008)
        unten.location = (sx, 0.132, 0.17)
        unten.rotation_euler = (math.radians(-10), 0, 0)
        teile.append(unten)
    # Der Schriftzug auf der Klappe — flach ins geneigte Klappen-Deck
    # gelegt, knapp über der Vorderkante wie beim Original.
    bpy.ops.object.text_add()
    text = bpy.context.active_object
    text.data.body = "KAPTEN & SON"
    text.data.size = 0.0225
    text.data.extrude = 0.0016
    text.data.align_x = "CENTER"
    text.data.align_y = "CENTER"
    drehung = mathutils.Euler((klappen_tilt, 0, 0)).to_matrix()
    text.location = (klappen_mitte
                     + drehung @ mathutils.Vector((0, -0.06, 0.0135)))
    text.rotation_euler = (klappen_tilt, 0, 0)
    bpy.ops.object.convert(target="MESH")
    text = bpy.context.active_object
    _zuweisen(text, logo_grau)
    teile.append(text)
    rucksack = _rotierte_teile_verbinden(teile, "rucksack")
    _pivot_setzen(rucksack, (0, 0, 0))
    return rucksack


def _vorschau(pfad, ort, blick):
    szene = bpy.context.scene
    bpy.ops.object.camera_add(location=ort)
    kamera = bpy.context.active_object
    richtung = mathutils.Vector(blick) - mathutils.Vector(ort)
    kamera.rotation_euler = richtung.to_track_quat("-Z", "Y").to_euler()
    szene.camera = kamera
    bpy.ops.object.light_add(type="SUN", location=(2, -3, 4))
    licht = bpy.context.active_object
    licht.data.energy = 3.5
    licht.rotation_euler = (math.radians(50), math.radians(-15), 0.4)
    szene.render.engine = "CYCLES"
    szene.cycles.device = "CPU"
    szene.cycles.samples = 20
    szene.render.resolution_x = 760
    szene.render.resolution_y = 420
    if szene.world is None:
        szene.world = bpy.data.worlds.new("w")
    szene.world.use_nodes = True
    szene.world.node_tree.nodes["Background"].inputs[0].default_value = (
        0.5, 0.6, 0.7, 1.0)
    pfad.parent.mkdir(parents=True, exist_ok=True)
    szene.render.filepath = str(pfad)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(kamera)
    bpy.data.objects.remove(licht)
    print("  vorschau:", pfad)


def bauen(mit_vorschau=False):
    ZIEL.mkdir(parents=True, exist_ok=True)

    _leeren()
    holz = _material("truhe_holz", (0.42, 0.28, 0.16), rauheit=0.8)
    metall = _material("truhe_metall", (0.22, 0.20, 0.18), rauheit=0.45,
                       metall=0.7)
    dunkel = _material("truhe_schloss", (0.55, 0.48, 0.22), rauheit=0.35,
                       metall=0.8)
    korpus, deckel, schloss = truhe_bauen(holz, metall, dunkel)
    if mit_vorschau:
        _vorschau(Path("/tmp/truhe/truhe.png"), (1.3, -1.5, 0.9),
                  (0, 0, 0.35))
    bpy.ops.object.select_all(action="DESELECT")
    for o in (korpus, deckel, schloss):
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(ZIEL / "truhe.glb"),
                              export_apply=True, export_yup=True,
                              use_selection=True)
    print("  hochzeit/truhe.glb")

    _leeren()
    rucksack = rucksack_bauen()
    if mit_vorschau:
        _vorschau(Path("/tmp/truhe/rucksack.png"), (0.45, -0.95, 0.62),
                  (0, 0, 0.32))
    bpy.ops.object.select_all(action="DESELECT")
    rucksack.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(ZIEL / "rucksack.glb"),
                              export_apply=True, export_yup=True,
                              use_selection=True)
    print("  hochzeit/rucksack.glb")


if __name__ == "__main__":
    bauen(mit_vorschau=len(sys.argv) > 1 and sys.argv[1] == "vorschau")
    print("fertig")
