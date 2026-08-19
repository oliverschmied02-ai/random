#!/usr/bin/env python3
"""Modelliert die Straßenrequisiten in Blender (bpy) und exportiert GLBs.

    python3 tools/make_props.py

Schreibt nach assets/props/: laterne, auto, bank, ampel, muelleimer,
poller, litfass. Alles mit gefasten Kanten und, wo es sich lohnt,
Subdivision — die messerscharfen Quaderkanten waren das letzte laute
„Computergrafik"-Signal der Kulisse.

Konventionen: Y nach oben, Ursprung am Boden in der Mitte, Blick nach -Z
(Godot-Vorne). Maße in Metern. Materialien tragen sprechende Namen, damit
die Kulisse einzelne (z. B. „lampenglas") zur Laufzeit ansteuern kann.
"""

import math
from pathlib import Path

import bpy

WURZEL = Path(__file__).resolve().parent.parent / "assets" / "props"


# --- Grundwerkzeug -----------------------------------------------------------


def _leeren():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _linear(c):
    """sRGB -> linear. Die Farbwerte hier sind als sRGB gemeint (wie die
    Godot-Farben der Kulisse); Blender erwartet im Shader lineare Werte —
    ohne Umrechnung kommen alle Requisiten zu hell heraus."""
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _material(name, farbe, rauheit=0.7, metall=0.0, leuchten=None, staerke=0.0):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*[_linear(v) for v in farbe], 1.0)
    bsdf.inputs["Roughness"].default_value = rauheit
    bsdf.inputs["Metallic"].default_value = metall
    if leuchten is not None:
        bsdf.inputs["Emission Color"].default_value = (*[_linear(v) for v in leuchten], 1.0)
        bsdf.inputs["Emission Strength"].default_value = staerke
    return m


def _zuweisen(obj, material):
    obj.data.materials.clear()
    obj.data.materials.append(material)


def _fase(obj, breite=0.008, segmente=2):
    mod = obj.modifiers.new("fase", "BEVEL")
    mod.width = breite
    mod.segments = segmente
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(40)


def _glatt(obj, winkel=45.0):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(winkel))
    obj.select_set(False)


def _kasten(masse, ort, material, fase=0.008):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=ort)
    obj = bpy.context.active_object
    obj.scale = (masse[0], masse[1], masse[2])
    bpy.ops.object.transform_apply(scale=True)
    if fase > 0:
        _fase(obj, fase)
    _zuweisen(obj, material)
    _glatt(obj)
    return obj


def _zylinder(radius, hoehe, ort, material, fase=0.006, seiten=20, r_oben=None):
    if r_oben is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=seiten, radius=radius,
                                            depth=hoehe, location=ort)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=seiten, radius1=radius,
                                        radius2=r_oben, depth=hoehe, location=ort)
    obj = bpy.context.active_object
    if fase > 0:
        _fase(obj, fase)
    _zuweisen(obj, material)
    _glatt(obj)
    return obj


def _kugel(radius, ort, material, seiten=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seiten, ring_count=seiten // 2,
                                         radius=radius, location=ort)
    obj = bpy.context.active_object
    _zuweisen(obj, material)
    _glatt(obj)
    return obj


def _exportieren(name):
    WURZEL.mkdir(parents=True, exist_ok=True)
    # Blender: Z hoch, -Y vorne. glTF-Export dreht auf Y hoch (+Y up).
    bpy.ops.export_scene.gltf(filepath=str(WURZEL / f"{name}.glb"),
                              export_apply=True, export_yup=True)
    print(f"  props/{name}.glb")


# --- Requisiten ---------------------------------------------------------------
# Gebaut wird in Blender-Achsen (Z hoch); der Export dreht nach Y hoch.


