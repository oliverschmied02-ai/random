#!/usr/bin/env python3
"""Baut Annes Hochzeitskleid für Kapitel 3.

    python3 tools/make_kleid.py            # assets/hochzeit/kleid.glb
    python3 tools/make_kleid.py vorschau   # zusätzlich Cycles-Vorschau

Fertige, auf das RPM-Skelett geriggte Hochzeitskleider sind aus dieser
Arbeitsumgebung nicht beziehbar — also entsteht das Kleid direkt auf
Annes Avatar, in drei Teilen:

* **Mieder** — eine Kopie des Rumpfes ihres Outfit-Netzes (RPM-Avatare
  haben unter der Kleidung keinen Körper!), leicht nach außen versetzt
  und mit Stoffstärke versehen. Weil es eine Kopie ist, **erbt es die
  Skelett-Gewichte gratis** und sitzt in jeder Pose.
* **Rock** — ein weiter Loft von der Taille bis knapp über den Boden,
  mit welligem Saum. Seine Gewichte kommen per Transfer vom Körpernetz:
  unten übernimmt jeder Punkt die Gewichte des nächstliegenden Beins,
  damit der Rock beim Gehen mitschwingt statt von den Beinen
  durchstoßen zu werden.
* **Taillenband** — ein schmaler Ring als Abschluss der Naht.

Exportiert wird **nur** Kleid plus Skelett (ohne Annes Netze): das GLB
bleibt klein, und das Spiel hängt die Kleidteile an das Skelett der
geladenen Figur — gleiche Knochennamen, gleiche Bindposen.
"""

import math
import sys
from pathlib import Path

import bpy
import mathutils

sys.path.insert(0, str(Path(__file__).resolve().parent))

ZIEL = Path(__file__).resolve().parent.parent / "assets" / "hochzeit"
WURZEL = Path(__file__).resolve().parent.parent


def kleid_importieren():
    """anne.glb laden, Armature und das **Outfit**-Netz behalten.

    Wichtig: RPM-Avatare haben unter der Kleidung keinen Körper —
    `AvatarBody` sind nur Hände, Arme und Hals. Die volle Rumpfform (und
    die Bein-Gewichte für den Rock-Transfer) trägt allein das Outfit."""
    vorher = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(WURZEL / "actors" / "models" / "anne.glb"))
    neu = [o for o in bpy.data.objects if o not in vorher]
    arm = next(o for o in neu if o.type == "ARMATURE")
    outfit = next(o for o in neu
                  if o.type == "MESH" and o.name.lower().startswith("outfit"))
    for o in neu:
        if o is not arm and o is not outfit:
            bpy.data.objects.remove(o)
    return arm, outfit

## Stofffarben: warmes Weiß, Satin-Schimmer fürs Band.
SATIN = (0.96, 0.95, 0.92)


