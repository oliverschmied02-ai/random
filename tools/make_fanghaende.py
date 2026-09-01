#!/usr/bin/env python3
"""Baut die Fanghände fürs Brautstrauß-Spiel aus Annes Avatar.

    python3 tools/make_fanghaende.py            # assets/hochzeit/fanghaende.glb
    python3 tools/make_fanghaende.py vorschau   # zusätzlich Cycles-Vorschau

Bisher fingen zwei hautfarbene Kugelschalen — „schlecht dargestellt" war
das freundlich formuliert. Jetzt fangen **Annes echte Hände**: derselbe
Zuschnitt aus `anne.glb` wie bei der Intro-Hand (`make_hand_anne.py`),
aber in zwei Posen — **offen** (Finger leicht gefächert, bereit) und
**zu** (Griff). Das Spiel blendet beim Zugreifen von offen auf zu um;
die linke Hand ist die gespiegelte rechte.

Ausrichtung im Blender-Raum (Z hoch): Finger nach +Z, Handfläche nach
+Y — nach dem Y-hoch-Export zeigt die Fläche in Godot nach −Z, also den
anfliegenden Sträußen entgegen. Handgelenk liegt im Ursprung; die
Ablage links/rechts übernimmt das Spiel.
"""

import math
import sys
from pathlib import Path

import bpy
import mathutils

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_hand_anne import (  # noqa: E402
    HAND_LAENGE, _FINGER, hand_importieren, zuschneiden,
)
from make_hand_echt import MITTELHAND_BEUGE  # noqa: E402

ZIEL = Path(__file__).resolve().parent.parent / "assets" / "hochzeit"

## Die beiden Posen: je Finger (Grund, Mittel, End) in Grad, dazu
## Fächer-Faktor (negativ = öffnen) und Daumen-Drehungen (Welt-XYZ).
POSEN = {
    "offen": {
        "beugen": {"index-finger": (10.0, 14.0, 6.0),
                   "middle-finger": (12.0, 16.0, 7.0),
                   "ring-finger": (14.0, 18.0, 8.0),
                   "pinky-finger": (16.0, 20.0, 9.0)},
        "spreiz": {"index-finger": 7.0, "middle-finger": 2.0,
                   "ring-finger": -4.0, "pinky-finger": -10.0},
        "daumen": {"thumb-metacarpal": (-18.0, -12.0, 4.0),
                   "thumb-phalanx-proximal": (-6.0, -4.0, 2.0),
                   "thumb-phalanx-distal": (-4.0, 0.0, 0.0)},
    },
    "zu": {
        "beugen": {"index-finger": (44.0, 56.0, 26.0),
                   "middle-finger": (48.0, 60.0, 28.0),
                   "ring-finger": (52.0, 62.0, 30.0),
                   "pinky-finger": (56.0, 66.0, 32.0)},
        "spreiz": {"index-finger": -5.0, "middle-finger": -1.5,
                   "ring-finger": 2.5, "pinky-finger": 7.5},
        "daumen": {"thumb-metacarpal": (-42.0, -26.0, 8.0),
                   "thumb-phalanx-proximal": (-18.0, -10.0, 4.0),
                   "thumb-phalanx-distal": (-12.0, 0.0, 0.0)},
    },
}


