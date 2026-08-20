#!/usr/bin/env python3
"""Verbaut das echte, geriggte Handmodell in die Tinder-Intro.

    python3 tools/make_hand_echt.py            # baut assets/intro/hand_handy.glb
    python3 tools/make_hand_echt.py vorschau   # zusätzlich ein Cycles-Vorschaubild

Quelle: `assets/intro/quelle/webxr_hand_rechts.glb` — das generische
WebXR-Handmodell (npm `@webxr-input-profiles/assets`, MIT, siehe
LIZENZ-webxr-hand.md daneben). Ein anatomisch echtes, vollständig
geriggtes Handnetz mit 25 Gelenken.

Ablauf:

1. Handy und Bildfläche wie gehabt aus `make_intro_props` bauen.
2. Handmodell importieren, ausrichten und über die Pose-Knochen in die
   **Griffpose** biegen: Finger queren die Rückseite und legen die Kuppen
   um die linke Kante, der Daumen ruht über der unteren Bildschirmhälfte.
3. Pose ins Netz einfrieren (Armature anwenden), Subdivision + Glätten.
4. **Daumen abtrennen** (über die Knochengewichte) — er bleibt ein eigenes
   Objekt namens `daumen`, das Godot beim Wischen bewegt. Kappenkugeln
   verstecken die Schnittkante auf beiden Seiten.
5. Selbst-AO in Cycles backen (fremde Körper versteckt), Hautton
   multiplizieren, Ärmel dazu, alles als `hand_handy.glb` exportieren —
   gleiche Objektnamen wie bisher, die Szene bleibt unverändert.
"""

import math
import sys
from pathlib import Path

import bpy
import mathutils

# Bausteine des bisherigen Werkzeugs wiederverwenden.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_intro_props import (  # noqa: E402
    AERMEL, HAUT, ZIEL, _ao_backen, _glaetten, _kasten, _material, _verbinden,
)

QUELLE = Path(__file__).resolve().parent.parent / "assets" / "intro" / "quelle"

# --- Die Stellschrauben der Pose ---------------------------------------------
# Ablage im Handy-Raum; die Drehung wird nicht geraten, sondern aus den
# Knochen gemessen und exakt konstruiert (siehe ausrichten()).
HAND_ORT = (0.057, 0.006, -0.033)
HAND_SKALA = 0.85
# Feinwinkel nach der exakten Ausrichtung (Grad, um Welt-XYZ).
HAND_FEIN = (0.0, 14.0, 0.0)

# Beugewinkel je Finger (Grad): Grundgelenk, Mittelgelenk, Endgelenk.
BEUGEN = {
    "index-finger": (24.0, 30.0, 12.0),
    "middle-finger": (28.0, 34.0, 14.0),
    "ring-finger": (32.0, 38.0, 16.0),
    "pinky-finger": (38.0, 42.0, 18.0),
}

# Spreizung einsammeln (Grad um Welt-Y am Grundgelenk): die Ruhelage
# fächert die Finger — im Griff liegen sie beieinander.
SPREIZ = {
    "index-finger": -6.0,
    "middle-finger": -2.0,
    "ring-finger": 3.0,
    "pinky-finger": 9.0,
}
MITTELHAND_BEUGE = 6.0

# Daumen: Drehungen um die WELT-Achsen (X, Y, Z) in Grad, je Knochen.
DAUMEN_POSE = {
    "thumb-metacarpal": (-38.0, -28.0, 6.0),
    "thumb-phalanx-proximal": (-14.0, -10.0, 4.0),
    "thumb-phalanx-distal": (-10.0, 0.0, 0.0),
}


def handy_bauen():
    """Gehäuse und Bildfläche — identisch zum bisherigen Werkzeug."""
    gehaeuse = _material("gehaeuse", (0.07, 0.07, 0.08), rauheit=0.35, metall=0.4)
    schirm = _material("bildschirm", (0.02, 0.02, 0.03), rauheit=0.1)

    koerper = _kasten((0.072, 0.0075, 0.150), (0, 0, 0), fase=0.004, name="handy")
    nase = _kasten((0.020, 0.002, 0.006), (0, -0.0045, 0.068), fase=0.0008,
                   name="nase")
    handy = _verbinden([koerper, nase], "handy")
    handy.data.materials.append(gehaeuse)

    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, -0.00395, -0.001))
    bildschirm = bpy.context.active_object
    bildschirm.name = "bildschirm"
    bildschirm.scale = (0.066, 0.140, 1.0)
    bildschirm.rotation_euler = (math.radians(90), 0, 0)
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    bildschirm.data.materials.append(schirm)
    return handy, bildschirm