def laterne():
    """Berliner Bogenlaterne: konischer Mast, geschwungener Arm, Kopf."""
    _leeren()
    metall = _material("laternenmetall", (0.10, 0.12, 0.11), 0.5, 0.6)
    glas = _material("lampenglas", (1.0, 0.85, 0.55), 0.3,
                     leuchten=(1.0, 0.78, 0.45), staerke=2.4)

    _zylinder(0.09, 0.5, (0, 0, 0.25), metall, seiten=16)      # Sockel
    mast = _zylinder(0.055, 4.6, (0, 0, 2.3 + 0.4), metall, seiten=16, r_oben=0.035)
    mast.location.z = 2.7

    # Bogenarm: Kette kurzer Zylinder entlang eines Viertelkreises nach -Y.
    # Zylinderachse ist +Z; Drehung um +X mit θ bildet +Z auf (0, -sin θ, cos θ)
    # ab — daher atan2(-Δy, Δz), sonst zerfällt der Bogen in Striche.
    for i in range(8):
        w0 = math.radians(90 * i / 8)
        w1 = math.radians(90 * (i + 1) / 8)
        r = 0.85
        p0 = (0, -r * (1 - math.cos(w0)), 5.0 + r * math.sin(w0))
        p1 = (0, -r * (1 - math.cos(w1)), 5.0 + r * math.sin(w1))
        mitte = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2)
        laenge = math.dist(p0, p1) * 1.5
        seg = _zylinder(0.034, laenge, mitte, metall, fase=0, seiten=10)
        seg.rotation_euler.x = math.atan2(-(p1[1] - p0[1]), p1[2] - p0[2])

    # Kopf am Armende: Gehäuse mit Schirm und leuchtender Wanne.
    kopf_ort = (0, -0.85, 5.78)
    _zylinder(0.16, 0.1, (kopf_ort[0], kopf_ort[1], kopf_ort[2] + 0.09), metall, seiten=16)
    _zylinder(0.22, 0.05, (kopf_ort[0], kopf_ort[1], kopf_ort[2] + 0.02), metall,
              seiten=16, r_oben=0.3)
    wanne = _zylinder(0.13, 0.12, (kopf_ort[0], kopf_ort[1], kopf_ort[2] - 0.05),
                      glas, seiten=16, r_oben=0.16)
    wanne.name = "Leuchtwanne"
    _exportieren("laterne")


def auto():
    """Kompakter Wagen mit gerundeter Karosserie. Front zeigt nach -Y."""
    _leeren()
    lack = _material("autolack", (0.10, 0.11, 0.13), 0.35, 0.4)
    glas = _material("autoglas", (0.05, 0.07, 0.1), 0.15, 0.4)
    kunststoff = _material("stossfaenger", (0.13, 0.14, 0.15), 0.6)
    reifen = _material("reifen", (0.04, 0.04, 0.04), 0.9)
    felge = _material("felge", (0.5, 0.52, 0.55), 0.3, 0.8)
    rot = _material("ruecklicht", (0.4, 0.05, 0.05), 0.3, leuchten=(0.9, 0.1, 0.08), staerke=0.4)
    weiss = _material("frontlicht", (0.7, 0.72, 0.75), 0.2, 0.5)
    schild = _material("kennzeichen", (0.85, 0.86, 0.82), 0.4)

    # Unterer Rumpf: Quader mit starker Fase = gerundete Wanne.
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.56))
    rumpf = bpy.context.active_object
    rumpf.scale = (1.72, 4.05, 0.66)
    bpy.ops.object.transform_apply(scale=True)
    f = rumpf.modifiers.new("fase", "BEVEL")
    f.width = 0.15
    f.segments = 4
    _zuweisen(rumpf, lack)
    _glatt(rumpf, 60)

    # Kabine: kleinerer Quader, noch runder, fast mittig (Kompaktwagen,
    # keine Limousine — die Haube bleibt kurz).
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.18, 1.1))
    kabine = bpy.context.active_object
    kabine.scale = (1.5, 2.3, 0.5)
    bpy.ops.object.transform_apply(scale=True)
    f2 = kabine.modifiers.new("fase", "BEVEL")
    f2.width = 0.24
    f2.segments = 5
    _zuweisen(kabine, glas)
    _glatt(kabine, 60)
    # Dachstreifen in Lackfarbe.
    _kasten((1.42, 1.7, 0.05), (0, 0.18, 1.34), lack, 0.02)

    for ende in (1, -1):
        _kasten((1.8, 0.16, 0.16), (0, 2.06 * ende, 0.34), kunststoff, 0.05)
        _kasten((0.52, 0.015, 0.12), (0, 2.13 * ende, 0.52), schild, 0.004)
        for seite in (1, -1):
            _kasten((0.32, 0.06, 0.12), (0.58 * seite, 2.04 * ende, 0.8),
                    rot if ende > 0 else weiss, 0.02)
    # Außenspiegel: kurzer Arm am Rumpf, Spiegelplatte außen.
    for seite in (1, -1):
        _kasten((0.14, 0.04, 0.03), (0.8 * seite, -0.95, 1.06), lack, 0.008)
        _kasten((0.05, 0.16, 0.1), (0.9 * seite, -0.95, 1.08), lack, 0.012)

    for ecke in [(0.82, 1.4), (-0.82, 1.4), (0.82, -1.4), (-0.82, -1.4)]:
        rad = _zylinder(0.33, 0.22, (ecke[0], ecke[1], 0.33), reifen, fase=0.03, seiten=18)
        rad.rotation_euler.y = math.radians(90)
        kappe = _zylinder(0.17, 0.24, (ecke[0], ecke[1], 0.33), felge, fase=0.01, seiten=14)
        kappe.rotation_euler.y = math.radians(90)
    _exportieren("auto")


