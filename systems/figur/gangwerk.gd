class_name Gangwerk
extends RefCounted

## Prozedurales Gangwerk: bewegt ein Skelett ohne Animationsdateien.
##
## Die Modelle kommen mit Skelett, aber ohne Animationen — und eine Figur, die
## starr durch Berlin gleitet, ist schlimmer als eine Kapsel, weil sie aussieht
## wie eine Schaufensterpuppe auf Rollen. Dieses Gangwerk schwenkt die Knochen
## selbst. Kein Ersatz für aufgenommene Bewegung, aber der Unterschied zwischen
## Puppe und Person.
##
## Was eine Bewegung „echt" aussehen lässt, ist weniger der einzelne Schwung
## als das Zusammenspiel der Nebenbewegungen. Deshalb steuert das Gangwerk
## nicht nur die Beine:
##
## * **Becken und Schultern drehen gegeneinander.** Das Becken folgt dem
##   führenden Bein, der Brustkorb hält dagegen — das ist der Unterschied
##   zwischen Marschieren und Gehen.
## * **Das Gewicht wandert.** Die Hüfte verschiebt sich seitlich über das
##   Standbein und federt bei jedem Schritt ein.
## * **Die Füße rollen ab**, statt parallel zum Boden zu schweben: die Spitze
##   hebt sich beim Durchschwingen, der hintere Fuß drückt sich ab.
## * **Die Arme pendeln nach**, mit leichtem Verzug im Unterarm — geschleudert,
##   nicht geschoben.
## * **Der Kopf lebt.** Er kann ein Ziel ansehen (den Gesprächspartner, die
##   Spielerin), nickt zur eigenen Sprechzeile und schaut im Stand gelegentlich
##   beiläufig umher. Nacken und Kopf teilen sich die Drehung, wie bei Menschen.
## * **Im Stand** bleibt die Figur nie ganz still: Atmen, langsame
##   Gewichtsverlagerung von Bein zu Bein.
##
## Zwei technische Entscheidungen tragen alles:
##
## 1. **Die Phase läuft über den zurückgelegten Weg**, nicht über die Zeit —
##    dasselbe Prinzip wie bei den Schrittgeräuschen, mit derselben
##    Schrittlänge. Füße rutschen nicht, Bild und Ton bleiben im Takt.
## 2. **Gedreht wird im Skelettraum**, nur die Drehung, nie die Position:
##    Kinder folgen der Elternkette (Eltern werden vor Kindern gesetzt), der
##    Fuß bleibt dadurch von allein in Bodennähe kontrolliert.
##
## Alle Winkel skalieren mit der Intensität (0 = stehen, 1 = volles Gangbild),
## die dem Tempo weich nachläuft — beim Anhalten kehrt die Figur von selbst in
## die Ruhehaltung zurück, egal wo im Schritt sie war.