def ausrichten(arm):
    """Finger nach +Z, Handfläche nach +Y, Handgelenk in den Ursprung —
    gleiche Messung wie in make_hand_anne, andere Zielachsen."""
    def _kopf(name):
        return arm.matrix_world @ arm.data.bones[name].head_local

    finger_richtung = (_kopf("RightHandMiddle4")
                       - _kopf("RightHandMiddle1")).normalized()
    quer = (_kopf("RightHandIndex1") - _kopf("RightHandPinky1")).normalized()
    normale = finger_richtung.cross(quer).normalized()
    daumen_seite = (_kopf("RightHandThumb4") - _kopf("RightHand")).normalized()
    if normale.dot(daumen_seite) < 0.0:
        normale = -normale
    quer = normale.cross(finger_richtung).normalized()

    ziel_finger = mathutils.Vector((0.0, 0.0, 1.0))
    ziel_normale = mathutils.Vector((0.0, 1.0, 0.0))
    ziel_quer = ziel_normale.cross(ziel_finger).normalized()

    quelle = mathutils.Matrix((finger_richtung, normale, quer)).transposed()
    ziel = mathutils.Matrix((ziel_finger, ziel_normale, ziel_quer)).transposed()
    drehung = ziel @ quelle.inverted()
    # Leicht nach hinten gekippt: die Öffnung der Hände zeigt schräg nach
    # oben-vorn, wie beim Warten auf einen Wurf.
    fein = mathutils.Euler((math.radians(-20.0), 0.0, 0.0), "XYZ")
    arm.rotation_mode = "QUATERNION"
    arm.rotation_quaternion = (
        fein.to_matrix() @ drehung @ arm.matrix_world.to_3x3()
    ).to_quaternion()

    laenge = (_kopf("RightHandMiddle4") - _kopf("RightHand")).length
    faktor = HAND_LAENGE / laenge
    arm.scale = (faktor, faktor, faktor)
    bpy.context.view_layer.update()
    gelenk = arm.matrix_world @ arm.data.bones["RightHand"].head_local
    arm.location = -(gelenk - arm.location)
    bpy.context.view_layer.update()


def pose_stellen(arm, pose):
    """Analytische Pose um Welt-Achsen — Rechnung aus make_hand_echt.py."""
    W = arm.matrix_world.to_quaternion().to_matrix()
    W_inv = W.inverted()
    eins = mathutils.Matrix.Identity(3)

    wuensche: dict = {}
    for alt, rpm in _FINGER.items():
        grund, mitte, ende = pose["beugen"][alt]
        wuensche["RightHand%s1" % rpm] = [
            ((0, 0, 1), grund + MITTELHAND_BEUGE),
            ((0, 1, 0), pose["spreiz"][alt])]
        wuensche["RightHand%s2" % rpm] = [((0, 0, 1), mitte)]
        wuensche["RightHand%s3" % rpm] = [((0, 0, 1), ende)]
    for alt, rpm in [("thumb-metacarpal", "RightHandThumb1"),
                     ("thumb-phalanx-proximal", "RightHandThumb2"),
                     ("thumb-phalanx-distal", "RightHandThumb3")]:
        um_x, um_y, um_z = pose["daumen"][alt]
        folge = []
        for achse, winkel in [((1, 0, 0), um_x), ((0, 1, 0), um_y),
                              ((0, 0, 1), um_z)]:
            if winkel:
                folge.append((achse, winkel))
        wuensche[rpm] = folge

    # Achtung: die Beugeachsen oben sind die des Griff-Werkzeugs — dort
    # zeigten die Finger nach −X. Hier zeigen sie nach +Z; die Beuge um
    # (0,0,1) wird zur Beuge um die neue Querachse (1,0,0), die Spreizung
    # um (0,1,0) bleibt die Handflächen-Normale. Deshalb werden die
    # Achsen vor der Rechnung umgeschrieben.
    # Die Rahmenrotation R bildet (Finger −X, Fläche −Y) auf (Finger +Z,
    # Fläche +Y) ab; daraus folgt für die Achsen: Z→−X, Y→−Y, X→−Z.
    def _achse_neu(achse):
        if achse == (0, 0, 1):
            return (-1, 0, 0)
        if achse == (0, 1, 0):
            return (0, -1, 0)
        if achse == (1, 0, 0):
            return (0, 0, -1)
        return achse

    def eigen_drehung(name):
        gesamt = eins.copy()
        for achse, winkel in wuensche.get(name, []):
            gesamt = (mathutils.Quaternion(
                mathutils.Vector(_achse_neu(achse)), math.radians(winkel))
                .to_matrix() @ gesamt)
        return gesamt

    A: dict = {None: eins}

    def akkumuliert(bone):
        if bone is None:
            return eins
        if bone.name not in A:
            A[bone.name] = eigen_drehung(bone.name) @ akkumuliert(bone.parent)
        return A[bone.name]

    for bone in arm.data.bones:
        eigene = eigen_drehung(bone.name)
        if eigene == eins:
            akkumuliert(bone)
            continue
        rest = bone.matrix_local.to_quaternion().to_matrix()
        a_eltern = akkumuliert(bone.parent)
        q = (rest.inverted() @ W_inv @ a_eltern.inverted()
             @ (eigene @ a_eltern) @ W @ rest)
        pb = arm.pose.bones[bone.name]
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = q.to_quaternion()
        akkumuliert(bone)
    bpy.context.view_layer.update()


