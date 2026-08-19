#!/usr/bin/env python3
"""Backt das Fassaden-Baukastensystem in Blender.

    python3 tools/make_fassade.py

Drei Module nach assets/props/:

* `fenster_modul` — Faschen-Band um die Öffnung, abgeschrägte Laibung,
  profilierte Fensterbank. Die Öffnung bleibt offen; Scheibe und Vorhang
  setzt die Kulisse wie bisher dahinter.
* `tuer_modul` — Türgewände mit Kassettentür und Trittstufe.
* `gesims_modul` — 1 m Kranzgesims-Profil, wird je Wandbreite in X gestreckt.

Alle Module bekommen ihre Schattierung **gebacken**: Cycles rechnet die
Ambient Occlusion (mit einer Wand als Verdecker hinter dem Modul), das
Ergebnis wird mit dem Faschen-Ton multipliziert und als Textur exportiert.
Ein 7-cm-Relief liest sich damit wie eine 20-cm-Laibung.

Achsen wie bei den Requisiten: Z hoch, -Y ist außen (Godot-Vorne nach dem
Export). Ursprung: Mitte der Öffnung auf der Wandebene (y = 0).
"""

import math
from pathlib import Path

import bpy
import bmesh  # noqa: E402 — braucht das initialisierte bpy
import numpy as np
from PIL import Image

WURZEL = Path(__file__).resolve().parent.parent / "assets" / "props"
ZWISCHEN = Path("/tmp") / "fassade_bake"

FASCHEN_TON = (0.82, 0.78, 0.70)
TUER_TON = (0.30, 0.23, 0.17)


def _leeren():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _ring(bm, breite, hoehe, y, mitte_z=0.0):
    return [bm.verts.new((sx * breite / 2, y, mitte_z + sz * hoehe / 2))
            for sx, sz in [(-1, -1), (1, -1), (1, 1), (-1, 1)]]


def _ring_flaechen(bm, aussen, innen):
    for k in range(4):
        bm.faces.new([aussen[k], aussen[(k + 1) % 4],
                      innen[(k + 1) % 4], innen[k]])


def _als_objekt(bm, name):
    netz = bpy.data.meshes.new(name)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(netz)
    bm.free()
    obj = bpy.data.objects.new(name, netz)
    bpy.context.collection.objects.link(obj)
    return obj


def _kasten(masse, ort):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=ort)
    obj = bpy.context.active_object
    obj.scale = masse
    bpy.ops.object.transform_apply(scale=True)
    return obj