def hand_importieren():
    """Lädt das WebXR-Handmodell und liefert (Armature, Netz)."""
    vorher = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(QUELLE / "webxr_hand_rechts.glb"))
    neu = [o for o in bpy.data.objects if o not in vorher]
    arm = next(o for o in neu if o.type == "ARMATURE")
    netz = next(o for o in neu if o.type == "MESH" and "hand" in o.name.lower())
    # Der kleine Icosphere-Marker aus dem Profil wird nicht gebraucht.
    for o in neu:
        if o is not arm and o is not netz:
            bpy.data.objects.remove(o)
    return arm, netz


def ausrichten(arm):
    """Misst die Ruhelage und dreht die Hand exakt in die Grifflage:
    Finger zeigen zur linken Handykante (-X), die Handfläche zur
    Handy-Rückseite (-Y, zur Kamera hin — vom Gehäuse verdeckt)."""
    def _kopf(name):
        return arm.matrix_world @ arm.data.bones[name].head_local

    finger_richtung = (_kopf("middle-finger-tip")
                       - _kopf("middle-finger-metacarpal")).normalized()
    quer = (_kopf("index-finger-phalanx-proximal")
            - _kopf("pinky-finger-phalanx-proximal")).normalized()
    normale = finger_richtung.cross(quer).normalized()
    # Vorzeichen: der entspannte Daumen liegt auf der Handflächenseite.
    daumen_seite = (_kopf("thumb-tip") - _kopf("wrist")).normalized()
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
    # WICHTIG: nicht matrix_world schreiben — das bricht im
    # Headless-Betrieb die spätere Pose-Auswertung. Einzelkanäle setzen.
    arm.rotation_mode = "QUATERNION"
    arm.rotation_quaternion = (
        fein.to_matrix() @ drehung @ arm.matrix_world.to_3x3()
    ).to_quaternion()
    arm.scale = (HAND_SKALA, HAND_SKALA, HAND_SKALA)
    arm.location = HAND_ORT
    bpy.context.view_layer.update()


def pose_stellen(arm):
    """Beugt die Finger um WELT-Achsen — komplett analytisch.

    Pose-Zustände zurückzulesen (pb.matrix, pb.head) ist im
    Headless-Betrieb unzuverlässig; hier wird ausschließlich aus den
    Ruhe-Matrizen (`bone.matrix_local`) gerechnet. Blender setzt die
    Kanal-Drehung Q so ein:  Pose(b) = Pose(Eltern) · Rest(Eltern)⁻¹ ·
    Rest(b) · Q — daraus folgt Q aus der gewünschten Welt-Drehung."""
    # Nur die ROTATIONSANTEILE verwenden — matrix_local mancher Knochen
    # trägt Skalenreste, die sonst als Scherung in die Kanal-Drehung
    # einziehen und Glieder zerknüllen.
    W = arm.matrix_world.to_quaternion().to_matrix()
    W_inv = W.inverted()
    eins = mathutils.Matrix.Identity(3)

    # Gewünschte Welt-Drehungen je Knochen, in Anwendungsreihenfolge.
    wuensche: dict[str, list] = {}
    for finger, (grund, mitte, ende) in BEUGEN.items():
        wuensche["%s-metacarpal" % finger] = [((0, 0, 1), MITTELHAND_BEUGE)]
        wuensche["%s-phalanx-proximal" % finger] = [
            ((0, 0, 1), grund), ((0, 1, 0), SPREIZ[finger])]
        wuensche["%s-phalanx-intermediate" % finger] = [((0, 0, 1), mitte)]
        wuensche["%s-phalanx-distal" % finger] = [((0, 0, 1), ende)]
    for name, (um_x, um_y, um_z) in DAUMEN_POSE.items():
        folge = []
        for achse, winkel in [((1, 0, 0), um_x), ((0, 1, 0), um_y),
                              ((0, 0, 1), um_z)]:
            if winkel:
                folge.append((achse, winkel))
        wuensche[name] = folge

    def eigen_drehung(name):
        gesamt = eins.copy()
        for achse, winkel in wuensche.get(name, []):
            gesamt = (mathutils.Quaternion(mathutils.Vector(achse),
                                           math.radians(winkel))
                      .to_matrix() @ gesamt)
        return gesamt

    A: dict = {None: eins}  # akkumulierte Welt-Drehung je Knochen

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
    """Pose ins Netz backen, dann verfeinern (Subdivision + Glätten)."""
    bpy.ops.object.select_all(action="DESELECT")
    netz.select_set(True)
    bpy.context.view_layer.objects.active = netz
    for mod in list(netz.modifiers):
        if mod.type == "ARMATURE":
            bpy.ops.object.modifier_apply(modifier=mod.name)
    # Objekt-Transformation der Armature aufs Netz übertragen. Das Netz
    # hängt als Kind an der Armature — erst die Welt-Matrix sichern, dann
    # den Parent lösen, sonst verpufft die Drehung beim Entfernen.
    if netz.parent is not None:
        welt = netz.matrix_world.copy()
        netz.parent = None
        netz.matrix_world = welt
    else:
        netz.matrix_world = arm.matrix_world @ netz.matrix_world
    bpy.data.objects.remove(arm)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    unter = netz.modifiers.new("glatt", "SUBSURF")
    unter.levels = 2
    bpy.ops.object.modifier_apply(modifier="glatt")
    _glaetten(netz)
    return netz