## Weg für einen vollen Gangzyklus (zwei Schritte), in Metern — passend zu
## `Schritte.schrittlaenge` (1,5 m), damit Tritt und Ton zusammenfallen.
var zyklus_laenge: float = 3.0
## Wie weit die Oberschenkel bei vollem Gangbild ausschwingen.
var beinschwung_grad: float = 26.0
## Wie weit das Knie beim Durchschwingen beugt.
var knie_grad: float = 32.0
## Wie weit die Fußspitze beim Durchschwingen anhebt bzw. beim Abdruck senkt.
var fussrolle_grad: float = 14.0
## Wie stark die Arme gegenschwingen. Eng am Körper hängende Arme schwingen
## sichtbar weniger als die alten, abgespreizten.
var armschwung_grad: float = 13.0
## Verzug des Unterarms hinter dem Oberarm, im Bogenmaß der Phase.
var arm_verzug: float = 0.55
## Ständige leichte Ellbogenbeugung — ganz gestreckte Arme wirken militärisch.
var ellbogen_grad: float = 11.0
## Drehung des Beckens um die Hochachse je Schritt.
var hueft_dreh_grad: float = 6.0
## Gegendrehung des Brustkorbs. Etwas kleiner als die Hüfte — der Oberkörper
## läuft dem Becken nach, er spiegelt es nicht.
var schulter_dreh_grad: float = 4.0
## Seitliche Gewichtsverlagerung über das Standbein (Meter).
var gewicht_seitlich: float = 0.020
## Vorlage des Oberkörpers bei vollem Tempo.
var neigung_grad: float = 3.5
## Wie tief die Hüfte bei jedem Schritt einfedert (Meter).
var wippen_meter: float = 0.02
## Atembewegung im Stand, in Grad am Brustwirbel.
var atem_grad: float = 1.1
## Atemzüge je Sekunde im Stand.
var atem_frequenz: float = 0.27
## Ab diesem Tempo (m/s) ist das Gangbild voll ausgeprägt.
var voll_bei_tempo: float = 3.2
## Wie schnell die Intensität dem Tempo nachläuft.
var glaettung: float = 8.0
## Größte Kopfdrehung zur Seite bzw. nach oben/unten (Bogenmaß).
var blick_gier_max: float = 1.05
var blick_nick_max: float = 0.4
## Wie schnell der Blick einem neuen Ziel folgt.
var blick_folge: float = 5.0

## Weltpunkt, den die Figur ansieht. `Vector3.INF` heißt: kein Ziel, geradeaus
## (im Stand mit beiläufigem Umherschauen).
var blick_ziel: Vector3 = Vector3.INF
## 1 setzen, wenn die Figur eine Zeile zu sprechen beginnt: ein kurzes Nicken,
## das von selbst abklingt.
var betonung: float = 0.0

## Reihenfolge ist Absicht: Eltern vor Kindern, sonst rechnet ein gesetzter
## Fuß mit der alten Lage seines Unterschenkels.
const _KNOCHEN: Array[StringName] = [
	&"Hips", &"Spine1", &"Spine2", &"Neck", &"Head",
	&"LeftUpLeg", &"LeftLeg", &"LeftFoot",
	&"RightUpLeg", &"RightLeg", &"RightFoot",
	&"LeftArm", &"LeftForeArm",
	&"RightArm", &"RightForeArm",
]

var _skelett: Skeleton3D
var _index: Dictionary = {}
var _ruhe_basis: Dictionary = {}
var _hueft_ruhe: Vector3
var _phase: float = 0.0
var _zeit: float = 0.0
var _intensitaet: float = 0.0
var _gier: float = 0.0
var _nick: float = 0.0
var _lehnen: float = 0.0


## Merkt sich die Ruhelage aller beteiligten Knochen. Muss laufen, nachdem die
## Grundhaltung steht (Arme gesenkt, Hände entspannt) — sie ist die Basis
## aller Schwünge. Liefert false, wenn ein Knochen fehlt; dann bleibt es starr.
func einrichten(skelett: Skeleton3D) -> bool:
	if skelett == null:
		return false
	for name in _KNOCHEN:
		var idx := skelett.find_bone(name)
		if idx < 0:
			push_warning("Gangwerk: Knochen '%s' fehlt — Figur bleibt starr." % name)
			return false
		_index[name] = idx
		_ruhe_basis[name] = skelett.get_bone_global_pose(idx).basis.orthonormalized()
	_hueft_ruhe = skelett.get_bone_pose_position(skelett.find_bone("Hips"))
	_skelett = skelett
	return true


