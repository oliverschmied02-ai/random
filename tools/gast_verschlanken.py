#!/usr/bin/env python3
"""Verschlankt die aufbereiteten Gäste-GLBs noch einmal deutlich.

    python3 tools/gast_verschlanken.py

Die erste Aufbereitung (mixamo_gast.py) ließ Normal- und Glanzkarten mit
256 px drin — bei zwölf Gästen in mehreren Metern Abstand trägt beides
nichts bei, kostet aber pro Kopf gut 2 MB. Nach dem Einbau lag die
macOS-Zip über dem GitHub-Limit von 100 MiB. Also weg damit:

* Normal- und Metall/Rauheits-Texturen werden aus den Materialien gelöst
  (feste Rauheit 0.85 ersetzt sie),
* Diffuse auf höchstens 384 px,
* Export wie gehabt; Bilder mit Alphakanal (Haare) bleiben PNG.
"""

from pathlib import Path

import bpy

MODELLE = Path(__file__).resolve().parent.parent / "actors" / "models"
DIFFUS_MAX = 256
DEZIMAT = 0.35  # Anteil der Dreiecke, der übrig bleibt


def verschlanken(pfad: Path) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(pfad))

    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        baum = mat.node_tree
        bsdf = baum.nodes.get("Principled BSDF")
        if bsdf is None:
            continue
        for eingang in ("Normal", "Metallic", "Roughness"):
            for verbindung in list(bsdf.inputs[eingang].links):
                baum.links.remove(verbindung)
        bsdf.inputs["Roughness"].default_value = 0.85
        bsdf.inputs["Metallic"].default_value = 0.0

    # Verwaiste Bildknoten mitsamt Normal-Map-Knoten entsorgen.
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        baum = mat.node_tree
        for knoten in list(baum.nodes):
            if knoten.bl_idname in ("ShaderNodeTexImage", "ShaderNodeNormalMap") \
                    and not any(a.links for a in knoten.outputs):
                baum.nodes.remove(knoten)

    for bild in bpy.data.images:
        if bild.size[0] == 0 or not bild.users:
            continue
        if max(bild.size) > DIFFUS_MAX:
            faktor = DIFFUS_MAX / max(bild.size)
            bild.scale(max(1, int(bild.size[0] * faktor)),
                       max(1, int(bild.size[1] * faktor)))

    # Dreieckszahl drücken: Gäste stehen Meter entfernt, ein Drittel der
    # Auflösung reicht. Decimate erhält die Skin-Gewichte; Formschlüssel
    # haben Mixamo-Figuren keine (und falls doch, fliegen sie vorher raus,
    # weil Decimate sonst verweigert).
    for obj in [o for o in bpy.data.objects if o.type == "MESH"]:
        if obj.data.shape_keys is not None:
            obj.shape_key_clear()
        mod = obj.modifiers.new("weniger", "DECIMATE")
        mod.ratio = DEZIMAT
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier="weniger")

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(pfad), export_yup=True,
                              export_image_format="AUTO")
    print("%s: %.1f MB" % (pfad.name, pfad.stat().st_size / 1e6))


if __name__ == "__main__":
    for nummer in range(1, 9):
        verschlanken(MODELLE / ("gast_%d.glb" % nummer))
    print("fertig")