def loecher_schliessen(netz):
    """Näht offene Kanten zu (Handgelenk-Ende). Der Daumen bleibt am
    Netz — jede Abtrennung hinterließ sichtbare Nahtartefakte; die
    Wischbewegung übernimmt in Godot stattdessen die ganze Hand."""
    bpy.ops.object.select_all(action="DESELECT")
    netz.select_set(True)
    bpy.context.view_layer.objects.active = netz
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.fill_holes(sides=0)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    netz.name = "hand"
    return netz


def vorschau_rendern(pfad, von_oben=False):
    szene = bpy.context.scene
    if von_oben:
        bpy.ops.object.camera_add(location=(0.05, 0.0, 0.5),
                                  rotation=(0.0, 0.0, 0.0))
    else:
        bpy.ops.object.camera_add(location=(0.05, -0.55, 0.02),
                                  rotation=(math.radians(87), 0, 0))
    szene.camera = bpy.context.active_object
    bpy.ops.object.light_add(type="AREA", location=(-0.25, -0.3, 0.25))
    licht = bpy.context.active_object
    licht.data.energy = 30.0
    licht.rotation_euler = (math.radians(45), math.radians(-25), 0)
    szene.render.engine = "CYCLES"
    szene.cycles.device = "CPU"
    szene.cycles.samples = 24
    szene.render.resolution_x = 640
    szene.render.resolution_y = 360
    szene.render.filepath = str(pfad)
    bpy.ops.render.render(write_still=True)
    print("  vorschau:", pfad)


def bauen(mit_vorschau=False):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    handy, bildschirm = handy_bauen()

    arm, netz = hand_importieren()
    ausrichten(arm)
    pose_stellen(arm)
    bpy.context.view_layer.update()
    netz = einfrieren(arm, netz)
    netz = loecher_schliessen(netz)

    _ao_backen(netz, "hand", HAUT, 512)

    aermel_stoff = _material("aermel", AERMEL, rauheit=0.95)
    puls = _kasten((0.060, 0.052, 0.095), (0.082, 0.028, -0.185),
                   fase=0.016, name="aermel", drehung=(4, 12, 0))
    puls.data.materials.append(aermel_stoff)
    _glaetten(puls)
    netz = _verbinden([netz, puls], "hand")

    if mit_vorschau:
        vorschau_rendern(Path("/tmp/intro_bake/hand_vorschau.png"))
        vorschau_rendern(Path("/tmp/intro_bake/hand_vorschau_oben.png"), von_oben=True)

    ZIEL.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in (handy, bildschirm, netz):
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(ZIEL / "hand_handy.glb"),
                              export_apply=True, export_yup=True,
                              use_selection=True)
    print("  intro/hand_handy.glb (echte Hand)")


if __name__ == "__main__":
    bauen(mit_vorschau=len(sys.argv) > 1 and sys.argv[1] == "vorschau")
    print("fertig")
