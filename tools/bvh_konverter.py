#!/usr/bin/env python3
"""Wandelt CMU-Mocap-BVH in die Bewegungsdaten des Spiels um.

    python3 tools/bvh_konverter.py <walk.bvh> <idle.bvh>

Schreibt assets/mocap/gehen.json und stehen.json. Das Format ist auf das
Laufzeit-Retargeting zugeschnitten (systems/figur/mocap.gd):

* Rumpf, Kopf, Hüfte übertragen ihre **volle Weltrotation** — die Nullpose
  des CMU-Skeletts ist dort aufrecht wie beim Modell.
* Arme und Beine übertragen nur ihre **Knochenrichtung** — die CMU-Nullpose
  spreizt die Beine ~20° nach außen, volle Rotationen kämen verdreht an.
  Zur Laufzeit wird die Modellruhe-Richtung per kürzestem Bogen auf die
  aufgenommene Richtung gedreht.

Alle Daten sind in einen "Skelettraum" gedreht, in dem die Laufrichtung +Z
ist (die Konvention des Gangwerks). Der Gang wird als nahtlose Schleife
geschnitten (bester Posen-Rückschluss zwischen erstem und letztem Drittel),
die Schrittlänge in Hüfthöhen gespeichert — zur Laufzeit skaliert sie mit
der gemessenen Hüfthöhe des Modells.
"""

import json
import sys
from pathlib import Path

import numpy as np

WURZEL = Path(__file__).resolve().parent.parent / "assets" / "mocap"

# Zuordnung BVH-Gelenk -> Modellknochen, mit Übertragungsart.
# "voll": Weltrotation; "richtung": Richtung zum genannten Kindgelenk.
ZUORDNUNG = [
    ("Hips", "Hips", "voll", None),
    ("LowerBack", "Spine", "voll", None),
    ("Spine", "Spine1", "voll", None),
    ("Spine1", "Spine2", "voll", None),
    ("Neck1", "Neck", "voll", None),
    ("Head", "Head", "voll", None),
    ("LeftShoulder", "LeftShoulder", "richtung", "LeftArm"),
    ("LeftArm", "LeftArm", "richtung", "LeftForeArm"),
    ("LeftForeArm", "LeftForeArm", "richtung", "LeftHand"),
    ("RightShoulder", "RightShoulder", "richtung", "RightArm"),
    ("RightArm", "RightArm", "richtung", "RightForeArm"),
    ("RightForeArm", "RightForeArm", "richtung", "RightHand"),
    ("LeftUpLeg", "LeftUpLeg", "richtung", "LeftLeg"),
    ("LeftLeg", "LeftLeg", "richtung", "LeftFoot"),
    ("LeftFoot", "LeftFoot", "richtung", "LeftToeBase"),
    ("RightUpLeg", "RightUpLeg", "richtung", "RightLeg"),
    ("RightLeg", "RightLeg", "richtung", "RightFoot"),
    ("RightFoot", "RightFoot", "richtung", "RightToeBase"),
]


def bvh_lesen(pfad):
    text = Path(pfad).read_text()
    kopf, motion = text.split("MOTION")
    namen, eltern, offsets = [], [], []
    kanal_start, kanal_arten = [], []
    stapel = []
    kanal_zaehler = 0
    for zeile in kopf.splitlines():
        s = zeile.split()
        if not s:
            continue
        if s[0] in ("ROOT", "JOINT"):
            namen.append(s[1])
            eltern.append(stapel[-1] if stapel else -1)
            offsets.append(None)
            kanal_start.append(None)
            kanal_arten.append(None)
            _zuletzt = len(namen) - 1
        elif s[0] == "{":
            stapel.append(_zuletzt if "_zuletzt" in dir() else -1)
            stapel[-1] = len(namen) - 1
        elif s[0] == "}":
            stapel.pop()
        elif s[0] == "OFFSET" and namen and offsets[len(namen) - 1] is None:
            offsets[len(namen) - 1] = np.array([float(v) for v in s[1:4]])
        elif s[0] == "CHANNELS":
            idx = len(namen) - 1
            kanal_start[idx] = kanal_zaehler
            kanal_arten[idx] = s[2:]
            kanal_zaehler += int(s[1])
    zeilen = motion.strip().splitlines()
    bildzeit = float(zeilen[1].split()[-1])
    bilder = np.array([[float(v) for v in z.split()] for z in zeilen[2:]])
    return namen, eltern, offsets, kanal_start, kanal_arten, bildzeit, bilder


