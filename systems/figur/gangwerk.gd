class_name Gangwerk
extends RefCounted

## Prozedurales Gangwerk: bewegt ein Skelett ohne Animationsdateien.
##
## Die Modelle kommen mit Skelett, aber ohne Animationen — und eine Figur, die
## starr durch Berlin gleitet, ist schlimmer als eine Kapsel, weil sie aussieht
## wie eine Schaufensterpuppe auf Rollen. Dieses Gangwerk schwenkt die Knochen
## selbst: Beine gegengleich, Arme gegenläufig zu den Beinen, ein leichtes
## Wippen der Hüfte, im Stand ein ruhiges Atmen. Kein Ersatz für echte
## Animationen, aber der Unterschied zwischen Puppe und Person.
##
## Zwei Entscheidungen tragen das Ganze:
##
## 1. **Die Phase läuft über den zurückgelegten Weg**, nicht über die Zeit —
##    dasselbe Prinzip wie bei den Schrittgeräuschen, mit derselben
##    Schrittlänge. Wer schneller geht, schreitet schneller aus, die Füße
##    „rutschen" nicht, und Bild und Ton bleiben von selbst ungefähr im Takt.
##
## 2. **Gedreht wird im Skelettraum** (um dessen X-Achse), nicht in den lokalen
##    Achsen der Knochen. Wie ein Oberschenkelknochen orientiert ist, hängt vom
##    Werkzeug ab, das ihn gebaut hat; „vor und zurück" ist im Skelettraum
##    überall dasselbe. Kinder werden nach den Eltern gesetzt — Fuß nach
##    Unterschenkel nach Oberschenkel —, dadurch sind die Winkel absolut und
##    der Fuß bleibt von allein annähernd parallel zum Boden.
##
## Alle Winkel skalieren mit der Intensität (0 = stehen, 1 = volles Gangbild),
## die dem Tempo weich nachläuft. Beim Anhalten kehrt die Figur dadurch von
## selbst in die Ruhehaltung zurück, egal wo im Schritt sie gerade war.

## Weg für einen vollen Gangzyklus (zwei Schritte), in Metern. Die Hälfte davon
## ist die Schrittlänge — passend zu `Schritte.schrittlaenge` (1,5 m), damit
## Tritt und Ton zusammenfallen.
var zyklus_laenge: float = 3.0
## Wie weit die Oberschenkel bei vollem Gangbild ausschwingen.
var beinschwung_grad: float = 26.0
## Wie weit das Knie beim Durchschwingen beugt.
var knie_grad: float = 32.0
## Wie stark die Arme gegenschwingen.
var armschwung_grad: float = 15.0
## Ständige leichte Ellbogenbeugung — ganz gestreckte Arme wirken militärisch.
var ellbogen_grad: float = 9.0
## Vorlage des Oberkörpers bei vollem Tempo.
var neigung_grad: float = 3.5
## Wie tief die Hüfte bei jedem Schritt einfedert (Meter).
var wippen_meter: float = 0.022
## Atembewegung im Stand, in Grad am Brustwirbel.
var atem_grad: float = 1.1
## Atemzüge je Sekunde im Stand.
var atem_frequenz: float = 0.27
## Ab diesem Tempo (m/s) ist das Gangbild voll ausgeprägt.
var voll_bei_tempo: float = 3.2
## Wie schnell die Intensität dem Tempo nachläuft.
var glaettung: float = 8.0

