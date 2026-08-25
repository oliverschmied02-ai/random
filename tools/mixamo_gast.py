#!/usr/bin/env python3
"""Bereitet einen Mixamo-Charakter als Hochzeitsgast auf.

    python3 tools/mixamo_gast.py <roh.glb> <ziel.glb>

Die Gäste kommen als Mixamo-FBX (Version 6100, T-Pose, 30–90 MB) und
werden vorab mit FBX2glTF nach glTF gewandelt — Blender liest das alte
FBX-Format nicht. Dieser Schritt macht aus dem Roh-glTF ein spieltaugliches
Modell:

* **Knochen umbenennen** (`mixamorig:LeftArm` → `LeftArm`): das
  Figur-System sucht Knochen unter den RPM-Namen ohne Präfix; mit den
  Originalnamen fände es nichts und die Gäste stünden in T-Pose.
  Blender zieht die Vertexgruppen der Meshes beim Umbenennen selbst nach.
* **Texturen verkleinern**: Diffuse auf 512, Normal/Glanz auf 256 —
  aus 20 MB werden unter 2. Hochzeitsgäste stehen Meter entfernt.
* **Transparenz reparieren**: FBX2glTF verwirft die TransparentColor-
  Texturen; Haare und Wimpern würden als deckende Flächen gerendert.
  Ihr Alphakanal steckt aber in der Diffuse — also Alpha-Blend anschalten
  und den Kanal wieder anschließen.

Höhe und Blickrichtung regelt das Figur-System zur Laufzeit selbst.
"""

import sys
from pathlib import Path

import bpy

DIFFUS_MAX = 512
NEBEN_MAX = 256


def knochen_umbenennen() -> int:
    zaehler = 0
    for arm in [o for o in bpy.data.objects if o.type == "ARMATURE"]:
        for knochen in arm.data.bones:
            if ":" in knochen.name:
                knochen.name = knochen.name.split(":", 1)[1]
                zaehler += 1
        # Sicherheitsnetz: Vertexgruppen, die Blender nicht nachgezogen hat.
        for kind in [o for o in bpy.data.objects if o.type == "MESH"]:
            for gruppe in kind.vertex_groups:
                if ":" in gruppe.name:
                    gruppe.name = gruppe.name.split(":", 1)[1]
    return zaehler


def texturen_verkleinern() -> None:
    for bild in bpy.data.images:
        if bild.size[0] == 0:
            continue
        grenze = DIFFUS_MAX if "diffuse" in bild.name.lower() else NEBEN_MAX
        if max(bild.size) > grenze:
            faktor = grenze / max(bild.size)
            bild.scale(max(1, int(bild.size[0] * faktor)),
                       max(1, int(bild.size[1] * faktor)))


def transparenz_reparieren() -> None:
    """Haar und Wimpern: Alpha aus der Diffuse zurück ans Material."""
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        name = mat.name.lower()
        if not ("hair" in name or "eyelash" in name):
            continue
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf is None:
            continue
        farbe = bsdf.inputs["Base Color"]
        if not farbe.links:
            continue
        quelle = farbe.links[0].from_node
        if quelle.bl_idname != "ShaderNodeTexImage":
            continue
        mat.node_tree.links.new(quelle.outputs["Alpha"],
                                bsdf.inputs["Alpha"])
        mat.blend_method = "HASHED"  # dithert statt zu sortieren
        mat.show_transparent_back = False


def bauen(quelle: str, ziel: str) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=quelle)
    print("umbenannt:", knochen_umbenennen(), "Knochen")
    texturen_verkleinern()
    transparenz_reparieren()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=ziel, export_yup=True,
                              export_image_format="AUTO")
    groesse = Path(ziel).stat().st_size
    print("geschrieben: %s (%.1f MB)" % (ziel, groesse / 1e6))


if __name__ == "__main__":
    bauen(sys.argv[1], sys.argv[2])
