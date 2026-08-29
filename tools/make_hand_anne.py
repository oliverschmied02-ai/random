#!/usr/bin/env python3
"""Baut die Intro-Hand aus Annes eigenem Avatar — echte Haut statt Gummi.

    python3 tools/make_hand_anne.py            # baut assets/intro/hand_handy.glb
    python3 tools/make_hand_anne.py vorschau   # zusätzlich ein Cycles-Vorschaubild

Die bisherige Hand war das WebXR-Handmodell (make_hand_echt.py):
anatomisch richtig, aber texturlos — eine getönte Gummihand. Dabei
liegt die beste Hand längst im Projekt: **anne.glb** hat eine voll
geriggte rechte Hand mit echter Hauttextur samt Fingernägeln. Und es
ist im Spiel ja auch Annes Hand, die das Handy hält.

Ablauf (Architektur aus make_hand_echt.py übernommen):

1. Handy und Bildfläche wie gehabt.
2. anne.glb laden, am AvatarBody-Netz alles wegschneiden, was nicht
   zur rechten Hand plus einem Stück Unterarm gehört (über die
   Knochengewichte — der Ärmel deckt die Schnittkante später ab).
3. Formschlüssel entfernen (ARKit-Mimik blockiert das Pose-Backen),
   Hand exakt in die Grifflage drehen (aus den Knochen gemessen wie
   bisher, nur mit RPM-Knochennamen) und die Finger analytisch in die
   Griffpose beugen — gleiche Winkeltabellen, gemappt auf das RPM-Rig.
4. Pose ins Netz backen, Subdivision, Löcher am Schnitt zunähen.
5. Ärmel dazu, als `hand_handy.glb` mit denselben Objektnamen
   exportieren — die Intro-Szene bleibt unverändert. Kein AO-Bake:
   die Hauttextur bringt ihre Schattierung selbst mit.
"""

import math
import sys
from pathlib import Path

import bpy
import mathutils

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_hand_echt import (  # noqa: E402
    HAND_FEIN, HAND_ORT, MITTELHAND_BEUGE, SPREIZ,
    handy_bauen, vorschau_rendern,
)
from make_intro_props import AERMEL, ZIEL, _glaetten, _kasten, _material, _verbinden  # noqa: E402

WURZEL = Path(__file__).resolve().parent.parent

## Wunschlänge der Hand (Handgelenk bis Mittelfingerspitze) im Handy-Raum.
HAND_LAENGE = 0.175

## Annes Finger sind länger und schlanker als die des WebXR-Modells —
## mit den alten Winkeln ragten sie gestreckt über die Handykante hinaus.
## Gleiche Tabellenform, kräftigere Beuge, Fächer stärker geschlossen.
BEUGEN_ANNE = {
    "index-finger": (40.0, 50.0, 12.0),
    "middle-finger": (46.0, 56.0, 16.0),
    "ring-finger": (52.0, 62.0, 28.0),
    "pinky-finger": (58.0, 66.0, 30.0),
}
SPREIZ_ANNE = {alt: winkel * 1.6 for alt, winkel in SPREIZ.items()}

## Handgelenkslage: weiter hinten als beim WebXR-Modell — Annes Handteller
## reicht ~4,5 cm vor das Gelenk, die Handfläche soll den Handyrücken
## berühren, nicht durch den Bildschirm stoßen.
ORT_ANNE = (HAND_ORT[0], 0.040, HAND_ORT[2])
DAUMEN_ANNE = {
    "thumb-metacarpal": (-46.0, -30.0, 8.0),
    "thumb-phalanx-proximal": (-20.0, -12.0, 4.0),
    "thumb-phalanx-distal": (-14.0, 0.0, 0.0),
}

## WebXR-Knochennamen → RPM-Knochennamen. Die Winkeltabellen aus
## make_hand_echt.py bleiben die Quelle; nur die Namen wechseln.
## RPM hat keine Finger-Mittelhandknochen — deren kleine Beuge entfällt.
_FINGER = {"index-finger": "Index", "middle-finger": "Middle",
           "ring-finger": "Ring", "pinky-finger": "Pinky"}


def hand_importieren():
    vorher = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(WURZEL / "actors" / "models" / "anne.glb"))
    neu = [o for o in bpy.data.objects if o not in vorher]
    arm = next(o for o in neu if o.type == "ARMATURE")
    netz = None
    for o in neu:
        if o.type == "MESH" and any(
                m is not None and m.name.startswith("AvatarBody")
                for m in o.data.materials):
            netz = o
    for o in neu:
        if o is not arm and o is not netz:
            bpy.data.objects.remove(o)
    return arm, netz


def zuschneiden(netz):
    """Nur die rechte Hand plus Unterarmstummel bleibt — Auswahl über die
    Knochengewichte, nicht über Raumkoordinaten: die überstehen jede Pose."""
    behalten = {g.index for g in netz.vertex_groups if "RightHand" in g.name}
    weg = [v.index for v in netz.data.vertices
           if sum(g.weight for g in v.groups if g.group in behalten) < 0.35]
    bpy.ops.object.select_all(action="DESELECT")
    netz.select_set(True)
    bpy.context.view_layer.objects.active = netz
    if netz.data.shape_keys is not None:
        netz.shape_key_clear()  # ARKit-Mimik blockiert das Armature-Backen
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    for i in weg:
        netz.data.vertices[i].select = True
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.delete(type="VERT")
    bpy.ops.object.mode_set(mode="OBJECT")