def _rot(achse, grad):
    w = np.radians(grad)
    c, s = np.cos(w), np.sin(w)
    if achse == "X":
        return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
    if achse == "Y":
        return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def globale_rotationen(namen, eltern, kanal_start, kanal_arten, bild):
    """Weltrotation je Gelenk für ein Einzelbild."""
    rot = [None] * len(namen)
    for i, name in enumerate(namen):
        lokal = np.eye(3)
        arten = kanal_arten[i]
        start = kanal_start[i]
        for k, art in enumerate(arten):
            if art.endswith("rotation"):
                lokal = lokal @ _rot(art[0], bild[start + k])
        rot[i] = lokal if eltern[i] < 0 else rot[eltern[i]] @ lokal
    return rot


def matrix_zu_quat(m):
    w = np.sqrt(max(0.0, 1 + m[0, 0] + m[1, 1] + m[2, 2])) / 2
    if w > 1e-6:
        return np.array([
            (m[2, 1] - m[1, 2]) / (4 * w),
            (m[0, 2] - m[2, 0]) / (4 * w),
            (m[1, 0] - m[0, 1]) / (4 * w), w])
    # Rückfall über die größte Diagonale.
    i = int(np.argmax([m[0, 0], m[1, 1], m[2, 2]]))
    j, k = (i + 1) % 3, (i + 2) % 3
    s = np.sqrt(max(1e-9, 1 + m[i, i] - m[j, j] - m[k, k])) * 2
    q = np.zeros(4)
    q[i] = s / 4
    q[j] = (m[j, i] + m[i, j]) / s
    q[k] = (m[k, i] + m[i, k]) / s
    q[3] = (m[k, j] - m[j, k]) / s
    return q