## Ein Physikschritt. `tempo` ist die tatsächliche waagerechte Geschwindigkeit,
## `gier_rate` die Drehgeschwindigkeit der Figur (rad/s) fürs Hineinlehnen in
## Kurven. Alles Weitere — Takt, Ausschlag, Rückkehr zur Ruhe — folgt daraus.
func tick(delta: float, tempo: float, gier_rate: float = 0.0) -> void:
	if _skelett == null:
		return
	_zeit += delta
	var ziel := clampf(tempo / voll_bei_tempo, 0.0, 1.0)
	_intensitaet = lerpf(_intensitaet, ziel, 1.0 - exp(-glaettung * delta))
	if _intensitaet > 0.01:
		_phase = fposmod(_phase + tempo * delta * TAU / zyklus_laenge, TAU)
	betonung = maxf(betonung - delta * 2.2, 0.0)
	_lehnen = lerpf(_lehnen, clampf(-gier_rate * 0.045, -0.08, 0.08), 1.0 - exp(-6.0 * delta))

	var s := _intensitaet
	var ruhe := 1.0 - s

	# --- Beine: Schwung, Kniebeugung im Durchschwung, abrollende Füße ------
	var bein_l := deg_to_rad(beinschwung_grad) * s * sin(_phase)
	var bein_r := deg_to_rad(beinschwung_grad) * s * sin(_phase + PI)
	var knie_l := deg_to_rad(knie_grad) * s * maxf(0.0, sin(_phase + 2.4))
	var knie_r := deg_to_rad(knie_grad) * s * maxf(0.0, sin(_phase + PI + 2.4))
	# Spitze hoch, wenn das Bein vorn durchschwingt (mit dem Knie), Spitze
	# runter beim Abdruck hinten (wenn das Bein nach hinten zeigt).
	var rolle_l := deg_to_rad(fussrolle_grad) * s * (0.7 * maxf(0.0, sin(_phase + 2.4)) - 0.9 * maxf(0.0, -sin(_phase)))
	var rolle_r := deg_to_rad(fussrolle_grad) * s * (0.7 * maxf(0.0, sin(_phase + PI + 2.4)) - 0.9 * maxf(0.0, -sin(_phase + PI)))

	# --- Arme: gegenläufig, der Unterarm läuft nach ------------------------
	var arm_l := deg_to_rad(armschwung_grad) * s * sin(_phase + PI)
	var arm_r := deg_to_rad(armschwung_grad) * s * sin(_phase)
	var unterarm_l := deg_to_rad(armschwung_grad) * 0.5 * s * sin(_phase + PI - arm_verzug)
	var unterarm_r := deg_to_rad(armschwung_grad) * 0.5 * s * sin(_phase - arm_verzug)
	var ellbogen := deg_to_rad(ellbogen_grad) * (0.8 + 0.2 * s)

	# --- Rumpf: Gegendrehung, Gewicht, Atem, Vorlage ------------------------
	var hueft_gier := deg_to_rad(hueft_dreh_grad) * s * sin(_phase)
	var schulter_gier := -deg_to_rad(schulter_dreh_grad) * s * sin(_phase)
	var atmen := deg_to_rad(atem_grad) * ruhe * sin(TAU * atem_frequenz * _zeit)
	# Im Stand wandert das Gewicht langsam von Bein zu Bein; beim Gehen liegt
	# es im Schritttakt über dem Standbein.
	var pendeln := ruhe * 0.014 * sin(TAU * 0.09 * _zeit)
	var seitlich := gewicht_seitlich * s * sin(_phase + PI * 0.5) + pendeln
	var einfedern := -wippen_meter * s * absf(sin(_phase))

	_skelett.set_bone_pose_position(
		_index[&"Hips"], _hueft_ruhe + Vector3(seitlich, einfedern, 0.0)
	)
	_setze(&"Hips", Basis(Vector3.UP, hueft_gier))
	_setze(&"Spine1",
		Basis(Vector3.UP, schulter_gier * 0.5)
		* Basis(Vector3.RIGHT, -(deg_to_rad(neigung_grad) * s + atmen))
		* Basis(Vector3(0, 0, 1), _lehnen + pendeln * 1.6))
	_setze(&"Spine2", Basis(Vector3.UP, schulter_gier * 0.5))

	_blick(delta, ruhe)

	_setze(&"LeftUpLeg", Basis(Vector3.RIGHT, -bein_l))
	_setze(&"LeftLeg", Basis(Vector3.RIGHT, -(bein_l - knie_l)))
	_setze(&"LeftFoot", Basis(Vector3.RIGHT, -(bein_l * 0.2 + rolle_l)))
	_setze(&"RightUpLeg", Basis(Vector3.RIGHT, -bein_r))
	_setze(&"RightLeg", Basis(Vector3.RIGHT, -(bein_r - knie_r)))
	_setze(&"RightFoot", Basis(Vector3.RIGHT, -(bein_r * 0.2 + rolle_r)))

	_setze(&"LeftArm", Basis(Vector3.RIGHT, -arm_l))
	_setze(&"LeftForeArm", Basis(Vector3.RIGHT, -(unterarm_l + ellbogen)))
	_setze(&"RightArm", Basis(Vector3.RIGHT, -arm_r))
	_setze(&"RightForeArm", Basis(Vector3.RIGHT, -(unterarm_r + ellbogen)))