def bank():
    """Parkbank: Holzlatten auf Gussfüßen."""
    _leeren()
    holz = _material("bankholz", (0.32, 0.22, 0.13), 0.75)
    guss = _material("bankguss", (0.09, 0.1, 0.11), 0.55, 0.5)

    # Sitzlatten waagerecht, Lehnlatten leicht nach hinten geneigt und ohne
    # Lücke an die Sitzkante angeschlossen.
    for i in range(4):
        _kasten((0.09, 1.8, 0.035), (-0.14 + i * 0.11, 0, 0.45), holz, 0.006)
    for i in range(3):
        latte = _kasten((0.035, 1.8, 0.1), (-0.24 - (i * 0.115) * 0.25, 0, 0.52 + i * 0.115), holz, 0.006)
        latte.rotation_euler.y = math.radians(-14)
    for seite in (0.8, -0.8):
        _kasten((0.3, 0.05, 0.42), (-0.02, seite, 0.21), guss, 0.01)
        lehne = _kasten((0.05, 0.05, 0.42), (-0.26, seite, 0.6), guss, 0.01)
        lehne.rotation_euler.y = math.radians(-14)
    _exportieren("bank")


def ampel():
    """Ampel: Mast, Ausleger-Gehäuse mit drei Kammern und Blendschirmen."""
    _leeren()
    metall = _material("ampelmetall", (0.13, 0.14, 0.15), 0.55, 0.4)
    rot = _material("ampelrot", (0.3, 0.02, 0.02), 0.4, leuchten=(1.0, 0.08, 0.05), staerke=3.0)
    dunkel = _material("ampeldunkel", (0.05, 0.05, 0.05), 0.4)

    _zylinder(0.07, 3.4, (0, 0, 1.7), metall, seiten=14)
    gehaeuse = _kasten((0.32, 0.24, 0.92), (0, -0.08, 3.0), metall, 0.02)
    for i, mat in enumerate([rot, dunkel, dunkel]):
        z = 3.32 - i * 0.3
        linse = _zylinder(0.1, 0.05, (0, -0.22, z), mat, fase=0.008, seiten=14)
        linse.rotation_euler.x = math.radians(90)
        schirm = _zylinder(0.12, 0.14, (0, -0.26, z + 0.04), metall,
                           fase=0, seiten=14, r_oben=0.13)
        schirm.rotation_euler.x = math.radians(105)
    _exportieren("ampel")


def muelleimer():
    """Der orange Berliner Mülleimer: gerundete Tonne mit Deckelhaube am Mast."""
    _leeren()
    orange = _material("muellorange", (0.80, 0.34, 0.06), 0.55)
    dunkel = _material("muelldeckel", (0.4, 0.17, 0.04), 0.6)

    tonne = _zylinder(0.17, 0.46, (0, 0, 0.23), orange, fase=0.02, seiten=18, r_oben=0.19)
    haube = _zylinder(0.2, 0.14, (0, 0, 0.52), dunkel, fase=0.02, seiten=18, r_oben=0.12)
    # Einwurföffnung angedeutet: dunkle Blende vorn.
    _kasten((0.18, 0.02, 0.1), (0, -0.185, 0.4), dunkel, 0.006)
    _kasten((0.05, 0.06, 0.4), (0, 0.19, 0.28), dunkel, 0.008)  # Mastbügel
    _exportieren("muelleimer")


def poller():
    """Runder Poller mit Zierrille und Kugelkopf."""
    _leeren()
    guss = _material("pollerguss", (0.16, 0.17, 0.19), 0.5, 0.4)
    _zylinder(0.075, 0.85, (0, 0, 0.425), guss, fase=0.015, seiten=16, r_oben=0.06)
    _zylinder(0.075, 0.03, (0, 0, 0.72), guss, fase=0.005, seiten=16)
    _kugel(0.07, (0, 0, 0.88), guss, 16)
    _exportieren("poller")