## Reihenfolge ist Absicht: Eltern vor Kindern, sonst rechnet ein gesetzter
## Fuß mit der alten Lage seines Unterschenkels.
const _KNOCHEN: Array[StringName] = [
	&"Hips", &"Spine1",
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


## Merkt sich die Ruhelage aller beteiligten Knochen. Muss laufen, nachdem die
## Grundhaltung steht (Arme gesenkt) — sie ist die Basis aller Schwünge.
## Liefert false, wenn dem Skelett ein Knochen fehlt; dann bleibt es starr.
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


## Ein Physikschritt: `tempo` ist die tatsächliche waagerechte Geschwindigkeit
## der Figur. Alles Weitere — Takt, Ausschlag, Rückkehr zur Ruhe — folgt daraus.
func tick(delta: float, tempo: float) -> void:
	if _skelett == null:
		return
	_zeit += delta
	var ziel := clampf(tempo / voll_bei_tempo, 0.0, 1.0)
	_intensitaet = lerpf(_intensitaet, ziel, 1.0 - exp(-glaettung * delta))
	if _intensitaet > 0.01:
		_phase = fposmod(_phase + tempo * delta * TAU / zyklus_laenge, TAU)

	var s := _intensitaet
	var bein_links := deg_to_rad(beinschwung_grad) * s * sin(_phase)
	var bein_rechts := deg_to_rad(beinschwung_grad) * s * sin(_phase + PI)
	# Das Knie beugt, während das Bein nach vorn durchschwingt — der Versatz
	# von 2,4 rad legt den Beugegipfel in die Mitte des Durchschwungs.
	var knie_links := deg_to_rad(knie_grad) * s * maxf(0.0, sin(_phase + 2.4))
	var knie_rechts := deg_to_rad(knie_grad) * s * maxf(0.0, sin(_phase + PI + 2.4))
	var arm_links := deg_to_rad(armschwung_grad) * s * sin(_phase + PI)
	var arm_rechts := deg_to_rad(armschwung_grad) * s * sin(_phase)
	var ellbogen := deg_to_rad(ellbogen_grad) * (0.4 + 0.6 * s)
	var atmen := deg_to_rad(atem_grad) * (1.0 - s) * sin(TAU * atem_frequenz * _zeit)
	# Das Einfedern verschiebt die Hüfte als einzigen Knochen wirklich — alle
	# anderen behalten ihre lokale Position und folgen der Elternkette.
	_skelett.set_bone_pose_position(
		_index[&"Hips"],
		_hueft_ruhe + Vector3(0.0, -wippen_meter * s * absf(sin(_phase)), 0.0)
	)
	_setze(&"Hips", 0.0)
	_setze(&"Spine1", deg_to_rad(neigung_grad) * s + atmen)

	_setze(&"LeftUpLeg", bein_links)
	_setze(&"LeftLeg", bein_links - knie_links)
	_setze(&"LeftFoot", bein_links * 0.3)
	_setze(&"RightUpLeg", bein_rechts)
	_setze(&"RightLeg", bein_rechts - knie_rechts)
	_setze(&"RightFoot", bein_rechts * 0.3)

	_setze(&"LeftArm", arm_links)
	_setze(&"LeftForeArm", arm_links + ellbogen)
	_setze(&"RightArm", arm_rechts)
	_setze(&"RightForeArm", arm_rechts + ellbogen)


## Setzt die Drehung eines Knochens: Ruhelage plus Vorwärtsneigung, absolut im
## Skelettraum. Nur die Drehung — die Position bleibt lokal unangetastet, damit
## Knie und Fuß dem Oberschenkel folgen, statt an ihrer Ruheposition zu kleben.
##
## `vorwaerts` > 0 kippt zur Blickrichtung der Figur. Im Skelettraum schaut das
## Modell nach +Z (die Figur dreht es als Ganzes um 180°); eine Drehung um +X
## bewegt einen Punkt unterhalb des Gelenks nach −Z, nach vorn kippen heißt
## also um −X drehen.
##
## Die gewünschte Skelettraum-Drehung wird über die **aktuelle** Lage des
## Elternknochens in eine lokale übersetzt — deshalb Eltern vor Kindern.
func _setze(name: StringName, vorwaerts: float) -> void:
	var idx: int = _index[name]
	var soll: Basis = Basis(Vector3.RIGHT, -vorwaerts) * _ruhe_basis[name]

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
