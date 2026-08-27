#!/usr/bin/env python3
"""Baut die Straßenfahrzeuge für die Autobahn — als echte Karosserien.

    python3 tools/make_fahrzeuge.py

Das alte `auto` (gefaster Quader + Glaskuppel) liest sich aus der
LKW-Kabine als Spielzeug. Eine glaubwürdige Karosserie entsteht hier
aus **Querschnitts-Lofts**: entlang der Fahrzeuglänge werden gerundete
Rechteckringe aufgespannt (Stoßfänger, Haube, Scheibenansatz, Dach,
Heck) und zu einer Haut verbunden — einmal für den Rumpf bis zur
Gürtellinie, einmal für das Glashaus darüber. Dazu ausgeschnittene
Radkästen (Boolean), Räder mit Felgenspeichen, Spiegel, Türfugen,
Leuchten und Kennzeichen.

Drei Varianten:
* `auto_limo.glb`  — Stufenheck-Limousine
* `auto_kombi.glb` — Kombi (Dachlinie läuft bis zum Heck)
* `auto_van.glb`   — weißer Kastenwagen (Sprinter-Silhouette)

Der Lack heißt in allen Varianten `autolack` — das Fahrspiel färbt ihn
pro Instanz über einen Material-Override ein. Front zeigt nach -Y,
wie bei allen Fahrzeugen des Projekts.
"""

import math
from pathlib import Path

import bpy

ZIEL = Path(__file__).resolve().parent.parent / "assets" / "props"


def _leeren():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _material(name, farbe, rauheit=0.6, metall=0.0, leuchten=None, staerke=0.0):
    def linear(k):
        return k / 12.92 if k <= 0.04045 else ((k + 0.055) / 1.055) ** 2.4
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = tuple(linear(k) for k in farbe) + (1.0,)
    bsdf.inputs["Roughness"].default_value = rauheit
    bsdf.inputs["Metallic"].default_value = metall
    if leuchten is not None:
        bsdf.inputs["Emission Color"].default_value = tuple(linear(k) for k in leuchten) + (1.0,)
        bsdf.inputs["Emission Strength"].default_value = staerke
    return mat


