#!/usr/bin/env python3
"""Baut den ICE für die Zug-Zwischenszene in Kapitel 2.

    python3 tools/make_zug.py            # baut assets/props/ice.glb
    python3 tools/make_zug.py vorschau   # zusätzlich Cycles-Vorschaubilder

Ein ICE ist an drei Dingen erkennbar: der lange weiße Leib, der rote
Streifen unter dem Fensterband und die heruntergezogene Nase. Genau die
drei werden gebaut — der Rest (Drehgestelle, Dachgeräte, Stromabnehmer)
ist Silhouettenfüllung.

Konstruktion: eine Wagenkasten-**Kontur** (Boden, Seitenwand, gerundetes
Dach) wird als Punktring entlang der Fahrtrichtung ausgelegt; die Nase
entsteht als Brücke über fünf schrumpfende, absinkende Ringe (Quads von
Hand, kein bridge-Operator — der stolpert headless über den Kontext).
Fensterband und Streifen sind schmale Kästen, einen Zentimeter vor der
Wand: Geometrie statt Textur, wie bei allen Requisiten des Projekts.

Achsen wie im übrigen Fuhrpark: gebaut in Blender (Z hoch) mit **Front
nach −Y**, der Export dreht auf Y hoch — in Godot schaut der Zug damit
nach **+Z** und fährt mit `rotation.y = PI/2` in +X. Ursprung: Gleismitte
auf Schienenoberkante.
"""

import math
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_props import (  # noqa: E402
    _exportieren, _fase, _glatt, _kasten, _leeren, _material, _zuweisen,
    _zylinder,
)

## Wagenkasten-Maße (Meter): ICE-3-Proportionen, leicht gestaucht.
BREITE = 2.95
DACH = 3.90        # Scheitel über Schienenoberkante
SCHULTER = 2.95    # ab hier rundet die Seitenwand ins Dach
BODEN = 0.55       # Unterkante Kasten (darunter Schürze und Drehgestelle)
KOPF_LAENGE = 20.0
WAGEN_LAENGE = 24.0
FUGE = 0.7         # Lücke zwischen den Wagen

## Die Nase: fünf Ringe von der vollen Kontur bis zur Spitze.
## Je Ring: (Abstand vom Kastenende, Breitenfaktor, Dachhöhe, Bodenhöhe)
NASE = [
    (0.0, 1.00, DACH, BODEN),
    (1.7, 0.96, 3.52, BODEN),
    (3.0, 0.80, 2.80, 0.60),
    (4.0, 0.54, 2.02, 0.70),
    (4.6, 0.26, 1.38, 0.86),
]


def _kontur(faktor: float, dach: float, boden: float):
    """Punktring der Kastenkontur in der XZ-Ebene (x quer, z hoch),
    gegen den Uhrzeigersinn. Acht Punkte je Seite reichen für die Rundung."""
    b = BREITE * 0.5 * faktor
    schulter = boden + (SCHULTER - BODEN) * (dach - boden) / (DACH - BODEN)
    punkte = []
    # rechte Seite hoch (x > 0), dann Dachbogen, dann linke Seite runter.
    punkte.append((b, boden))
    punkte.append((b, schulter))
    for t in (0.30, 0.60, 0.85):
        w = t * math.pi / 2.0
        punkte.append((b * math.cos(w),
                       schulter + (dach - schulter) * math.sin(w)))
    punkte.append((0.0, dach))
    for x, z in reversed(punkte[:-1]):
        punkte.append((-x, z))
    return punkte


