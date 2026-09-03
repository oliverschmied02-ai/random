class_name Mocap
extends RefCounted

## Echte aufgenommene Bewegung statt prozeduralem Gangwerk.
##
## Die Daten stammen aus der freien CMU-Motion-Capture-Datenbank (BVH),
## umgerechnet von `tools/bvh_konverter.py` in zwei Schleifen: Gehen
## (`assets/mocap/gehen.json`, ein Gangzyklus) und Stehen
## (`stehen.json`, ~25 s „auf den Bus warten" — Gewichtsverlagerung,
## kleine Haltungswechsel, alles echt).
##
## Das Retargeting läuft zweigleisig, weil die Nullpose des CMU-Skeletts
## nur teilweise zur T-Pose der Modelle passt:
##
## * **Rumpf, Kopf, Hüfte** übernehmen die volle Weltrotation der Aufnahme —
##   dort sind beide Skelette aufrecht, die Übertragung stimmt direkt.
## * **Arme und Beine** übernehmen nur die aufgenommene **Knochenrichtung**:
##   die Ruherichtung des Modells wird per kürzestem Bogen auf die
##   aufgenommene gedreht. Das ist unempfindlich gegen die gespreizte
##   CMU-Nullpose und erhält die Ruhehaltung (hängende Arme) als Basis.
##
## Vom Gangwerk übernommen und bewährt: die Phase läuft über den
## **zurückgelegten Weg** (Füße rutschen nicht, Ton bleibt im Takt), gesetzt
## wird **nur die Drehung im Skelettraum**, Eltern vor Kindern. Der Blick
## (Ziel ansehen, Nicken zur Sprechzeile) legt sich als dünne Schicht über
## die Aufnahme. Die Schnittstelle ist mit dem Gangwerk identisch — die
## Figur merkt nicht, wer sie bewegt, und fällt ohne Daten aufs Gangwerk
## zurück.

const GEHEN_PFAD := "res://assets/mocap/gehen.json"
const STEHEN_PFAD := "res://assets/mocap/stehen.json"
const SPRECHEN_PFAD := "res://assets/mocap/sprechen.json"

## Streckt die aufgenommene Schrittlänge. Die CMU-Person ging gemütliche
## 1,5 m/s; die Spielfigur geht 3,4 m/s. Ohne Streckung wirbelte der Gang
## im Doppeltakt — mit ihr wird der Schritt länger und ruhiger, um den
## Preis eines leichten Gleitens der Füße.
var strecken_faktor: float = 1.4
## Ab diesem Tempo (m/s) zählt die Figur als voll gehend.
var voll_bei_tempo: float = 1.3
## Wieviel der seitlichen Armhaltung aus der Aufnahme übernommen wird. Die
## CMU-Anzüge mit Markern lassen die Arme weiter abstehen, als entspannte
## Arme hängen — der Schwung (vor/zurück) bleibt voll erhalten, nur das
## Abspreizen wird Richtung Ruhehaltung gedämpft.
var arm_seite_anteil: float = 0.3
var glaettung: float = 8.0
## Die Aufnahme liefert nur Drehungen — Einfedern und Gewichtsverlagerung
## der Hüfte kommen als dünne Positionsschicht obendrauf, sonst gleitet
## der Rumpf wie auf Schienen (die sichtbarste Steifheit des alten Gangs).
var wippen_meter: float = 0.018
var gewicht_seitlich: float = 0.018
var blick_gier_max: float = 1.05
var blick_nick_max: float = 0.4
var blick_folge: float = 5.0

var blick_ziel: Vector3 = Vector3.INF
var betonung: float = 0.0
## true, solange die Figur ihre Sprechzeile hat — dann erklärt sie mit den
## Händen (CMU-Aufnahme 18_08), weich ein- und ausgeblendet.
var spricht: bool = false

## Eltern vor Kindern — dieselbe Regel wie im Gangwerk.
const _KNOCHEN: Array[StringName] = [
	&"Hips", &"Spine", &"Spine1", &"Spine2", &"Neck", &"Head",
	&"LeftShoulder", &"LeftArm", &"LeftForeArm",
	&"RightShoulder", &"RightArm", &"RightForeArm",
	&"LeftUpLeg", &"LeftLeg", &"LeftFoot",
	&"RightUpLeg", &"RightLeg", &"RightFoot",
]