def _material(name, farbe, rauheit, metall=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    def lin(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    bsdf.inputs["Base Color"].default_value = (*[lin(v) for v in farbe], 1.0)
    bsdf.inputs["Roughness"].default_value = rauheit
    bsdf.inputs["Metallic"].default_value = metall
    return m


def _knochen_z(arm, name):
    return (arm.matrix_world @ arm.data.bones[name].head_local).z


def mieder_bauen(arm, body, stoff):
    """Der Rumpf des Outfit-Netzes, kopiert und zu Stoff gemacht."""
    mieder = body.copy()
    mieder.data = body.data.copy()
    bpy.context.collection.objects.link(mieder)
    mieder.name = "kleid_mieder"
    if mieder.data.shape_keys is not None:
        bpy.context.view_layer.objects.active = mieder
        mieder.shape_key_clear()

    # Zuschnitt rein geometrisch — die T-Pose macht es einfach: Rumpf ist,
    # was im Höhenfenster liegt und nicht weiter als 20 cm von der
    # Mittelachse absteht (dort beginnen die ausgestreckten Arme).
    # Untergrenze deutlich UNTER dem Hüftknochen: so überzieht das
    # Mieder den kompletten Jeansbund samt Po-Wölbung — ein Stoß auf
    # Hüfthöhe ließ die Jeans seitlich zwischen Mieder und Rock
    # hervorblitzen.
    unten = _knochen_z(arm, "Hips") - 0.06
    oben = _knochen_z(arm, "Neck") - 0.115
    weg = []
    for v in mieder.data.vertices:
        p = mieder.matrix_world @ v.co
        if p.z < unten or p.z > oben or abs(p.x) > 0.20:
            weg.append(v.index)
    bpy.ops.object.select_all(action="DESELECT")
    mieder.select_set(True)
    bpy.context.view_layer.objects.active = mieder
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    for i in weg:
        mieder.data.vertices[i].select = True
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.delete(type="VERT")
    bpy.ops.object.mode_set(mode="OBJECT")
    print("  mess: mieder weg %d, übrig %d Ecken" % (
        len(weg), len(mieder.data.vertices)))
    # Stoff liegt AUF der Haut: entlang der Normalen hinausschieben,
    # dann Stoffstärke.
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.transform.shrink_fatten(value=0.007)
    bpy.ops.object.mode_set(mode="OBJECT")
    solid = mieder.modifiers.new("stoff", "SOLIDIFY")
    solid.thickness = 0.004
    bpy.ops.object.modifier_apply(modifier="stoff")
    mieder.data.materials.clear()
    mieder.data.materials.append(stoff)
    # Kein Subsurf: das Outfit-Netz ist bereits dicht, eine Unterteilung
    # vervierfachte nur die Dateigröße (das GLB sprang auf 7 MB).
    bpy.ops.object.shade_smooth()
    return mieder


def _rock_loft(arm, name, radius_oben, radius_unten, saum_z, weite_y,
               falten, phase):
    """Ein Rockloft mit vertikalem Faltenwurf und leichter Schleppe.

    Realismus kommt aus drei Dingen: **Falten**, die oben fein beginnen
    und zum Saum hin kräftig werden (zwei überlagerte Frequenzen, damit
    kein Muster auffällt), eine **Schleppe** (der Stoff zieht hinten
    nach außen und tiefer), und ein **welliger Saum**."""
    hueft_z = _knochen_z(arm, "Hips")
    mitte = arm.matrix_world @ arm.data.bones["Hips"].head_local
    ringe = 14
    segmente = 48
    verts = []
    faces = []
    for r in range(ringe):
        t = r / (ringe - 1.0)
        z = hueft_z + 0.015 - t * (hueft_z + 0.015 - saum_z)
        radius = radius_oben + (radius_unten - radius_oben) * (t ** 1.6)
        for s in range(segmente):
            w = math.tau * s / segmente
            falte = (math.sin(w * 9.0 + phase) * 0.55
                     + math.sin(w * 15.0 + phase * 1.7 + 1.1) * 0.30)                 * falten * (t ** 1.3)
            # Schleppe: hinten (+Y, die Figur schaut nach −Y) zieht der
            # Stoff nach außen und der Saum fällt tiefer.
            hinten = max(0.0, math.sin(w))
            schleppe = (hinten ** 2) * 0.16 * (t ** 2)
            r_hier = radius + falte
            verts.append((mitte.x + math.cos(w) * r_hier,
                          mitte.y + math.sin(w) * r_hier * weite_y + schleppe,
                          max(z + math.sin(w * 9.0 + 1.3) * 0.010 * (t ** 2)
                              - (hinten ** 2) * 0.02 * t, 0.028)))
    for r in range(ringe - 1):
        a = r * segmente
        b = (r + 1) * segmente
        for s in range(segmente):
            s2 = (s + 1) % segmente
            faces.append((a + s, a + s2, b + s2, b + s))
    netz = bpy.data.meshes.new(name)
    netz.from_pydata(verts, [], faces)
    netz.update()
    rock = bpy.data.objects.new(name, netz)
    bpy.context.collection.objects.link(rock)
    return rock


def _rock_fertigstellen(rock, body, dicke):
    bpy.ops.object.select_all(action="DESELECT")
    rock.select_set(True)
    bpy.context.view_layer.objects.active = rock
    bpy.ops.object.shade_smooth()
    if dicke > 0.0:
        solid = rock.modifiers.new("stoff", "SOLIDIFY")
        solid.thickness = dicke
        bpy.ops.object.modifier_apply(modifier="stoff")
    # Gewichte vom Körper: der nächste Körperpunkt bestimmt die Bindung —
    # unten also das jeweilige Bein, oben die Hüfte.
    bpy.ops.object.select_all(action="DESELECT")
    rock.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.data_transfer(use_create=True, data_type="VGROUP_WEIGHTS",
                                 vert_mapping="POLYINTERP_NEAREST",
                                 layers_select_src="ALL",
                                 layers_select_dst="NAME")


def rock_bauen(arm, body, stoff):
    rock = _rock_loft(arm, "kleid_rock", 0.172, 0.44, 0.05, 0.95,
                      0.014, 0.0)
    rock.data.materials.append(stoff)
    _rock_fertigstellen(rock, body, 0.005)
    return rock


def tuell_bauen(arm, body, tuell):
    """Die halbtransparente Überlage: etwas weiter, etwas kürzer,
    kräftigere Falten mit anderer Phase — das gibt dem Rock Tiefe."""
    lage = _rock_loft(arm, "kleid_tuell", 0.180, 0.475, 0.10, 0.96,
                      0.020, 2.3)
    lage.data.materials.append(tuell)
    _rock_fertigstellen(lage, body, 0.0)
    return lage


def schleier_bauen(arm, tuell):
    """Der Schleier: eine gewölbte Tüllbahn vom Hinterkopf bis zwischen
    die Schulterblätter, komplett an den Kopfknochen gebunden."""
    kopf = arm.matrix_world @ arm.data.bones["Head"].head_local
    reihen = 9
    spalten = 9
    verts = []
    faces = []
    for r in range(reihen):
        t = r / (reihen - 1.0)
        breite = 0.13 + 0.13 * t
        # Bahn: startet oben am Hinterkopf, schwingt nach hinten-unten.
        y = kopf.y + 0.065 + 0.10 * t + 0.03 * math.sin(t * math.pi)
        z = kopf.z + 0.10 - 0.52 * (t ** 1.15)
        for c in range(spalten):
            u = c / (spalten - 1.0) - 0.5
            x = kopf.x + u * 2.0 * breite
            # Quer gewölbt (um den Kopf) plus leichte Wellen am Rand.
            verts.append((x,
                          y - (u * u) * 0.16
                          + math.sin(u * 9.0 + t * 4.0) * 0.008 * t,
                          z + math.sin(u * 7.0) * 0.012 * t))
    for r in range(reihen - 1):
        for c in range(spalten - 1):
            a = r * spalten + c
            b = (r + 1) * spalten + c
            faces.append((a, a + 1, b + 1, b))
    netz = bpy.data.meshes.new("kleid_schleier")
    netz.from_pydata(verts, [], faces)
    netz.update()
    schleier = bpy.data.objects.new("kleid_schleier", netz)
    bpy.context.collection.objects.link(schleier)
    schleier.data.materials.append(tuell)
    bpy.ops.object.select_all(action="DESELECT")
    schleier.select_set(True)
    bpy.context.view_layer.objects.active = schleier
    bpy.ops.object.shade_smooth()
    gruppe = schleier.vertex_groups.new(name="Head")
    gruppe.add(list(range(len(schleier.data.vertices))), 1.0, "REPLACE")
    return schleier


def band_bauen(arm, schimmer):
    mitte = arm.matrix_world @ arm.data.bones["Hips"].head_local
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.165, minor_radius=0.013,
        location=(mitte.x, mitte.y, _knochen_z(arm, "Hips") + 0.01),
        major_segments=28, minor_segments=8)
    band = bpy.context.active_object
    band.name = "kleid_band"
    band.scale = (1.0, 0.88, 1.5)
    bpy.ops.object.transform_apply(scale=True)
    band.data.materials.append(schimmer)
    bpy.ops.object.shade_smooth()
    # Volle Bindung an die Hüfte — ohne Gewichte bliebe das Band beim
    # Umhängen ans Spiel-Skelett starr am Ursprung stehen.
    gruppe = band.vertex_groups.new(name="Hips")
    gruppe.add(list(range(len(band.data.vertices))), 1.0, "REPLACE")
    return band


def _skinnen(teil, arm):
    """Armature-Bindung fürs Export-Skinning (Gewichte liegen schon da)."""
    teil.parent = arm
    mod = teil.modifiers.new("skelett", "ARMATURE")
    mod.object = arm


def bauen(mit_vorschau=False):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    arm, body = kleid_importieren()
    zs = [(body.matrix_world @ v.co).z for v in body.data.vertices]
    print("  mess: Hips %.3f  Neck %.3f  body-z %.3f..%.3f (%d Ecken)" % (
        _knochen_z(arm, "Hips"), _knochen_z(arm, "Neck"),
        min(zs), max(zs), len(zs)))

    stoff = _material("kleid_stoff", SATIN, rauheit=0.74)
    schimmer = _material("kleid_band", (0.93, 0.90, 0.84), rauheit=0.32,
                         metall=0.15)
    tuell = _material("kleid_tuell", (1.0, 1.0, 1.0), rauheit=0.9)
    tuell.blend_method = "BLEND"
    tuell.use_backface_culling = False
    bsdf = tuell.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Alpha"].default_value = 0.30

    mieder = mieder_bauen(arm, body, stoff)
    rock = rock_bauen(arm, body, stoff)
    lage = tuell_bauen(arm, body, tuell)
    band = band_bauen(arm, schimmer)
    schleier = schleier_bauen(arm, tuell)
    for teil in (mieder, rock, lage, band, schleier):
        _skinnen(teil, arm)

    if mit_vorschau:
        _vorschau(Path("/tmp/kleid/kleid.png"), body)

    # Nur Kleid + Skelett exportieren — Annes Netze bleiben draußen, das
    # Spiel hängt die Teile an das Skelett der geladenen Figur.
    bpy.ops.object.select_all(action="DESELECT")
    for o in (arm, mieder, rock, lage, band, schleier):
        o.select_set(True)
    ZIEL.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(ZIEL / "kleid.glb"),
                              export_apply=False, export_yup=True,
                              use_selection=True)
    print("  hochzeit/kleid.glb")