def _leib(name, laenge, nase_vorn, nase_hinten):
    """Wagenkasten von y=0 (hinten) bis y=−laenge (vorn). Nasen ersetzen
    das jeweilige Ende durch die Ringbrücke; gerade Enden werden gedeckelt."""
    ringe = []   # (y, faktor, dach, boden)
    if nase_hinten:
        for abstand, faktor, dach, boden in reversed(NASE):
            ringe.append((-abstand, faktor, dach, boden))
    else:
        ringe.append((0.0, 1.0, DACH, BODEN))
    kasten_hinten = -NASE[-1][0] if nase_hinten else 0.0
    kasten_vorn = -(laenge - NASE[-1][0]) if nase_vorn else -laenge
    # das gerade Stück
    ringe.insert(0 if nase_hinten else len(ringe),
                 (kasten_hinten, 1.0, DACH, BODEN))
    ringe.append((kasten_vorn, 1.0, DACH, BODEN))
    if nase_vorn:
        for abstand, faktor, dach, boden in NASE[1:]:
            ringe.append((kasten_vorn - abstand, faktor, dach, boden))

    # Ringe, die doppelt bei y=0/kasten liegen, ausdünnen
    ringe = [r for i, r in enumerate(ringe)
             if i == 0 or abs(r[0] - ringe[i - 1][0]) > 0.01]

    verts = []
    faces = []
    n = len(_kontur(1.0, DACH, BODEN))
    for y, faktor, dach, boden in ringe:
        for x, z in _kontur(faktor, dach, boden):
            verts.append((x, y, z))
    for r in range(len(ringe) - 1):
        a = r * n
        b = (r + 1) * n
        for i in range(n - 1):
            faces.append((a + i, a + i + 1, b + i + 1, b + i))
        faces.append((a + n - 1, a, b, b + n - 1))
    # Deckel vorn und hinten (n-Gons; Blender trianguliert beim Export).
    faces.append(tuple(range(n - 1, -1, -1)))
    faces.append(tuple(range((len(ringe) - 1) * n, len(ringe) * n)))

    netz = bpy.data.meshes.new(name)
    netz.from_pydata(verts, [], faces)
    netz.update()
    obj = bpy.data.objects.new(name, netz)
    bpy.context.collection.objects.link(obj)
    _zuweisen(obj, _material("ice_weiss", (0.93, 0.93, 0.94), rauheit=0.35))
    _glatt(obj, 38.0)
    return obj


def _kasten_gedreht(masse, ort, material, drehung, fase=0.01):
    """Kasten mit Drehung. make_props._kasten bakt die Ablage ins Netz
    (transform_apply nimmt in Blender standardmäßig auch die Position mit) —
    eine nachträgliche Drehung liefe dann um den Weltursprung. Also am
    Ursprung bauen und Ort/Drehung als Objekt-Transform setzen."""
    obj = _kasten(masse, (0.0, 0.0, 0.0), material, fase=fase)
    obj.rotation_euler = drehung
    obj.location = ort
    return obj


def _streifen(y_von, y_bis, rot, fenster):
    """Roter Streifen und **einzelne Fenster** statt des durchgehenden
    Bandes, beidseitig, einen Zentimeter vor der Wand — ein Band ohne
    Unterteilung las sich als Zierstreifen, nicht als Fensterreihe."""
    laenge = abs(y_bis - y_von)
    mitte_y = (y_von + y_bis) * 0.5
    for seite in (1.0, -1.0):
        x = seite * (BREITE * 0.5 + 0.012)
        _kasten((0.02, laenge, 0.20), (x, mitte_y, 1.66), rot, fase=0.0)
    _fensterreihe(y_von, y_bis, fenster)


def _fensterreihe(y_von, y_bis, fenster):
    """Einzelfenster im 2,1-m-Raster, mittig im Abschnitt verteilt."""
    lo, hi = min(y_von, y_bis), max(y_von, y_bis)
    laenge = hi - lo
    anzahl = max(int((laenge - 0.8) / 2.1), 1)
    start = lo + (laenge - (anzahl - 1) * 2.1) * 0.5
    for seite in (1.0, -1.0):
        x = seite * (BREITE * 0.5 + 0.012)
        for i in range(anzahl):
            _kasten((0.02, 1.30, 0.58), (x, start + i * 2.1, 2.42),
                    fenster, fase=0.0)


def _tueren(y, dunkel):
    for seite in (1.0, -1.0):
        x = seite * (BREITE * 0.5 + 0.008)
        _kasten((0.02, 1.30, 2.10), (x, y, 1.70), dunkel, fase=0.0)