def _ring(y, halbbreite, unten, oben, ecken=0.32, n=10):
    """Ein gerundeter Rechteckring bei Längsposition y (Punkte im Uhrzeigersinn).
    `ecken` ist der Rundungsradius als Anteil der Halbbreite."""
    punkte = []
    r = ecken * halbbreite
    mitte_z = (unten + oben) / 2.0
    halb_z = (oben - unten) / 2.0
    rz = min(r, halb_z * 0.8)
    # Vier Ecken als Viertelkreise, gegen den Uhrzeigersinn ab rechts unten.
    for ecke_x, ecke_z, w0 in [(halbbreite - r, unten + rz, -math.pi / 2),
                               (halbbreite - r, oben - rz, 0.0),
                               (-halbbreite + r, oben - rz, math.pi / 2),
                               (-halbbreite + r, unten + rz, math.pi)]:
        for i in range(n // 2):
            w = w0 + (math.pi / 2) * i / (n // 2 - 1)
            punkte.append((ecke_x + math.cos(w) * r, y, ecke_z + math.sin(w) * rz))
    return punkte


def _loft(name, ringe, mat, deckel=True):
    """Verbindet Ringe gleicher Punktzahl zu einer Haut."""
    ecken, flaechen = [], []
    n = len(ringe[0])
    for ring in ringe:
        ecken.extend(ring)
    for j in range(len(ringe) - 1):
        for i in range(n):
            a = j * n + i
            b = j * n + (i + 1) % n
            flaechen.append((a, b, b + n, a + n))
    if deckel:
        flaechen.append(tuple(range(n - 1, -1, -1)))
        start = (len(ringe) - 1) * n
        flaechen.append(tuple(range(start, start + n)))
    netz = bpy.data.meshes.new(name)
    netz.from_pydata(ecken, [], flaechen)
    netz.update()
    obj = bpy.data.objects.new(name, netz)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(48))
    obj.data.materials.append(mat)
    return obj


def _kasten(masse, ort, mat, fase=0.0, name="teil"):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=ort)
    teil = bpy.context.active_object
    teil.name = name
    teil.scale = (masse[0] / 2, masse[1] / 2, masse[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    if fase > 0:
        f = teil.modifiers.new("fase", "BEVEL")
        f.width = fase
        f.segments = 3
        bpy.ops.object.modifier_apply(modifier="fase")
    teil.data.materials.append(mat)
    return teil


def _radkasten_schneiden(rumpf, orte, radius):
    """Schneidet zylindrische Radkästen aus dem Rumpf."""
    for x, y in orte:
        bpy.ops.mesh.primitive_cylinder_add(
            radius=radius, depth=1.0, location=(x, y, 0.30), vertices=24,
            rotation=(0, math.pi / 2, 0))
        messer = bpy.context.active_object
        mod = rumpf.modifiers.new("rad", "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.object = messer
        bpy.context.view_layer.objects.active = rumpf
        bpy.ops.object.modifier_apply(modifier="rad")
        bpy.data.objects.remove(messer)


def _rad(x, y, radius, breite, reifen, felge):
    bpy.ops.mesh.primitive_cylinder_add(
        radius=radius, depth=breite, location=(x, y, radius), vertices=22,
        rotation=(0, math.pi / 2, 0))
    r = bpy.context.active_object
    r.name = "reifen"
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    r.data.materials.append(reifen)
    teile = [r]
    seite = 1.0 if x > 0 else -1.0
    bpy.ops.mesh.primitive_cylinder_add(
        radius=radius * 0.58, depth=0.03,
        location=(x + seite * breite * 0.52, y, radius), vertices=18,
        rotation=(0, math.pi / 2, 0))
    scheibe = bpy.context.active_object
    scheibe.name = "felge"
    scheibe.data.materials.append(felge)
    teile.append(scheibe)
    for i in range(5):
        w = i * math.tau / 5
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(x + seite * breite * 0.54,
                      y + math.cos(w) * radius * 0.30,
                      radius + math.sin(w) * radius * 0.30))
        speiche = bpy.context.active_object
        speiche.scale = (0.012, radius * 0.16, radius * 0.055)
        speiche.rotation_euler.x = w
        bpy.ops.object.transform_apply(scale=True, rotation=True)
        speiche.data.materials.append(felge)
        teile.append(speiche)
    return teile


def _gemeinsam(name, lackfarbe=(0.45, 0.46, 0.48)):
    lack = _material("autolack", lackfarbe, 0.32, 0.5)
    glas = _material("autoglas", (0.06, 0.08, 0.10), 0.12, 0.4)
    schwarz = _material("anbau", (0.10, 0.10, 0.11), 0.7)
    reifen = _material("reifen", (0.045, 0.045, 0.05), 0.9)
    felge = _material("felge", (0.55, 0.57, 0.60), 0.3, 0.8)
    rot = _material("ruecklicht", (0.45, 0.06, 0.05), 0.3, leuchten=(0.9, 0.1, 0.08), staerke=0.5)
    weiss = _material("frontlicht", (0.75, 0.78, 0.82), 0.15, 0.5,
                      leuchten=(0.9, 0.92, 0.95), staerke=0.3)
    schild = _material("kennzeichen", (0.88, 0.89, 0.86), 0.4)
    return lack, glas, schwarz, reifen, felge, rot, weiss, schild


def _abschluss(name):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(ZIEL / f"{name}.glb"),
                              export_apply=True, export_yup=True,
                              use_selection=True)
    print(f"  props/{name}.glb")


def _anbauteile(l, lack, schwarz, rot, weiss, schild, heck_y, front_y, spiegel_y, spiegel_z):
    # Spiegel.
    for seite in (1, -1):
        _kasten((0.16, 0.05, 0.04), (0.86 * seite, spiegel_y, spiegel_z), schwarz)
        _kasten((0.06, 0.18, 0.11), (0.97 * seite, spiegel_y, spiegel_z + 0.02), lack, 0.012)
    # Leuchten und Kennzeichen.
    for ende, mat_l, y in ((1, rot, heck_y), (-1, weiss, front_y)):
        for seite in (1, -1):
            _kasten((0.42, 0.06, 0.14), (0.55 * seite, y * 1.0, 0.82), mat_l, 0.02)
        _kasten((0.52, 0.02, 0.12), (0, y + (0.03 if ende > 0 else -0.03), 0.52), schild)
    # Stoßfänger.
    _kasten((1.78, 0.14, 0.20), (0, front_y - 0.02, 0.44), schwarz, 0.04)
    _kasten((1.78, 0.14, 0.20), (0, heck_y + 0.02, 0.44), schwarz, 0.04)
    # Kühlergrill.
    _kasten((0.9, 0.03, 0.16), (0, front_y - 0.04, 0.66), schwarz, 0.02)


def limousine():
    _leeren()
    lack, glas, schwarz, reifen, felge, rot, weiss, schild = _gemeinsam("limo")
    # Rumpf bis Gürtellinie: Stoßfänger → Haube → Flanke → Heck.
    rumpf = _loft("rumpf", [
        _ring(-2.28, 0.78, 0.42, 0.70, 0.5),
        _ring(-2.10, 0.86, 0.34, 0.80, 0.42),
        _ring(-1.30, 0.88, 0.30, 0.88, 0.36),   # Haube vorn
        _ring(-0.55, 0.90, 0.28, 1.00, 0.34),   # Scheibenansatz
        _ring(0.90, 0.90, 0.28, 1.02, 0.34),    # Flanke
        _ring(1.80, 0.88, 0.30, 0.96, 0.36),    # Kofferraum
        _ring(2.10, 0.84, 0.36, 0.86, 0.42),
        _ring(2.26, 0.76, 0.44, 0.72, 0.5),
    ], lack)
    # Glashaus: Windschutzscheibe schräg, Dach, Heckscheibe.
    _loft("glashaus", [
        _ring(-0.52, 0.80, 0.99, 1.02, 0.5),
        _ring(-0.05, 0.74, 1.00, 1.42, 0.42),
        _ring(0.85, 0.74, 1.00, 1.44, 0.42),
        _ring(1.45, 0.78, 0.99, 1.04, 0.5),
    ], glas)
    _kasten((1.36, 1.15, 0.035), (0, 0.55, 1.45), lack, 0.01, "dach")
    _radkasten_schneiden(rumpf, [(0.8, -1.45), (-0.8, -1.45), (0.8, 1.45), (-0.8, 1.45)], 0.40)
    for x, y in [(0.8, -1.45), (-0.8, -1.45), (0.8, 1.45), (-0.8, 1.45)]:
        _rad(x, y, 0.33, 0.22, reifen, felge)
    _anbauteile(4.5, lack, schwarz, rot, weiss, schild, 2.30, -2.32, -0.50, 1.02)
    _abschluss("auto_limo")


def kombi():
    _leeren()
    lack, glas, schwarz, reifen, felge, rot, weiss, schild = _gemeinsam("kombi")
    rumpf = _loft("rumpf", [
        _ring(-2.28, 0.78, 0.42, 0.70, 0.5),
        _ring(-2.10, 0.86, 0.34, 0.80, 0.42),
        _ring(-1.30, 0.88, 0.30, 0.88, 0.36),
        _ring(-0.55, 0.90, 0.28, 1.00, 0.34),
        _ring(1.60, 0.90, 0.28, 1.02, 0.34),
        _ring(2.30, 0.86, 0.32, 0.98, 0.38),
        _ring(2.42, 0.78, 0.40, 0.80, 0.46),
    ], lack)
    # Dachlinie läuft bis zum Heck durch — das macht den Kombi.
    _loft("glashaus", [
        _ring(-0.52, 0.80, 0.99, 1.02, 0.5),
        _ring(-0.05, 0.75, 1.00, 1.44, 0.42),
        _ring(1.90, 0.75, 1.00, 1.46, 0.42),
        _ring(2.34, 0.78, 0.99, 1.10, 0.46),
    ], glas)
    _kasten((1.38, 2.1, 0.035), (0, 0.9, 1.47), lack, 0.01, "dach")
    for seite in (1, -1):  # Dachreling
        _kasten((0.05, 2.0, 0.06), (0.6 * seite, 0.9, 1.51), schwarz, 0.01)
    _radkasten_schneiden(rumpf, [(0.8, -1.45), (-0.8, -1.45), (0.8, 1.55), (-0.8, 1.55)], 0.40)
    for x, y in [(0.8, -1.45), (-0.8, -1.45), (0.8, 1.55), (-0.8, 1.55)]:
        _rad(x, y, 0.33, 0.22, reifen, felge)
    _anbauteile(4.7, lack, schwarz, rot, weiss, schild, 2.46, -2.32, -0.50, 1.02)
    _abschluss("auto_kombi")


def kastenwagen():
    _leeren()
    lack, glas, schwarz, reifen, felge, rot, weiss, schild = _gemeinsam(
        "van", lackfarbe=(0.88, 0.88, 0.87))
    rumpf = _loft("rumpf", [
        _ring(-2.70, 0.80, 0.44, 0.90, 0.42),
        _ring(-2.45, 0.92, 0.36, 1.10, 0.30),   # kurze Schnauze
        _ring(-2.00, 0.96, 0.32, 1.30, 0.26),
        _ring(-1.55, 0.98, 0.30, 2.10, 0.18),   # Anstieg zum Kasten
        _ring(2.40, 0.98, 0.30, 2.14, 0.16),    # langer Kasten
        _ring(2.62, 0.94, 0.36, 2.02, 0.22),
    ], lack)
    # Fahrerhausglas: Windschutzscheibe und Seitenfenster als dunkles Band.
    _kasten((1.82, 0.05, 0.55), (0, -2.28, 1.62), glas, 0.02, "frontscheibe")
    for seite in (1, -1):
        _kasten((0.06, 0.9, 0.5), (1.00 * seite, -1.75, 1.62), glas, 0.01)
    _radkasten_schneiden(rumpf, [(0.85, -1.85), (-0.85, -1.85), (0.85, 1.75), (-0.85, 1.75)], 0.44)
    for x, y in [(0.85, -1.85), (-0.85, -1.85), (0.85, 1.75), (-0.85, 1.75)]:
        _rad(x, y, 0.36, 0.24, reifen, felge)
    for seite in (1, -1):  # große Transporterspiegel
        _kasten((0.05, 0.06, 0.30), (1.06 * seite, -2.05, 1.75), schwarz, 0.01)
        _kasten((0.16, 0.05, 0.05), (0.95 * seite, -2.05, 1.62), schwarz)
    for seite in (1, -1):
        _kasten((0.42, 0.06, 0.16), (0.55 * seite, 2.66, 1.0), rot, 0.02)
        _kasten((0.42, 0.06, 0.14), (0.6 * seite, -2.73, 0.78), weiss, 0.02)
    _kasten((0.52, 0.02, 0.12), (0, 2.68, 0.5), schild)
    _kasten((0.52, 0.02, 0.12), (0, -2.74, 0.5), schild)
    _kasten((1.95, 0.16, 0.24), (0, -2.68, 0.42), schwarz, 0.04)
    _kasten((1.95, 0.16, 0.24), (0, 2.62, 0.42), schwarz, 0.04)
    _kasten((1.1, 0.03, 0.2), (0, -2.72, 0.85), schwarz, 0.02)  # Grill
    # Hecktür-Fugen als dunkle Linien.
    _kasten((0.02, 0.01, 1.6), (0, 2.68, 1.2), schwarz)
    _abschluss("auto_van")


if __name__ == "__main__":
    limousine()
    kombi()
    kastenwagen()
    print("fertig")