def litfass():
    """Litfaßsäule mit gewölbter Haube und Zierring."""
    _leeren()
    beton = _material("litfassgrund", (0.25, 0.22, 0.2), 0.85)
    blech = _material("litfassdach", (0.12, 0.13, 0.13), 0.5, 0.5)

    _zylinder(0.68, 0.18, (0, 0, 0.09), blech, fase=0.02, seiten=24)
    _zylinder(0.62, 2.9, (0, 0, 1.63), beton, fase=0.01, seiten=24)
    _zylinder(0.7, 0.1, (0, 0, 3.13), blech, fase=0.02, seiten=24)
    haube = _kugel(0.62, (0, 0, 3.12), blech, 24)
    haube.scale = (1.0, 1.0, 0.55)
    bpy.ops.object.transform_apply(scale=True)
    _kugel(0.08, (0, 0, 3.52), blech, 12)
    _exportieren("litfass")


def baum():
    """Straßenbaum: konischer Stamm, drei Astansätze, klumpige Krone aus
    verformten Kugeln, dunkle Baumscheibe. Bewusst unter den Oberleitungen
    bleibend (~5,2 m). Nachts zählt die Silhouette, nicht das Blattwerk."""
    _leeren()
    rinde = _material("rinde", (0.21, 0.16, 0.12), 0.9)
    laub = _material("laub", (0.16, 0.22, 0.12), 0.95)
    erde = _material("baumscheibe", (0.09, 0.08, 0.07), 0.95)

    _kasten((1.5, 1.5, 0.06), (0, 0, 0.03), erde, 0.01)
    _zylinder(0.16, 2.6, (0, 0, 1.3), rinde, fase=0.01, seiten=12, r_oben=0.1)
    for winkel, neig in [(0.4, 0.5), (2.5, 0.45), (4.4, 0.55)]:
        ast = _zylinder(0.06, 1.1, (0.35 * math.cos(winkel), 0.35 * math.sin(winkel), 3.0),
                        rinde, fase=0, seiten=8, r_oben=0.03)
        ast.rotation_euler = (neig * math.sin(winkel), neig * math.cos(winkel), 0)

    # Krone: verformte Kugeln um den Kronenansatz, per Wolkentextur verbeult.
    wolken = bpy.data.textures.new("kronenform", type="CLOUDS")
    wolken.noise_scale = 0.6
    import random as zufall
    zufall.seed(11)
    for i in range(6):
        ort = (zufall.uniform(-0.7, 0.7), zufall.uniform(-0.7, 0.7),
               3.9 + zufall.uniform(-0.3, 0.6))
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,
                                              radius=zufall.uniform(0.85, 1.25),
                                              location=ort)
        kugel = bpy.context.active_object
        beule = kugel.modifiers.new("beule", "DISPLACE")
        beule.texture = wolken
        beule.strength = 0.45
        _zuweisen(kugel, laub)
        _glatt(kugel, 60)
    _exportieren("baum")


def atemmaske():
    """OP-Maske fürs Minispiel: gewölbtes Kissen mit zwei Ohrbändern.
    Leicht selbstleuchtend, damit sie im Nachtlicht als Ziel lesbar bleibt."""
    _leeren()
    stoff = _material("maskenstoff", (0.75, 0.85, 0.92), 0.8,
                      leuchten=(0.75, 0.85, 0.92), staerke=0.25)
    band = _material("maskenband", (0.9, 0.9, 0.9), 0.7)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
    kissen = bpy.context.active_object
    kissen.scale = (0.17, 0.05, 0.11)
    bpy.ops.object.transform_apply(scale=True)
    f = kissen.modifiers.new("fase", "BEVEL")
    f.width = 0.035
    f.segments = 4
    _zuweisen(kissen, stoff)
    _glatt(kissen, 70)

    # Ohrbänder: je Seite ein Bogen aus kurzen Röhrchen.
    for seite in (1, -1):
        for i in range(5):
            w0 = math.pi * i / 5
            w1 = math.pi * (i + 1) / 5
            r = 0.06
            p0 = (seite * (0.17 + r - r * math.cos(w0)), 0, r * math.sin(w0) - 0.0)
            p1 = (seite * (0.17 + r - r * math.cos(w1)), 0, r * math.sin(w1) - 0.0)
            mitte = ((p0[0] + p1[0]) / 2, 0, (p0[2] + p1[2]) / 2)
            seg = _zylinder(0.006, math.dist(p0, p1) * 1.4, mitte, band, fase=0, seiten=6)
            seg.rotation_euler.y = math.atan2(seite * (p1[0] - p0[0]), p1[2] - p0[2]) * seite
    _exportieren("atemmaske")


if __name__ == "__main__":
    for bau in [laterne, auto, bank, ampel, muelleimer, poller, litfass, baum,
                atemmaske]:
        bau()
    print("fertig")