## Kopf und Nacken: dem Ziel folgen, sonst beiläufig umherschauen; dazu das
## Nicken der Betonung. Nacken und Kopf teilen sich die Drehung 35/65 — ein
## Kopf, der allein auf dem starren Hals dreht, sieht mechanisch aus.
func _blick(delta: float, ruhe: float) -> void:
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
		# Beiläufig: zwei ungleiche, langsame Wellen — kein erkennbares Muster.
		soll_gier = ruhe * (0.11 * sin(0.23 * _zeit) + 0.06 * sin(0.71 * _zeit + 1.7))
		soll_nick = ruhe * 0.04 * sin(0.31 * _zeit + 0.8)

	var w := 1.0 - exp(-blick_folge * delta)
	_gier = lerpf(_gier, soll_gier, w)
	_nick = lerpf(_nick, soll_nick, w)

	# Das Nicken: ein weicher Bogen abwärts und zurück, ausgelöst über
	# `betonung = 1.0`, abklingend in tick().
	var nicken := 0.14 * sin(PI * (1.0 - betonung)) if betonung > 0.0 else 0.0

	_setze(&"Neck", Basis(Vector3.UP, _gier * 0.35) * Basis(Vector3.RIGHT, (_nick - nicken) * 0.35))
	_setze(&"Head", Basis(Vector3.UP, _gier * 0.65) * Basis(Vector3.RIGHT, (_nick - nicken) * 0.65))


## Setzt einen Knochen auf Ruhelage plus Drehung, absolut im Skelettraum. Nur
## die Drehung — die Position bleibt lokal, damit Knie und Fuß dem Oberschenkel
## folgen statt an ihrer Ruheposition zu kleben.
##
## Vorzeichen: das Modell schaut im Skelettraum nach +Z (die Figur dreht es als
## Ganzes um 180°); eine Drehung um −X kippt nach vorn. Die gewünschte Drehung
## wird über die **aktuelle** Lage des Elternknochens in eine lokale übersetzt —
## deshalb Eltern vor Kindern.
func _setze(name: StringName, drehung: Basis) -> void:
	var idx: int = _index[name]
	var soll: Basis = drehung * _ruhe_basis[name]
	var eltern := _skelett.get_bone_parent(idx)
	if eltern >= 0:
		soll = _skelett.get_bone_global_pose(eltern).basis.orthonormalized().inverse() * soll
	_skelett.set_bone_pose_rotation(idx, Quaternion(soll.orthonormalized()))


## Wo im Schritt die Figur gerade ist — für Prüfläufe und, später, um Ton und
## Bild exakt zu verkoppeln.
func phase() -> float:
	return _phase


## Aktuelle Intensität, 0 = ruhig stehend, 1 = volles Gangbild.
func intensitaet() -> float:
	return _intensitaet


## Aktuelle Kopfdrehung zur Seite (Bogenmaß) — für Prüfläufe.
func blick_gier() -> float:
	return _gier