def _drehgestell(y, dunkel, stahl):
    _kasten((2.2, 2.6, 0.5), (0.0, y, 0.45), dunkel, fase=0.02)
    for dy in (-0.85, 0.85):
        rad = _zylinder(0.46, 2.1, (0.0, y + dy, 0.46), stahl,
                        fase=0.02, seiten=18)
        rad.rotation_euler = (0.0, math.pi / 2.0, 0.0)


def _schuerze(y_von, y_bis, grau):
    laenge = abs(y_bis - y_von)
    _kasten((BREITE - 0.35, laenge, 0.34), (0.0, (y_von + y_bis) * 0.5, 0.36),
            grau, fase=0.015)


def _dachgeraete(y_von, y_bis, grau):
    laenge = abs(y_bis - y_von)
    _kasten((1.7, laenge, 0.10), (0.0, (y_von + y_bis) * 0.5, DACH + 0.02),
            grau, fase=0.01)


def _stromabnehmer(y, dunkel):
    """Halbschere: zwei angewinkelte Arme, oben die Wippe."""
    fuss = DACH + 0.06
    _kasten((1.0, 1.6, 0.10), (0.0, y, fuss), dunkel, fase=0.01)
    _kasten_gedreht((0.06, 1.5, 0.06), (0.0, y + 0.35, fuss + 0.35), dunkel,
                    (math.radians(-28), 0.0, 0.0), fase=0.0)
    _kasten_gedreht((0.05, 1.3, 0.05), (0.0, y - 0.25, fuss + 0.95), dunkel,
                    (math.radians(42), 0.0, 0.0), fase=0.0)
    _kasten((1.4, 0.08, 0.05), (0.0, y - 0.52, fuss + 1.38), dunkel, fase=0.0)


def _frontscheibe(y_spitze, richtung, fenster):
    """Die dunkle Windschutzscheibe auf der Nasenschräge — `richtung` −1
    für die Front bei −Y, +1 für das gespiegelte Heck. Sie liegt zwischen
    dem zweiten und dritten Nasenring (2,25 m hinter der Spitze) und ist
    dick genug, um sicher durch die Lofthaut zu stoßen."""
    _kasten_gedreht((1.35, 1.45, 0.16),
                    (0.0, y_spitze - richtung * 2.10, 2.42), fenster,
                    (math.radians(42) * richtung, 0.0, 0.0), fase=0.0)


def _licht(y_spitze, richtung, leucht):
    for seite in (-0.34, 0.34):
        _kasten((0.28, 0.30, 0.14),
                (seite, y_spitze - richtung * 0.10, 1.06), leucht, fase=0.01)


