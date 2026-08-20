#!/usr/bin/env python3
"""Baut die Requisiten der Tinder-Intro in Blender.

    python3 tools/make_intro_props.py

Ein GLB nach assets/intro/: `hand_handy.glb` — Annes rechte Hand mit
Smartphone, aus Kameranähe gesehen. Vier Objekte, damit Godot sie einzeln
ansteuern kann:

* `handy`      — Gehäuse mit Kameranase und Lautsprecherschlitz
* `bildschirm` — die Bildfläche; bekommt in Godot die Viewport-Textur
* `hand`       — Handfläche, vier greifende Finger, Unterarm, Ärmel
* `daumen`     — liegt vor dem Bildschirm und wischt (wird in Godot bewegt)

Die Hand entsteht **organisch statt aus Kästen**: ein Kanten-Skelett mit
Skin-Modifier (je Wirbel ein Radius), darüber Subdivision — das ergibt
runde Glieder, Knöchelwölbungen und einen weichen Ballen. Danach backt
Cycles die **Ambient Occlusion** (das Handy steht als Verdecker im Bake),
mit dem Hautton multipliziert: Kontaktschatten, wo Finger das Gehäuse
greifen, dunkle Beugen zwischen den Gliedern.

Achsen wie bei den Requisiten: Z hoch, -Y ist vorn (zur Kamera). Ursprung:
Mitte des Handys. Maße in Metern, das Handy ist 7,2 × 15 cm.
"""

import math
from pathlib import Path

import bpy
import numpy as np
from PIL import Image

ZIEL = Path(__file__).resolve().parent.parent / "assets" / "intro"
ZWISCHEN = Path("/tmp") / "intro_bake"

# Godot erwartet sRGB, Blender rechnet linear.
def _linear(kanal: float) -> float:
    if kanal <= 0.04045:
        return kanal / 12.92
    return ((kanal + 0.055) / 1.055) ** 2.4


def _farbe(r, g, b):
    return (_linear(r), _linear(g), _linear(b), 1.0)


HAUT = (0.74, 0.53, 0.45)
AERMEL = (0.24, 0.26, 0.19)  # moosgrüner Strick
GEHAEUSE = (0.07, 0.07, 0.08)


def _material(name, farbe, rauheit=0.9, metall=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = _farbe(*farbe)
    bsdf.inputs["Roughness"].default_value = rauheit
    bsdf.inputs["Metallic"].default_value = metall
    return mat


def _kasten(masse, ort, fase=0.0, name="teil", drehung=None):
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


def _skelett(name, punkte, kanten, radien, wurzel=0):
    """Kanten-Skelett → Skin-Modifier → Subdivision → fertiges, glattes
    Objekt (Modifier angewendet, damit UVs und Bake auf der Endform liegen)."""
    netz = bpy.data.meshes.new(name)
    netz.from_pydata(punkte, kanten, [])
    obj = bpy.data.objects.new(name, netz)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj

    haut = obj.modifiers.new("haut", "SKIN")
    haut.use_smooth_shade = True
    for i, radius in enumerate(radien):
        wirbel = obj.data.skin_vertices[0].data[i]
        wirbel.radius = (radius, radius)
        wirbel.use_root = i == wurzel
    unter = obj.modifiers.new("glatt", "SUBSURF")
    unter.levels = 2
    unter.render_levels = 2

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier="haut")
    bpy.ops.object.modifier_apply(modifier="glatt")
    _glaetten(obj)
    return obj