def _alles_verbinden(teile, name):
    bpy.ops.object.select_all(action="DESELECT")
    for teil in teile:
        teil.select_set(True)
    bpy.context.view_layer.objects.active = teile[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    return obj


def _backen_und_exportieren(obj, name, ton, aufloesung=1024):
    """Smart-UVs, Cycles-AO-Bake mit Wand als Verdecker, Ton multiplizieren,
    Textur anbinden, GLB exportieren."""
    ZWISCHEN.mkdir(parents=True, exist_ok=True)

    # Material mit Bild-Knoten, der das Bake-Ziel ist.
    material = bpy.data.materials.new(name + "_material")
    material.use_nodes = True
    knoten = material.node_tree.nodes
    bsdf = knoten["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.85
    bild = bpy.data.images.new(name + "_ao", aufloesung, aufloesung)
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
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")

    # Verdecker: die Wand hinter dem Modul, für Kontaktschatten.
    wand = _kasten((8.0, 0.3, 8.0), (0, 0.16, 0))

    szene = bpy.context.scene
    szene.render.engine = "CYCLES"
    szene.cycles.device = "CPU"
    szene.cycles.samples = 48
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.bake(type="AO")

    roh_pfad = ZWISCHEN / f"{name}_ao.png"
    bild.filepath_raw = str(roh_pfad)
    bild.file_format = "PNG"
    bild.save()

    # Ton einmultiplizieren (sRGB-Ton, das Bake ist linear-neutral genug).
    ao = np.asarray(Image.open(roh_pfad).convert("RGB"), dtype=np.float32) / 255.0
    getont = ao * np.array(ton, dtype=np.float32)
    fertig_pfad = ZWISCHEN / f"{name}_farbe.png"
    Image.fromarray((np.clip(getont, 0, 1) * 255).astype(np.uint8)).save(fertig_pfad)

    bild_knoten.image = bpy.data.images.load(str(fertig_pfad))
    material.node_tree.links.new(bild_knoten.outputs["Color"],
                                 bsdf.inputs["Base Color"])

    bpy.data.objects.remove(wand)
    WURZEL.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(WURZEL / f"{name}.glb"),
                              export_apply=True, export_yup=True,
                              use_selection=True)
    print(f"  props/{name}.glb")


def fenster_modul():
    """Faschen-Band, abgeschrägte Laibung, Fensterbank. Öffnung 1,02 × 1,62,
    Band bis 1,38 × 1,98, 6,5 cm proud — die AO macht die Tiefe."""
    _leeren()
    bm = bmesh.new()
    band_aussen = _ring(bm, 1.38, 1.98, -0.065)
    band_innen = _ring(bm, 1.02, 1.62, -0.065)
    laibung = _ring(bm, 0.88, 1.48, -0.004)
    rand_hinten = _ring(bm, 1.38, 1.98, 0.0)
    _ring_flaechen(bm, band_aussen, band_innen)   # Bandfläche
    _ring_flaechen(bm, band_innen, laibung)       # Laibungsschräge
    _ring_flaechen(bm, rand_hinten, band_aussen)  # Außenkante
    gewaende = _als_objekt(bm, "gewaende")

    bank = _kasten((1.5, 0.17, 0.075), (0, -0.085, -0.85))
    fase = bank.modifiers.new("fase", "BEVEL")
    fase.width = 0.02
    fase.segments = 2
    tropf = _kasten((1.5, 0.02, 0.02), (0, -0.16, -0.9))

    modul = _alles_verbinden([gewaende, bank, tropf], "fenster_modul")
    _backen_und_exportieren(modul, "fenster_modul", FASCHEN_TON)


def tuer_modul():
    """Türgewände mit Kassettentür und Trittstufe, 1,5 × 2,6."""
    _leeren()
    bm = bmesh.new()
    band_aussen = _ring(bm, 1.72, 2.86, -0.08, 0.0)
    band_innen = _ring(bm, 1.36, 2.56, -0.08, 0.0)
    laibung = _ring(bm, 1.24, 2.44, -0.01, 0.0)
    rand_hinten = _ring(bm, 1.72, 2.86, 0.0, 0.0)
    _ring_flaechen(bm, band_aussen, band_innen)
    _ring_flaechen(bm, band_innen, laibung)
    _ring_flaechen(bm, rand_hinten, band_aussen)
    gewaende = _als_objekt(bm, "tuergewaende")

    blatt = _kasten((1.24, 0.05, 2.44), (0, -0.005, 0.0))
    teile = [gewaende, blatt]
    # Kassetten: vier vertiefte Felder als aufgesetzte Rahmenleisten.
    for sz in (0.62, -0.62):
        for sx in (-0.3, 0.3):
            teile.append(_kasten((0.46, 0.02, 0.98), (sx, -0.04, sz)))
    teile.append(_kasten((1.6, 0.32, 0.08), (0, -0.14, -1.47)))  # Stufe

    modul = _alles_verbinden(teile, "tuer_modul")
    _backen_und_exportieren(modul, "tuer_modul", TUER_TON)


def gesims_modul():
    """1 m Kranzgesims: gestuftes Profil, wird je Wand in X gestreckt."""
    _leeren()
    teile = [
        _kasten((1.0, 0.10, 0.10), (0, -0.05, 0.0)),
        _kasten((1.0, 0.16, 0.07), (0, -0.08, 0.10)),
        _kasten((1.0, 0.24, 0.06), (0, -0.12, 0.18)),
        _kasten((1.0, 0.30, 0.05), (0, -0.15, 0.245)),
    ]
    for teil in teile:
        fase = teil.modifiers.new("fase", "BEVEL")
        fase.width = 0.012
        fase.segments = 2
    modul = _alles_verbinden(teile, "gesims_modul")
    _backen_und_exportieren(modul, "gesims_modul", FASCHEN_TON, 512)


if __name__ == "__main__":
    fenster_modul()
    tuer_modul()
    gesims_modul()
    print("fertig")
