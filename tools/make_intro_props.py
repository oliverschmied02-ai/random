#!/usr/bin/env python3
"""Baut die Requisiten der Tinder-Intro in Blender.

    python3 tools/make_intro_props.py

Ein GLB nach assets/intro/: `hand_handy.glb` — Annes rechte Hand mit
Smartphone, aus Kameranähe gesehen. Vier Objekte, damit Godot sie einzeln
ansteuern kann:

* `handy`      — Gehäuse mit Kameranase und Lautsprecherschlitz
* `bildschirm` — die Bildfläche; bekommt in Godot die Viewport-Textur
* `hand`       — Fingerkuppen um die linke Kante, Handballen, Ärmel
* `daumen`     — liegt vor dem Bildschirm und wischt (wird in Godot bewegt)

Achsen wie bei den Requisiten: Z hoch, -Y ist vorn (zur Kamera). Ursprung:
Mitte des Handys. Maße in Metern, das Handy ist 7,2 × 15 cm.
"""

import math
from pathlib import Path

import bpy

ZIEL = Path(__file__).resolve().parent.parent / "assets" / "intro"

# Godot erwartet sRGB, Blender rechnet linear.
def _linear(kanal: float) -> float:
    if kanal <= 0.04045:
        return kanal / 12.92
    return ((kanal + 0.055) / 1.055) ** 2.4


def _farbe(r, g, b):
    return (_linear(r), _linear(g), _linear(b), 1.0)


def _material(name, farbe, rauheit=0.9, metall=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = _farbe(*farbe)
    bsdf.inputs["Roughness"].default_value = rauheit
    bsdf.inputs["Metallic"].default_value = metall
    return mat


def _kasten(masse, ort, fase=0.0, name="teil", drehung=None):
    """Gefaster Kasten; `drehung` sind Euler-Winkel in Grad (XYZ)."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=ort)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = masse
    bpy.ops.object.transform_apply(scale=True)
    if drehung is not None:
        obj.rotation_euler = tuple(math.radians(w) for w in drehung)
    if fase > 0.0:
        mod = obj.modifiers.new("fase", "BEVEL")
        mod.width = fase
        mod.segments = 3
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


def _glaetten(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth()


HAUT = (0.76, 0.56, 0.48)
AERMEL = (0.24, 0.26, 0.19)  # moosgrüner Strick
GEHAEUSE = (0.07, 0.07, 0.08)


def bauen():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    haut = _material("haut", HAUT, rauheit=0.75)
    aermel = _material("aermel", AERMEL, rauheit=0.95)
    gehaeuse = _material("gehaeuse", GEHAEUSE, rauheit=0.35, metall=0.4)
    schirm = _material("bildschirm", (0.02, 0.02, 0.03), rauheit=0.1)

    # --- Handy -------------------------------------------------------------
    koerper = _kasten((0.072, 0.0075, 0.150), (0, 0, 0), fase=0.004, name="handy")
    nase = _kasten((0.020, 0.002, 0.006), (0, -0.0045, 0.068), fase=0.0008,
                   name="nase")  # Frontkamera-Insel oben
    handy = _verbinden([koerper, nase], "handy")
    handy.data.materials.append(gehaeuse)

    # Bildfläche: knapp vor der Front, mit schmalem Rand. +90° um X dreht
    # die Plane-Normale (+Z) auf -Y — nach vorn, zur Kamera.
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, -0.00395, -0.001))
    bildschirm = bpy.context.active_object
    bildschirm.name = "bildschirm"
    bildschirm.scale = (0.066, 0.140, 1.0)
    bildschirm.rotation_euler = (math.radians(90), 0, 0)
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    bildschirm.data.materials.append(schirm)

    # --- Hand ---------------------------------------------------------------
    teile = []
    # Vier Fingerkuppen greifen um die linke Kante (-X): kleine, stark
    # gefaste Kästen, die die Kante umschließen und vorn knapp überstehen.
    for i, hoehe in enumerate((0.050, 0.021, -0.008, -0.037)):
        breite = 0.0155 - i * 0.0004
        teile.append(_kasten((breite, 0.026, 0.0175), (-0.0345, -0.002, hoehe),
                             fase=0.006, name="finger%d" % i,
                             drehung=(0, 0, -4)))
    # Handballen hinter der unteren rechten Ecke.
    teile.append(_kasten((0.052, 0.030, 0.085), (0.043, 0.016, -0.055),
                         fase=0.013, name="ballen"))
    # Handgelenk und Unterarm laufen nach unten rechts aus dem Bild.
    teile.append(_kasten((0.036, 0.032, 0.095), (0.058, 0.013, -0.132),
                         fase=0.012, name="gelenk", drehung=(4, 14, 0)))
    hand = _verbinden(teile, "hand")
    hand.data.materials.append(haut)
    _glaetten(hand)

    # Ärmel: Strickbund über dem Unterarm, läuft unten aus dem Bild.
    puls = _kasten((0.058, 0.050, 0.10), (0.072, 0.014, -0.20),
                   fase=0.014, name="aermel", drehung=(4, 14, 0))
    puls.data.materials.append(aermel)
    _glaetten(puls)
    hand = _verbinden([hand, puls], "hand")

    # --- Daumen (eigenes Objekt, wird in Godot animiert) --------------------
    # Wurzel unten rechts, Kuppe zeigt über die untere Bildschirmhälfte
    # nach oben links. Drehung um Y neigt die Glieder in der Bildebene.
    wurzel = _kasten((0.019, 0.017, 0.046), (0.031, -0.011, -0.056),
                     fase=0.0075, name="daumenwurzel", drehung=(0, -32, 0))
    kuppe = _kasten((0.0165, 0.0145, 0.038), (0.012, -0.0135, -0.034),
                    fase=0.0065, name="daumenkuppe", drehung=(0, -56, 0))
    daumen = _verbinden([wurzel, kuppe], "daumen")
    daumen.data.materials.append(haut)
    _glaetten(daumen)

    ZIEL.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(ZIEL / "hand_handy.glb"),
                              export_apply=True, export_yup=True,
                              use_selection=True)
    print("  intro/hand_handy.glb")


if __name__ == "__main__":
    bauen()
    print("fertig")