def _vorschau(pfad, body):
    szene = bpy.context.scene
    bpy.ops.object.camera_add(location=(0.4, -2.6, 1.1),
                              rotation=(math.radians(88), 0, math.radians(8)))
    szene.camera = bpy.context.active_object
    bpy.ops.object.light_add(type="SUN", location=(2, -3, 4))
    licht = bpy.context.active_object
    licht.data.energy = 3.0
    licht.rotation_euler = (math.radians(55), math.radians(-12), 0.4)
    szene.render.engine = "CYCLES"
    szene.cycles.device = "CPU"
    szene.cycles.samples = 20
    szene.render.resolution_x = 540
    szene.render.resolution_y = 760
    if szene.world is None:
        szene.world = bpy.data.worlds.new("w")
    szene.world.use_nodes = True
    szene.world.node_tree.nodes["Background"].inputs[0].default_value = (
        0.45, 0.55, 0.65, 1.0)
    pfad.parent.mkdir(parents=True, exist_ok=True)
    szene.render.filepath = str(pfad)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(szene.camera)
    bpy.data.objects.remove(licht)
    print("  vorschau:", pfad)


if __name__ == "__main__":
    bauen(mit_vorschau=len(sys.argv) > 1 and sys.argv[1] == "vorschau")
    print("fertig")