## Kindknochen je Richtungs-Knochen, um die Ruherichtung des Modells zu messen.
const _KINDER := {
	&"LeftShoulder": &"LeftArm", &"LeftArm": &"LeftForeArm", &"LeftForeArm": &"LeftHand",
	&"RightShoulder": &"RightArm", &"RightArm": &"RightForeArm", &"RightForeArm": &"RightHand",
	&"LeftUpLeg": &"LeftLeg", &"LeftLeg": &"LeftFoot", &"LeftFoot": &"LeftToeBase",
	&"RightUpLeg": &"RightLeg", &"RightLeg": &"RightFoot", &"RightFoot": &"RightToeBase",
}

static var _gehen: Dictionary = {}
static var _stehen: Dictionary = {}
static var _sprechen: Dictionary = {}

var _skelett: Skeleton3D
var _index: Dictionary = {}
var _ruhe_basis: Dictionary = {}
var _ruhe_richtung: Dictionary = {}
var _hueft_ruhe: Vector3
var _lehnen: float = 0.0
var _zyklus_meter: float = 3.0
var _weg: float = 0.0
var _zeit: float = 0.0
var _intensitaet: float = 0.0
var _sprech_gewicht: float = 0.0
var _gier: float = 0.0
var _nick: float = 0.0


static func daten_vorhanden() -> bool:
	return ResourceLoader.exists(GEHEN_PFAD) and ResourceLoader.exists(STEHEN_PFAD)


