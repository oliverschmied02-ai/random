#!/usr/bin/env python3
"""Baut die FFP2-Maske für das Minispiel.

    python3 tools/make_maske.py

Ersetzt `assets/props/atemmaske.glb` durch eine echte FFP2-Form: die
typische Bootsfalte (aufgewölbte Mitte, verschweißte flache Enden),
Nasenbügel, zwei Ohrschlaufen. Die Vlies-Textur entsteht in PIL:
feines Faserrauschen, die horizontale Faltlinie, gepunktete Schweißnähte
an den Rändern und ein dezenter „FFP2 NR"-Aufdruck.

Achsen wie bei allen Requisiten: Z hoch, -Y ist vorn.
"""

import math
from pathlib import Path

import bpy
import numpy as np
from PIL import Image, ImageDraw

ZIEL = Path(__file__).resolve().parent.parent / "assets" / "props"
TEXTUR = ZIEL / "atemmaske_vlies.png"

BREITE = 0.160   # ausgefaltete Breite in Metern
HOEHE = 0.096
WOELBUNG = 0.038


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


def vlies_textur():
    """Weißes Vlies mit Fasern, Faltlinie, Nähten und Aufdruck."""
    seite = 512
    rng = np.random.default_rng(2021)
    grund = np.full((seite, seite), 235.0)
    # Faserrauschen: zwei Körnungen, leicht horizontal verschmiert.
    fein = rng.normal(0.0, 5.5, (seite, seite))
    fein = (fein + np.roll(fein, 1, axis=1) + np.roll(fein, 2, axis=1)) / 3.0
    grob = rng.normal(0.0, 3.0, (seite // 8, seite // 8))
    grob = np.kron(grob, np.ones((8, 8)))
    feld = grund + fein + grob

    # Horizontale Faltlinie in der Mitte: schmaler Schatten mit Lichtkante.
    for zeile, staerke in [(-4, -10), (-2, -16), (0, -20), (2, -12), (4, 10)]:
        feld[seite // 2 + zeile, :] += staerke
    # Gepunktete Schweißnähte nahe Ober- und Unterkante.
    for v in (int(seite * 0.07), int(seite * 0.93)):
        for u in range(6, seite - 6, 14):
            feld[v - 1:v + 2, u:u + 7] -= 26.0

    bild = Image.fromarray(np.clip(feld, 0, 255).astype(np.uint8), "L").convert("RGB")
    z = ImageDraw.Draw(bild)
    # Aufdruck: dezent grau, wie aufgestempelt (leicht gedreht wäre schöner,
    # aber der Stempel liegt ohnehin auf gewölbter Fläche).
    z.text((int(seite * 0.56), int(seite * 0.36)), "FFP2 NR", fill=(120, 122, 126))
    z.text((int(seite * 0.56), int(seite * 0.42)), "CE 2163", fill=(150, 152, 156))
    z.text((int(seite * 0.56), int(seite * 0.48)), "EN 149:2001", fill=(165, 167, 170))
    bild = bild.resize((seite, seite))
    ZIEL.mkdir(parents=True, exist_ok=True)
    bild.save(TEXTUR)
    print("  props/atemmaske_vlies.png")


def bauen():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    vlies_textur()

    # --- Der Maskenkörper als Gitter -------------------------------------
    nu, nv = 25, 9
    # Wölbungsprofil über die Höhe: Falte in der Mitte am weitesten vorn.
    profil = [0.16, 0.44, 0.70, 0.90, 1.00, 0.90, 0.70, 0.44, 0.16]
    punkte = []
    uvs = []
    for j in range(nv):
        z = HOEHE / 2 - HOEHE * j / (nv - 1)
        for i in range(nu):
            t = i / (nu - 1)
            x = -BREITE / 2 + BREITE * t
            # Zu den verschweißten Enden läuft die Wölbung flach aus.
            fenster = math.sin(math.pi * t) ** 0.72
            y = -WOELBUNG * fenster * profil[j]
            punkte.append((x, y, z))
            uvs.append((t, 1.0 - j / (nv - 1)))
    flaechen = []
    for j in range(nv - 1):
        for i in range(nu - 1):
            a = j * nu + i
            flaechen.append((a, a + 1, a + nu + 1, a + nu))

    netz = bpy.data.meshes.new("maske")
    netz.from_pydata(punkte, [], flaechen)
    uv_ebene = netz.uv_layers.new(name="UVMap")
    for poly in netz.polygons:
        for schleife in poly.loop_indices:
            ecke = netz.loops[schleife].vertex_index
            uv_ebene.data[schleife].uv = uvs[ecke]
    koerper = bpy.data.objects.new("maske", netz)
    bpy.context.collection.objects.link(koerper)
    bpy.context.view_layer.objects.active = koerper
    koerper.select_set(True)

    dick = koerper.modifiers.new("dick", "SOLIDIFY")
    dick.thickness = 0.0018
    glatt = koerper.modifiers.new("glatt", "SUBSURF")
    glatt.levels = 2
    bpy.ops.object.modifier_apply(modifier="dick")
    bpy.ops.object.modifier_apply(modifier="glatt")
    bpy.ops.object.shade_smooth()

    vlies = _material("vlies", (1.0, 1.0, 1.0), rauheit=0.92)
    knoten = vlies.node_tree.nodes
    bild_knoten = knoten.new("ShaderNodeTexImage")
    bild_knoten.image = bpy.data.images.load(str(TEXTUR))
    vlies.node_tree.links.new(
        bild_knoten.outputs["Color"],
        knoten["Principled BSDF"].inputs["Base Color"])
    koerper.data.materials.append(vlies)

    # --- Nasenbügel -------------------------------------------------------
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.0095, 0.0415))
    buegel = bpy.context.active_object
    buegel.name = "nasenbuegel"
    buegel.scale = (0.034, 0.0022, 0.0062)
    buegel.rotation_euler = (math.radians(-14), 0, 0)
    bpy.ops.object.transform_apply(scale=True)
    fase = buegel.modifiers.new("fase", "BEVEL")
    fase.width = 0.001
    fase.segments = 2
    buegel.data.materials.append(
        _material("buegel", (0.75, 0.76, 0.78), rauheit=0.4, metall=0.6))

    # --- Ohrschlaufen -----------------------------------------------------
    band = _material("band", (0.94, 0.94, 0.95), rauheit=0.85)
    schlaufen = []
    for seite in (-1, 1):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.027, minor_radius=0.0013,
            location=(seite * (BREITE / 2 + 0.004), 0.0, 0.0),
            rotation=(0.0, math.radians(90), 0.0),
            major_segments=28, minor_segments=8)
        schlaufe = bpy.context.active_object
        schlaufe.name = "schlaufe"
        # Leicht nach hinten gekippt, wie sie beim Fallen flattern würde.
        schlaufe.rotation_euler = (math.radians(seite * 12), math.radians(90), 0)
        schlaufe.data.materials.append(band)
        bpy.ops.object.shade_smooth()
        schlaufen.append(schlaufe)

    bpy.ops.object.select_all(action="DESELECT")
    for teil in [koerper, buegel] + schlaufen:
        teil.select_set(True)
    bpy.context.view_layer.objects.active = koerper
    bpy.ops.object.join()
    maske = bpy.context.active_object
    maske.name = "atemmaske"

    bpy.ops.export_scene.gltf(filepath=str(ZIEL / "atemmaske.glb"),
                              export_apply=True, export_yup=True,
                              use_selection=True)
    print("  props/atemmaske.glb (FFP2)")


if __name__ == "__main__":
    bauen()
    print("fertig")