def verarbeiten(pfad, ist_gang, ausgabe):
    namen, eltern, offsets, ks, ka, bildzeit, bilder = bvh_lesen(pfad)
    idx = {n: i for i, n in enumerate(namen)}
    fps_roh = 1.0 / bildzeit

    # Hüfthöhe der Nullpose als Maßstab (Hüfte -> Boden über die Beinkette).
    beinkette = ["LeftUpLeg", "LeftLeg", "LeftFoot"]
    hueft_hoehe = -sum(offsets[idx[k]][1] for k in ["LeftUpLeg"]) \
        + sum(-offsets[idx[k]][1] for k in ["LeftLeg", "LeftFoot"])
    hueft_hoehe = abs(offsets[idx["LeftUpLeg"]][1]) \
        + abs(offsets[idx["LeftLeg"]][1]) + abs(offsets[idx["LeftFoot"]][1])

    wurzel = bilder[:, 0:3]  # Xpos Ypos Zpos der Hüfte

    # Laufrichtung des Ausschnitts -> +Z drehen. Eine Stehaufnahme hat keinen
    # Laufweg — dort richtet die mittlere Blickrichtung der Hüfte aus, sonst
    # steht die Figur so verdreht da, wie der Aufgenommene zufällig stand.
    fahrt = wurzel[-1] - wurzel[0]
    fahrt[1] = 0.0
    # Schwelle in CMU-Einheiten (~6 cm je Einheit): erst ab ~1,2 m Weg gilt
    # der Ausschnitt als Gang — eine wartende Person driftet auch mal 30 cm.
    if np.linalg.norm(fahrt) > 20.0:
        fahrt = fahrt / np.linalg.norm(fahrt)
        winkel = np.arctan2(fahrt[0], fahrt[2])
        dreh = _rot("Y", -np.degrees(winkel))
    else:
        vorn = np.zeros(2)
        for f in range(0, len(bilder), max(1, len(bilder) // 60)):
            rot = globale_rotationen(namen, eltern, ks, ka, bilder[f])
            blick = rot[idx["Hips"]] @ np.array([0.0, 0.0, 1.0])
            vorn += [blick[0], blick[2]]
        winkel = np.arctan2(vorn[0], vorn[1])
        dreh = _rot("Y", -np.degrees(winkel))

    # Für den Gang: nahtlose Schleife suchen (Posen der Beine vergleichen).
    n = len(bilder)
    if ist_gang:
        beine = [idx[k] for k in ["LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg"]]
        posen = []
        for f in range(n):
            rot = globale_rotationen(namen, eltern, ks, ka, bilder[f])
            posen.append(np.concatenate([matrix_zu_quat(rot[b]) for b in beine]))
        posen = np.array(posen)
        best = (1e9, 0, n - 1)
        for s in range(10, n // 3):
            for e in range(s + n // 3, n - 5):
                d = np.linalg.norm(posen[s] - posen[e])
                if d < best[0]:
                    best = (d, s, e)
        _, start, ende = best
    else:
        start, ende = 5, n - 5

    # Gang auf ~30, Stehen auf ~15 Bilder je Sekunde ausdünnen (die Laufzeit
    # blendet zwischen den Bildern); Stehen zusätzlich auf 25 s begrenzen.
    schritt = max(1, round(fps_roh / (30.0 if ist_gang else 15.0)))
    auswahl = list(range(start, ende, schritt))
    fps = fps_roh / schritt
    if not ist_gang:
        auswahl = auswahl[:int(25 * fps)]

    spuren = {modell: [] for _, modell, _, _ in ZUORDNUNG}
    arten = {modell: art for _, modell, art, _ in ZUORDNUNG}
    hueft_y = []
    for f in auswahl:
        rot = globale_rotationen(namen, eltern, ks, ka, bilder[f])
        for bvh_name, modell, art, kind in ZUORDNUNG:
            g = dreh @ rot[idx[bvh_name]]
            if art == "voll":
                q = matrix_zu_quat(g)
                # Vorzeichen stetig halten — q und -q sind dieselbe Drehung,
                # aber Sprünge würden die Laufzeit-Überblendung stören.
                if spuren[modell] and np.dot(q, spuren[modell][-1]) < 0:
                    q = -q
                spuren[modell].append([round(float(v), 5) for v in q])
            else:
                richtung = g @ (offsets[idx[kind]] / np.linalg.norm(offsets[idx[kind]]))
                spuren[modell].append([round(float(v), 5) for v in richtung])
        hueft_y.append(wurzel[f][1])

    hueft_y = np.array(hueft_y)
    weg = 0.0
    if ist_gang:
        strecke = (dreh @ (wurzel[ende] - wurzel[start]))[2]
        weg = float(strecke / hueft_hoehe)  # Meter je Schleife, in Hüfthöhen

    daten = {
        "fps": round(fps, 3),
        "bilder": len(auswahl),
        "weg_je_schleife": round(weg, 4),
        "hueft_hub": [round(float(v - hueft_y.mean()) / hueft_hoehe, 5) for v in hueft_y],
        "arten": arten,
        "spuren": spuren,
    }
    WURZEL.mkdir(parents=True, exist_ok=True)
    (WURZEL / ausgabe).write_text(json.dumps(daten))
    print(f"  {ausgabe}: {len(auswahl)} bilder @ {fps:.1f} fps, "
          f"schleife {weg:.2f} hüfthöhen, quelle {Path(pfad).name}")


if __name__ == "__main__":
    verarbeiten(sys.argv[1], True, "gehen.json")
    verarbeiten(sys.argv[2], False, "stehen.json")
    print("fertig")