def ausrichten(arm):
    """Wie im WebXR-Werkzeug: Lage messen, exakt in die Grifflage drehen —
    Finger zur linken Handykante (-X), Handfläche zur Rückseite (-Y)."""
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

    ziel_finger = mathutils.Vector((-1.0, 0.0, 0.0))
    ziel_normale = mathutils.Vector((0.0, -1.0, 0.0))
    ziel_quer = ziel_normale.cross(ziel_finger).normalized()

    quelle = mathutils.Matrix((finger_richtung, normale, quer)).transposed()
    ziel = mathutils.Matrix((ziel_finger, ziel_normale, ziel_quer)).transposed()
    drehung = ziel @ quelle.inverted()
    fein = mathutils.Euler(tuple(math.radians(w) for w in HAND_FEIN), "XYZ")
    arm.rotation_mode = "QUATERNION"
    arm.rotation_quaternion = (
        fein.to_matrix() @ drehung @ arm.matrix_world.to_3x3()
    ).to_quaternion()

    laenge = (_kopf("RightHandMiddle4") - _kopf("RightHand")).length
    faktor = HAND_LAENGE / laenge
    arm.scale = (faktor, faktor, faktor)
    # Ablage: HAND_ORT gilt fürs Handgelenk — die Armature-Wurzel liegt
    # bei RPM an den Füßen, deshalb wird der Versatz gemessen. matrix_world
    # trägt die Skalierung bereits, head_local bleibt also ungestaucht.
    bpy.context.view_layer.update()
    gelenk = arm.matrix_world @ arm.data.bones["RightHand"].head_local
    arm.location = mathutils.Vector(ORT_ANNE) - (gelenk - arm.location)
    bpy.context.view_layer.update()


def pose_stellen(arm):
    """Analytische Griffpose — Rechnung identisch zu make_hand_echt.py,
    nur die Knochennamen sind RPM."""
    W = arm.matrix_world.to_quaternion().to_matrix()
    W_inv = W.inverted()
    eins = mathutils.Matrix.Identity(3)

    wuensche: dict = {}
    for alt, rpm in _FINGER.items():
        grund, mitte, ende = BEUGEN_ANNE[alt]
        wuensche["RightHand%s1" % rpm] = [
            ((0, 0, 1), grund + MITTELHAND_BEUGE), ((0, 1, 0), SPREIZ_ANNE[alt])]
        wuensche["RightHand%s2" % rpm] = [((0, 0, 1), mitte)]
        wuensche["RightHand%s3" % rpm] = [((0, 0, 1), ende)]
    for alt, rpm in [("thumb-metacarpal", "RightHandThumb1"),
                     ("thumb-phalanx-proximal", "RightHandThumb2"),
                     ("thumb-phalanx-distal", "RightHandThumb3")]:
        um_x, um_y, um_z = DAUMEN_ANNE[alt]
        folge = []
        for achse, winkel in [((1, 0, 0), um_x), ((0, 1, 0), um_y),
                              ((0, 0, 1), um_z)]:
            if winkel:
                folge.append((achse, winkel))
        wuensche[rpm] = folge

    def eigen_drehung(name):
        gesamt = eins.copy()
        for achse, winkel in wuensche.get(name, []):
            gesamt = (mathutils.Quaternion(mathutils.Vector(achse),
                                           math.radians(winkel))
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


def einfrieren(arm, netz):
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
    _glaetten(netz)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.fill_holes(sides=0)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    netz.name = "hand"
    return netz


def bauen(mit_vorschau=False):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    handy, bildschirm = handy_bauen()
    arm, netz = hand_importieren()
    zuschneiden(netz)
    ausrichten(arm)
    pose_stellen(arm)

    # Ärmellage aus den Knochen messen, solange das Skelett noch steht:
    # der Schnitt endet am Handgelenk, der Ärmel deckt die Kante ab.
    gelenk = arm.matrix_world @ arm.pose.bones["RightHand"].head
    richtung = (arm.matrix_world @ arm.pose.bones["RightForeArm"].head
                - gelenk).normalized()
    dreh = richtung.to_track_quat("Z", "Y").to_euler()
    print("  gelenk %s  richtung %s" % (tuple(round(v, 3) for v in gelenk),
                                        tuple(round(v, 3) for v in richtung)))

    netz = einfrieren(arm, netz)

    aermel_stoff = _material("aermel", AERMEL, rauheit=0.95)
    # Kasten am Ursprung bauen und dann als Objekt-Transform platzieren —
    # _kasten bakt die Ablage ins Netz, eine spätere Drehung liefe sonst
    # um den Weltursprung.
    puls = _kasten((0.052, 0.046, 0.085), (0.0, 0.0, 0.0),
                   fase=0.010, name="aermel")
    puls.rotation_euler = dreh
    puls.location = gelenk + richtung * 0.040
    bpy.ops.object.modifier_apply(modifier="fase")
    puls.data.materials.append(aermel_stoff)
    _glaetten(puls)
    netz = _verbinden([netz, puls], "hand")

    if mit_vorschau:
        vorschau_rendern(Path("/tmp/intro_bake/hand_anne.png"))
        vorschau_rendern(Path("/tmp/intro_bake/hand_anne_oben.png"), von_oben=True)

    ZIEL.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in (handy, bildschirm, netz):
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(ZIEL / "hand_handy.glb"),
                              export_apply=True, export_yup=True,
                              use_selection=True)
    print("  intro/hand_handy.glb (Annes Hand)")


if __name__ == "__main__":
    bauen(mit_vorschau=len(sys.argv) > 1 and sys.argv[1] == "vorschau")
    print("fertig")