static func _laden(pfad: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(pfad)
	var roh: Dictionary = JSON.parse_string(text)
	# Spuren in PackedFloat32Array umpacken — JSON-Arrays sind zu träge.
	var spuren := {}
	for name in roh["spuren"]:
		var flach := PackedFloat32Array()
		for bild in roh["spuren"][name]:
			for wert in bild:
				flach.append(wert)
		spuren[StringName(name)] = flach
	roh["spuren"] = spuren
	return roh


## Liefert false, wenn Daten oder Knochen fehlen — dann bleibt das Gangwerk.
func einrichten(skelett: Skeleton3D) -> bool:
	if skelett == null or not daten_vorhanden():
		return false
	if _gehen.is_empty():
		_gehen = _laden(GEHEN_PFAD)
		_stehen = _laden(STEHEN_PFAD)
		if ResourceLoader.exists(SPRECHEN_PFAD):
			_sprechen = _laden(SPRECHEN_PFAD)
	for name in _KNOCHEN:
		var idx := skelett.find_bone(name)
		if idx < 0:
			push_warning("Mocap: Knochen '%s' fehlt — Gangwerk übernimmt." % name)
			return false
		_index[name] = idx
		_ruhe_basis[name] = skelett.get_bone_global_pose(idx).basis.orthonormalized()
	# Ruherichtungen der Gliedmaßen: vom Knochen zu seinem Kind.
	for name in _KINDER:
		var kind_idx := skelett.find_bone(_KINDER[name])
		if kind_idx < 0:
			push_warning("Mocap: Kindknochen '%s' fehlt — Gangwerk übernimmt." % _KINDER[name])
			return false
		var von: Vector3 = skelett.get_bone_global_pose(_index[name]).origin
		var zu: Vector3 = skelett.get_bone_global_pose(kind_idx).origin
		_ruhe_richtung[name] = (zu - von).normalized()
	# Schrittweite: die Aufnahme speichert sie in Hüfthöhen des CMU-Skeletts,
	# hier wird sie mit der Hüfthöhe des Modells zu Metern.
	var hueft_hoehe: float = skelett.get_bone_global_pose(_index[&"Hips"]).origin.y
	_zyklus_meter = maxf(0.5, _gehen["weg_je_schleife"] * hueft_hoehe * strecken_faktor)
	_hueft_ruhe = skelett.get_bone_pose_position(skelett.find_bone("Hips"))
	_skelett = skelett
	return true


func tick(delta: float, tempo: float, gier_rate: float = 0.0) -> void:
	if _skelett == null:
		return
	_zeit += delta
	_weg += tempo * delta
	var ziel := clampf(tempo / voll_bei_tempo, 0.0, 1.0)
	_intensitaet = lerpf(_intensitaet, ziel, 1.0 - exp(-glaettung * delta))
	betonung = maxf(betonung - delta * 2.2, 0.0)
	# In Kurven lehnt sich der Oberkörper hinein — die Aufnahme kennt nur
	# den geraden Gang.
	_lehnen = lerpf(_lehnen, clampf(-gier_rate * 0.045, -0.08, 0.08),
		1.0 - exp(-6.0 * delta))
	# Beim Sprechen erklärt die Figur mit den Händen — nur im Stand, und
	# weich ein- und ausgeblendet.
	var sprech_ziel := 1.0 if (spricht and not _sprechen.is_empty()) else 0.0
	_sprech_gewicht = lerpf(_sprech_gewicht, sprech_ziel, 1.0 - exp(-3.5 * delta))

	# Bildposition der Schleifen: Gehen läuft über den Weg (nahtlos
	# geschnitten), Stehen und Sprechen über die Zeit im Hin-und-zurück —
	# die langen Aufnahmen haben keinen Schleifenpunkt, gespiegelt brauchen
	# sie keinen.
	var gehen_bilder: int = _gehen["bilder"]
	var gehen_bild := fposmod(_weg / _zyklus_meter, 1.0) * gehen_bilder

	# Hüfte: einfedern bei jedem Schritt (zwei Tritte je Zyklus), Gewicht
	# seitlich übers Standbein; im Stand ein ganz langsames Pendeln.
	var ph := fposmod(_weg / _zyklus_meter, 1.0) * TAU
	var pendeln := (1.0 - _intensitaet) * 0.012 * sin(TAU * 0.09 * _zeit)
	var seitlich := gewicht_seitlich * _intensitaet * sin(ph + PI * 0.5) + pendeln
	var einfedern := -wippen_meter * _intensitaet * absf(sin(ph))
	_skelett.set_bone_pose_position(_index[&"Hips"],
		_hueft_ruhe + Vector3(seitlich, einfedern, 0.0))

	for name in _KNOCHEN:
		var soll := Basis(_stand_und_gang(name, gehen_bild, gehen_bilder))
		if name == &"Neck" or name == &"Head":
			continue  # kommt gleich, mit Blick obendrauf
		if name == &"Spine1":
			soll = Basis(Vector3(0, 0, 1), _lehnen + pendeln * 1.6) * soll
		_setze_global(name, soll)

	_blick(delta,
		Basis(_stand_und_gang(&"Neck", gehen_bild, gehen_bilder)),
		Basis(_stand_und_gang(&"Head", gehen_bild, gehen_bilder)))


## Die gemischte Zieldrehung eines Knochens: Stehen (ggf. mit Sprechgesten)
## und Gehen, gewichtet nach Sprechzustand und Tempo.
func _stand_und_gang(name: StringName, gehen_bild: float, gehen_bilder: int) -> Quaternion:
	var stand := Quaternion(_ziel_basis(_stehen, name, _pendel_bild(_stehen), _stehen["bilder"], false))
	if _sprech_gewicht > 0.01:
		var geste := Quaternion(_ziel_basis(_sprechen, name, _pendel_bild(_sprechen), _sprechen["bilder"], false))
		stand = stand.slerp(geste, _sprech_gewicht)
	if _intensitaet < 0.01:
		return stand
	return stand.slerp(Quaternion(_ziel_basis(_gehen, name, gehen_bild, gehen_bilder, true)), _intensitaet)


## Bildposition einer Zeit-Schleife im Hin-und-zurück.
func _pendel_bild(daten: Dictionary) -> float:
	var bilder: int = daten["bilder"]
	var lauf := fposmod(_zeit * float(daten["fps"]), 2.0 * (bilder - 1))
	return lauf if lauf < bilder - 1 else 2.0 * (bilder - 1) - lauf


## Die Ziel-Weltdrehung eines Knochens aus einer Schleife, zwischen zwei
## Bildern überblendet. `schleife` = true verbindet das letzte Bild mit dem
## ersten (Gehzyklus), sonst wird am Ende festgehalten.
func _ziel_basis(daten: Dictionary, name: StringName, bild: float, bilder: int, schleife: bool) -> Basis:
	var spur: PackedFloat32Array = daten["spuren"][name]
	var art: String = daten["arten"][name]
	var i0 := int(bild) % bilder
	var i1 := (i0 + 1) % bilder if schleife else mini(i0 + 1, bilder - 1)
	var t := bild - floorf(bild)
	if art == "voll":
		var a := Quaternion(spur[i0 * 4], spur[i0 * 4 + 1], spur[i0 * 4 + 2], spur[i0 * 4 + 3])
		var b := Quaternion(spur[i1 * 4], spur[i1 * 4 + 1], spur[i1 * 4 + 2], spur[i1 * 4 + 3])
		return Basis(a.slerp(b, t).normalized()) * _ruhe_basis[name]
	var r0 := Vector3(spur[i0 * 3], spur[i0 * 3 + 1], spur[i0 * 3 + 2])
	var r1 := Vector3(spur[i1 * 3], spur[i1 * 3 + 1], spur[i1 * 3 + 2])
	var richtung := r0.slerp(r1, t).normalized()
	var ruhe: Vector3 = _ruhe_richtung[name]
	if String(name).contains("Arm") or String(name).contains("Shoulder"):
		richtung.x = lerpf(ruhe.x, richtung.x, arm_seite_anteil)
		richtung = richtung.normalized()
	var achse := ruhe.cross(richtung)
	if achse.length_squared() < 1e-8:
		return _ruhe_basis[name]
	var winkel := ruhe.angle_to(richtung)
	return Basis(achse.normalized(), winkel) * _ruhe_basis[name]


## Blick über die Aufnahme legen: Nacken und Kopf bekommen die Mocap-Drehung
## plus Zielverfolgung bzw. Nicken — dieselbe Schicht wie im Gangwerk, nur
## dass die Basis darunter jetzt echt ist.
func _blick(delta: float, nacken_grund: Basis, kopf_grund: Basis) -> void:
	var soll_gier := 0.0
	var soll_nick := 0.0
	if blick_ziel.is_finite():
		var lokal := _skelett.global_transform.affine_inverse() * blick_ziel
		var kopf := _skelett.get_bone_global_pose(_index[&"Head"]).origin
		var d := lokal - kopf
		var flach := Vector2(d.x, d.z).length()
		soll_gier = clampf(atan2(d.x, d.z), -blick_gier_max, blick_gier_max)
		soll_nick = clampf(atan2(d.y, flach), -blick_nick_max * 0.6, blick_nick_max)
	else:
		# Ohne Ziel schaut die Figur im Stand beiläufig umher — zwei
		# ungleiche, langsame Wellen, wie im Gangwerk bewährt.
		var ruhe := 1.0 - _intensitaet
		soll_gier = ruhe * (0.11 * sin(0.23 * _zeit) + 0.06 * sin(0.71 * _zeit + 1.7))
		soll_nick = ruhe * 0.04 * sin(0.31 * _zeit + 0.8)
	var w := 1.0 - exp(-blick_folge * delta)
	_gier = lerpf(_gier, soll_gier, w)
	_nick = lerpf(_nick, soll_nick, w)
	var nicken := 0.14 * sin(PI * (1.0 - betonung)) if betonung > 0.0 else 0.0

	_setze_global(&"Neck",
		Basis(Vector3.UP, _gier * 0.35) * Basis(Vector3.RIGHT, (_nick - nicken) * 0.35)
		* nacken_grund)
	_setze_global(&"Head",
		Basis(Vector3.UP, _gier * 0.65) * Basis(Vector3.RIGHT, (_nick - nicken) * 0.65)
		* kopf_grund)


## Setzt die Ziel-Weltdrehung eines Knochens, nur Drehung, Eltern vor Kindern —
## wörtlich die Mechanik des Gangwerks.
func _setze_global(name: StringName, soll: Basis) -> void:
	var idx: int = _index[name]
	var eltern := _skelett.get_bone_parent(idx)
	if eltern >= 0:
		soll = _skelett.get_bone_global_pose(eltern).basis.orthonormalized().inverse() * soll
	_skelett.set_bone_pose_rotation(idx, Quaternion(soll.orthonormalized()))


func phase() -> float:
	return fposmod(_weg / _zyklus_meter, 1.0) * TAU


func intensitaet() -> float:
	return _intensitaet


func blick_gier() -> float:
	return _gier