def _ao_backen(obj, name, ton, aufloesung=512):
    """Smart-UVs, Cycles-Selbst-AO, Ton multiplizieren, Textur anbinden.

    Nur Selbst-AO: die Finger schneiden bewusst ins Gehäuse (so sitzt der
    Griff bündig), aber innerhalb fremder Körper ist AO = 0 — das malt
    pechschwarze Flecken auf Knöchel und Kuppen. Deshalb werden alle
    anderen Objekte fürs Backen versteckt; die Beugenschatten zwischen
    den Gliedern bleiben."""
    andere = [o for o in bpy.context.scene.objects if o is not obj]
    for o in andere:
        o.hide_render = True
    ZWISCHEN.mkdir(parents=True, exist_ok=True)

    material = bpy.data.materials.new(name + "_material")
    material.use_nodes = True
    knoten = material.node_tree.nodes
    bsdf = knoten["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.6
    bild = bpy.data.images.new(name + "_ao", aufloesung, aufloesung)
    # Weiß vorbelegen: an UV-Nähten sampelt die Textur sonst das schwarze
    # Nichts zwischen den Inseln — das zeichnet „Risse" auf die Haut.
    bild.generated_color = (1.0, 1.0, 1.0, 1.0)
    bild_knoten = knoten.new("ShaderNodeTexImage")
    bild_knoten.image = bild
    knoten.active = bild_knoten
    obj.data.materials.clear()
    obj.data.materials.append(material)

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    # Großzügiger Winkel = wenige, große Inseln — weniger Nähte auf der Haut.
    bpy.ops.uv.smart_project(angle_limit=math.radians(89), island_margin=0.04)
    bpy.ops.object.mode_set(mode="OBJECT")

    szene = bpy.context.scene
    szene.render.engine = "CYCLES"
    szene.cycles.device = "CPU"
    szene.cycles.samples = 32
    # Nicht auf Schwarz löschen (das weiße Bild bleibt Grundfläche) und den
    # Inselrand breit auslaufen lassen — sonst sampeln Nähte dunkles Nichts.
    szene.render.bake.use_clear = False
    szene.render.bake.margin = 24
    bpy.ops.object.bake(type="AO")

    roh = ZWISCHEN / f"{name}_ao.png"
    bild.filepath_raw = str(roh)
    bild.file_format = "PNG"
    bild.save()
    for o in andere:
        o.hide_render = False
    ao = np.asarray(Image.open(roh).convert("RGB"), dtype=np.float32) / 255.0
    # Sanft einrechnen: angehobener Boden und Gamma-Aufhellung — Beugen
    # bleiben schattig, nichts wirkt schmutzig.
    ao = 0.35 + 0.65 * np.power(ao, 0.7)
    getont = ao * np.array(ton, dtype=np.float32)
    fertig = ZWISCHEN / f"{name}_farbe.png"
    Image.fromarray((np.clip(getont, 0, 1) * 255).astype(np.uint8)).save(fertig)
    bild_knoten.image = bpy.data.images.load(str(fertig))
    material.node_tree.links.new(bild_knoten.outputs["Color"],
                                 bsdf.inputs["Base Color"])


def bauen():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    aermel_stoff = _material("aermel", AERMEL, rauheit=0.95)
    gehaeuse = _material("gehaeuse", GEHAEUSE, rauheit=0.35, metall=0.4)
    schirm = _material("bildschirm", (0.02, 0.02, 0.03), rauheit=0.1)

    # --- Handy -------------------------------------------------------------
    koerper = _kasten((0.072, 0.0075, 0.150), (0, 0, 0), fase=0.004, name="handy")
    nase = _kasten((0.020, 0.002, 0.006), (0, -0.0045, 0.068), fase=0.0008,
                   name="nase")
    handy = _verbinden([koerper, nase], "handy")
    handy.data.materials.append(gehaeuse)

    # Bildfläche: knapp vor der Front. +90° um X dreht die Plane-Normale
    # (+Z) auf -Y — nach vorn, zur Kamera.
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, -0.00395, -0.001))
    bildschirm = bpy.context.active_object
    bildschirm.name = "bildschirm"
    bildschirm.scale = (0.066, 0.140, 1.0)
    bildschirm.rotation_euler = (math.radians(90), 0, 0)
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    bildschirm.data.materials.append(schirm)

    # --- Hand als Skin-Skelett ----------------------------------------------
    # Rechte Hand: Ballen und Handfläche hinterm Gehäuse rechts, vier Finger
    # queren die Rückseite und greifen um die linke Kante, die Kuppen drücken
    # vorn aufs Glas. Der Unterarm läuft nach unten rechts aus dem Bild.
    # WICHTIG: keine Verzweigungen im Skelett — an Astpunkten erzeugt der
    # Skin-Modifier verschränkte Flächen, die als dunkle „Risse" auf der
    # Haut liegen. Deshalb ist jeder Finger eine eigene, saubere Kette;
    # die Ansätze verschwinden ohnehin hinter dem Gehäuse. Die Handfläche
    # bleibt klar HINTER dem Gehäuse (y deutlich positiv) und schlank,
    # sonst schiebt sich der Ballen vor die rechte Bildschirmkante.
    teile = []
    teile.append(_skelett("handflaeche", [
        (0.088, 0.034, -0.235),   # Unterarm-Ende (aus dem Bild)
        (0.074, 0.028, -0.175),   # Unterarm
        (0.060, 0.025, -0.120),   # Handgelenk (Wurzel)
        (0.053, 0.024, -0.085),   # Ballen
        (0.049, 0.023, -0.048),   # Handfläche unten
        (0.047, 0.023, -0.010),   # Handfläche mitte
        (0.045, 0.023, 0.020),    # Handfläche oben
    ], [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6)],
        [0.023, 0.021, 0.018, 0.016, 0.015, 0.014, 0.013], wurzel=2))

    # Finger: [Höhe an der linken Kante, Radius] — jede Kette beginnt
    # unsichtbar hinter dem Gehäuse nahe der Handfläche.
    finger = [
        (0.050, 0.0080),    # Zeigefinger
        (0.021, 0.0082),    # Mittelfinger
        (-0.008, 0.0078),   # Ringfinger
        (-0.037, 0.0066),   # kleiner Finger
    ]
    for lauf, (hoehe, radius) in enumerate(finger):
        teile.append(_skelett("finger%d" % lauf, [
            (0.030, 0.022, hoehe + 0.009),     # Ansatz, hinterm Gehäuse
            (0.008, 0.020, hoehe + 0.006),     # quert die Rückseite
            (-0.028, 0.014, hoehe + 0.001),    # kurz vor der Kante
            (-0.0405, 0.001, hoehe),           # Knöchel um die Kante
            (-0.0350, -0.0105, hoehe - 0.003), # Kuppe drückt aufs Glas
        ], [(0, 1), (1, 2), (2, 3), (3, 4)],
            [radius * 1.05, radius, radius * 0.94, radius * 0.88,
             radius * 0.78], wurzel=0))

    hand = _verbinden(teile, "hand")

    # --- Daumen (eigenes Objekt, wird in Godot animiert) --------------------
    # Schlanker als zuvor, und die Kuppe ruht tiefer — über der Knopfreihe,
    # nicht mitten auf der Bio.
    daumen = _skelett("daumen", [
        (0.041, 0.004, -0.082),
        (0.027, -0.006, -0.058),
        (0.013, -0.0115, -0.046),
        (0.003, -0.0130, -0.038),
    ], [(0, 1), (1, 2), (2, 3)], [0.0105, 0.0090, 0.0080, 0.0070], wurzel=0)

    # --- AO backen (Handy und Nachbarn verschatten mit) ----------------------
    _ao_backen(hand, "hand", HAUT, 512)
    _ao_backen(daumen, "daumen", HAUT, 256)

    # Ärmel: Strickbund über dem Unterarm, läuft unten aus dem Bild.
    puls = _kasten((0.060, 0.052, 0.095), (0.078, 0.024, -0.205),
                   fase=0.016, name="aermel", drehung=(4, 12, 0))
    puls.data.materials.append(aermel_stoff)
    _glaetten(puls)
    hand = _verbinden([hand, puls], "hand")

    ZIEL.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(ZIEL / "hand_handy.glb"),
                              export_apply=True, export_yup=True,
                              use_selection=True)
    print("  intro/hand_handy.glb")


if __name__ == "__main__":
    bauen()
    print("fertig")