def einfrieren(arm, netz, name):
    bpy.ops.object.select_all(action="DESELECT")
    netz.select_set(True)
    bpy.context.view_layer.objects.active = netz
    for mod in list(netz.modifiers):
        if mod.type == "ARMATURE":
            bpy.ops.object.modifier_apply(modifier=mod.name)
    if netz.parent is not None:
        welt = netz.matrix_world.copy()
        netz.parent = None
        netz.matrix_world = welt
    bpy.data.objects.remove(arm)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    unter = netz.modifiers.new("glatt", "SUBSURF")
    unter.levels = 1
    bpy.ops.object.modifier_apply(modifier="glatt")
    bpy.ops.object.shade_smooth()
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.fill_holes(sides=0)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    netz.name = name
    return netz


def spiegeln(rechts, name):
    """Linke Hand = gespiegelte rechte. Negative Skala dreht die Flächen
    um — nach dem Anwenden werden die Normalen neu vereinheitlicht."""
    kopie = rechts.copy()
    kopie.data = rechts.data.copy()
    bpy.context.collection.objects.link(kopie)
    bpy.ops.object.select_all(action="DESELECT")
    kopie.select_set(True)
    bpy.context.view_layer.objects.active = kopie
    kopie.scale = (-1.0, 1.0, 1.0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    kopie.name = name
    return kopie


def bauen(mit_vorschau=False):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    haende = []
    for pose_name, pose in POSEN.items():
        arm, netz = hand_importieren()
        zuschneiden(netz)
        ausrichten(arm)
        pose_stellen(arm, pose)
        rechts = einfrieren(arm, netz, "rechts_%s" % pose_name)
        haende.append(rechts)
        haende.append(spiegeln(rechts, "links_%s" % pose_name))

    if mit_vorschau:
        # Fürs Bild: offenes Paar links, zugreifendes Paar rechts.
        for obj in haende:
            versatz = -0.11 if obj.name.startswith("links") else 0.11
            gruppe = -0.28 if obj.name.endswith("offen") else 0.28
            obj.location = (gruppe + versatz, 0.0, 0.0)
        _vorschau(Path("/tmp/intro_bake/fanghaende.png"))
        for obj in haende:
            obj.location = (0.0, 0.0, 0.0)

    ZIEL.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in haende:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(ZIEL / "fanghaende.glb"),
                              export_apply=True, export_yup=True,
                              use_selection=True)
    print("  hochzeit/fanghaende.glb")


def _vorschau(pfad):
    szene = bpy.context.scene
    bpy.ops.object.camera_add(location=(0.0, -1.05, 0.14),
                              rotation=(math.radians(86), 0.0, 0.0))
    szene.camera = bpy.context.active_object
    bpy.ops.object.light_add(type="AREA", location=(-0.4, -0.6, 0.6))
    licht = bpy.context.active_object
    licht.data.energy = 60.0
    licht.rotation_euler = (math.radians(40), math.radians(-20), 0.0)
    szene.render.engine = "CYCLES"
    szene.cycles.device = "CPU"
    szene.cycles.samples = 24
    szene.render.resolution_x = 800
    szene.render.resolution_y = 420
    pfad.parent.mkdir(parents=True, exist_ok=True)
    szene.render.filepath = str(pfad)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(szene.camera)
    bpy.data.objects.remove(licht)
    print("  vorschau:", pfad)


if __name__ == "__main__":
    bauen(mit_vorschau=len(sys.argv) > 1 and sys.argv[1] == "vorschau")
    print("fertig")