def bauen(mit_vorschau=False):
    _leeren()
    rot = _material("ice_rot", (0.72, 0.06, 0.10), rauheit=0.4)
    fenster = _material("ice_fenster", (0.04, 0.05, 0.07), rauheit=0.12, metall=0.3)
    grau = _material("ice_grau", (0.44, 0.45, 0.47), rauheit=0.6)
    dunkel = _material("ice_dunkel", (0.10, 0.10, 0.11), rauheit=0.7)
    stahl = _material("ice_stahl", (0.30, 0.30, 0.32), rauheit=0.4, metall=0.6)
    leucht = _material("ice_licht", (0.95, 0.92, 0.80), rauheit=0.3,
                       leuchten=(1.0, 0.95, 0.75), staerke=2.0)

    gesamt = 2 * KOPF_LAENGE + 2 * WAGEN_LAENGE + 3 * FUGE
    vorn = -gesamt * 0.5   # Nasenspitze des vorderen Triebkopfs

    # Vorderer Triebkopf: Nase nach −Y.
    kopf_v = _leib("kopf_vorn", KOPF_LAENGE, True, False)
    kopf_v.location = (0.0, vorn + KOPF_LAENGE, 0.0)
    _streifen(vorn + 6.5, vorn + KOPF_LAENGE, rot, fenster)
    _frontscheibe(vorn, -1.0, fenster)
    _licht(vorn, -1.0, leucht)
    _drehgestell(vorn + 6.6, dunkel, stahl)
    _drehgestell(vorn + 16.6, dunkel, stahl)
    _schuerze(vorn + 5.2, vorn + KOPF_LAENGE, grau)
    _dachgeraete(vorn + 8.0, vorn + KOPF_LAENGE - 1.0, grau)

    # Zwei Mittelwagen.
    y = vorn + KOPF_LAENGE + FUGE
    for nr in range(2):
        wagen = _leib("wagen_%d" % (nr + 1), WAGEN_LAENGE, False, False)
        wagen.location = (0.0, y + WAGEN_LAENGE, 0.0)
        _streifen(y + 0.2, y + WAGEN_LAENGE - 0.2, rot, fenster)
        _tueren(y + 1.6, fenster)
        _tueren(y + WAGEN_LAENGE - 1.6, fenster)
        _drehgestell(y + 3.0, dunkel, stahl)
        _drehgestell(y + WAGEN_LAENGE - 3.0, dunkel, stahl)
        _schuerze(y + 0.2, y + WAGEN_LAENGE - 0.2, grau)
        _dachgeraete(y + 2.0, y + WAGEN_LAENGE - 2.0, grau)
        if nr == 0:
            _stromabnehmer(y + WAGEN_LAENGE * 0.5, dunkel)
        y += WAGEN_LAENGE + FUGE

    # Hinterer Triebkopf: derselbe Leib wie vorn, als Objekt um 180°
    # gedreht — der gespiegelte Loft (nase_hinten) kollabierte beim
    # Export zu einer flachen Platte, deshalb fehlte der letzte Wagen.
    kopf_h = _leib("kopf_hinten", KOPF_LAENGE, True, False)
    kopf_h.rotation_euler = (0.0, 0.0, math.pi)
    kopf_h.location = (0.0, y, 0.0)
    hinten = y + KOPF_LAENGE
    _streifen(y, hinten - 6.5, rot, fenster)
    _frontscheibe(hinten, 1.0, fenster)
    _licht(hinten, 1.0, leucht)
    _drehgestell(y + 3.4, dunkel, stahl)
    _drehgestell(y + 13.4, dunkel, stahl)
    _schuerze(y, hinten - 5.2, grau)
    _dachgeraete(y + 1.0, hinten - 8.0, grau)

    if mit_vorschau:
        _vorschau(Path("/tmp/zug/ice_seite.png"), (18.0, vorn + 6.0, 3.0),
                  (0.0, vorn + 10.0, 2.0))
        _vorschau(Path("/tmp/zug/ice_front.png"), (7.0, vorn - 14.0, 2.6),
                  (0.0, vorn + 4.0, 2.2))

    bpy.ops.object.select_all(action="SELECT")
    _exportieren("ice")


def _vorschau(pfad, ort, ziel):
    szene = bpy.context.scene
    bpy.ops.object.camera_add(location=ort)
    kamera = bpy.context.active_object
    blick = (bpy.context.view_layer.objects.active.location)  # placeholder
    # Kamera aufs Ziel richten.
    import mathutils
    richtung = mathutils.Vector(ziel) - mathutils.Vector(ort)
    kamera.rotation_euler = richtung.to_track_quat("-Z", "Y").to_euler()
    szene.camera = kamera
    bpy.ops.object.light_add(type="SUN", location=(6, -8, 14))
    licht = bpy.context.active_object
    licht.data.energy = 4.0
    licht.rotation_euler = (math.radians(50), math.radians(-18), 0.3)
    szene.render.engine = "CYCLES"
    szene.cycles.device = "CPU"
    szene.cycles.samples = 16
    szene.render.resolution_x = 800
    szene.render.resolution_y = 420
    szene.world = bpy.data.worlds.new("w") if szene.world is None else szene.world
    szene.world.use_nodes = True
    szene.world.node_tree.nodes["Background"].inputs[0].default_value = (
        0.55, 0.65, 0.8, 1.0)
    pfad.parent.mkdir(parents=True, exist_ok=True)
    szene.render.filepath = str(pfad)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(kamera)
    bpy.data.objects.remove(licht)
    print("  vorschau:", pfad)


if __name__ == "__main__":
    bauen(mit_vorschau=len(sys.argv) > 1 and sys.argv[1] == "vorschau")
    print("fertig")
