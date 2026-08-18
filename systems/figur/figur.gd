class_name Figur
extends Node3D

## Das sichtbare Modell einer Person — mit Kapsel als Rückfallebene.
##
## Solange kein Modell vorliegt, bleibt der Platzhalter stehen. Liegt eines
## vor, wird es geladen, auf die richtige Höhe skaliert und der Platzhalter
## verschwindet. Das Spiel läuft in beiden Fällen unverändert: Bewegung,
## Kollision und Kamera hängen an der Figur selbst, nie an ihrem Aussehen.
##
## Der Weg für ein neues Modell ist damit: Datei nach `actors/models/` legen,
## `modell_pfad` eintragen, fertig. Kein Code, keine Szene umbauen.
##
## **Maßstab.** Modelle kommen in unterschiedlichen Größen aus den Werkzeugen,
## und ein Mensch, der einen Kopf zu groß ist, fällt sofort auf. Deshalb wird
## nicht auf gut Glück skaliert, sondern gemessen: aus den Ausmaßen aller
## sichtbaren Teile ergibt sich die tatsächliche Höhe, daraus der Faktor auf
## `zielhoehe`. Wer die Skalierung von Hand setzen will, stellt `zielhoehe`
## auf 0.
##
## **Blickrichtung.** glTF-Figuren schauen üblicherweise nach +Z, in Godot ist
## vorne −Z. Ein Modell, das rückwärts läuft, ist fast immer genau das.

## Ressource mit dem Modell — eine importierte `.glb` oder eine `.tscn`.
## Leer oder nicht vorhanden heißt: Platzhalter behalten.
@export var modell_pfad: String = ""
## Höhe der fertigen Figur in Metern, Sohle bis Scheitel. 0 = nicht skalieren.
@export_range(0.0, 2.5, 0.01) var zielhoehe: float = 1.75
## Modell um 180° drehen, weil glTF-Figuren nach +Z schauen.
@export var blickrichtung_drehen: bool = true
## Wie weit die Arme aus der T-Pose gesenkt werden, in Grad.
##
## Modelle kommen mit waagerecht ausgestreckten Armen — das ist die Haltung, in
## der sie gebaut und später animiert werden, aber niemand steht so an einer
## Bushaltestelle. Ein natürlicher Arm hängt fast senkrecht: rund 10° bleiben
## zwischen Arm und Rumpf, mehr wirkt wie eine Schaufensterpuppe, weniger
## klemmt den Ärmel in die Jacke. 0 lässt die T-Pose stehen.
@export_range(0.0, 90.0, 1.0) var arme_senken_grad: float = 79.0
## Wie weit die hängenden Arme zusätzlich nach vorn kommen. Die Schultergelenke
## sitzen hinter der Körpermitte — ein senkrecht fallender Arm läge sonst zu
## weit hinten, echte Hände hängen neben dem Oberschenkel.
@export_range(0.0, 20.0, 0.5) var arme_vor_grad: float = 4.0
## Wie weit die Schultern aus der angespannten T-Pose absinken. Nimmt der
## Figur das „Schulterzucken" und holt die Arme näher an den Rumpf.
@export_range(0.0, 12.0, 0.5) var schultern_senken_grad: float = 4.0
## Ruhebeugung des Handgelenks — eine ganz gestreckte Hand wirkt wie ein Brett.
@export_range(0.0, 30.0, 1.0) var handgelenk_grad: float = 9.0
## Innenrotation der hängenden Arme, damit die Handflächen zum Oberschenkel
## zeigen statt nach hinten — die Haltung entspannter Schultern.
@export_range(0.0, 30.0, 1.0) var arme_eindrehen_grad: float = 14.0
## Bewegt das Skelett prozedural (Gehen, Atmen), solange es keine echten
## Animationen gibt. Aus, wenn später eine Animationsschicht übernimmt.
@export var gangwerk_aktiv: bool = true
## Was ausgeblendet wird, sobald ein Modell steht.
@export var platzhalter_pfad: NodePath = ^"Platzhalter"

## Das geladene Modell, oder null solange die Kapsel steht.
var modell: Node3D
## Das prozedurale Gangwerk, oder null (kein Modell, abgeschaltet, Rig fremd).
var gangwerk: Gangwerk

var _letzte_lage: Vector3
var _letzte_gier: float = 0.0
var _blick: Node3D
## Auf welcher Höhe über dem Ziel der Blick landet — Augenhöhe einer Figur.
var _blick_hoehe: float = 1.55


func _ready() -> void:
	set_physics_process(false)
	if modell_pfad.is_empty() or not ResourceLoader.exists(modell_pfad):
		return

	var geladen := load(modell_pfad)
	var szene := geladen as PackedScene
	if szene == null:
		push_warning("Figur: '%s' ist keine Szene." % modell_pfad)
		return

	modell = szene.instantiate() as Node3D
	if modell == null:
		push_warning("Figur: '%s' enthält keinen 3D-Knoten." % modell_pfad)
		return

	add_child(modell)
	if blickrichtung_drehen:
		modell.rotate_y(PI)
	_auf_hoehe_bringen()
	_arme_senken()
	_haende_entspannen()

	var platzhalter := get_node_or_null(platzhalter_pfad) as Node3D
	if platzhalter != null:
		platzhalter.visible = false

	# Das Gangwerk holt sich seine Ruhelage jetzt — nach dem Senken der Arme,
	# denn diese Haltung ist die Basis aller Schwünge.
	if gangwerk_aktiv:
		var werk := Gangwerk.new()
		if werk.einrichten(skelett_finden()):
			gangwerk = werk
			_letzte_lage = global_position
			set_physics_process(true)


func _physics_process(delta: float) -> void:
	# Das Tempo kommt aus der tatsächlich zurückgelegten Strecke, nicht aus der
	# `velocity` des Körpers: so schreitet die Figur auch dann aus, wenn eine
	# Sequenz sie per Tween bewegt — etwa auf die Abschlussmarken — und steht
	# still, sobald sie wirklich steht. Sprünge über einen Meter pro Physiktick
	# sind Teleports (Prüfläufe, Szenenumbauten), kein Rennen.
	var jetzt := global_position
	var weg := jetzt - _letzte_lage
	_letzte_lage = jetzt
	weg.y = 0.0
	var tempo := 0.0 if weg.length() > 1.0 else weg.length() / maxf(delta, 0.0001)

	# Drehgeschwindigkeit fürs Hineinlehnen in Kurven.
	var gier := global_rotation.y
	var gier_rate := angle_difference(_letzte_gier, gier) / maxf(delta, 0.0001)
	_letzte_gier = gier

	if _blick != null and not is_instance_valid(_blick):
		_blick = null
	gangwerk.blick_ziel = (
		_blick.global_position + Vector3.UP * _blick_hoehe if _blick != null
		else Vector3.INF
	)
	gangwerk.tick(delta, tempo, gier_rate)


## Lässt die Figur ein Ziel ansehen — den Gesprächspartner, die Spielerin.
## `null` gibt den Blick frei (geradeaus, im Stand beiläufig umherschauend).
## `hoehe` ist der Punkt über dem Zielursprung, auf den geschaut wird.
func schaue_an(ziel: Node3D, hoehe: float = 1.55) -> void:
	_blick = ziel
	_blick_hoehe = hoehe


## Ein kurzes Nicken — beim Beginn der eigenen Sprechzeile.
func betone() -> void:
	if gangwerk != null:
		gangwerk.betonung = 1.0


## Nimmt den Händen die gespreizte T-Pose: alle Fingerglieder leicht gebeugt,
## der Daumen kaum. Gespreizte Finger fallen in jeder Nahaufnahme sofort auf —
## entspannte Hände sind die halbe Natürlichkeit einer stehenden Figur.
##
## Gebeugt wird im **lokalen** Raum der Fingerknochen (Mixamo-Rigs beugen
## Finger um die lokale X-Achse) — die Glieder sind nicht Teil des Gangwerks
## und behalten diese Haltung dauerhaft.
func _haende_entspannen() -> void:
	var skelett := skelett_finden()
	if skelett == null:
		return
	var beugung := {"Thumb": 0.08, "Index": 0.22, "Middle": 0.26, "Ring": 0.28, "Pinky": 0.32}
	# Die T-Pose spreizt die Finger wie zum Abklatschen; in Ruhe liegen sie
	# fast aneinander. Zusammengeführt wird am Grundglied um die lokale
	# Z-Achse (die Spreizachse des Rigs), zur Mittelhand hin.
	var spreizung := {"Thumb": -0.18, "Index": 0.10, "Middle": 0.03, "Ring": -0.06, "Pinky": -0.16}
	for seite in ["Left", "Right"]:
		for finger in beugung:
			for glied in range(1, 4):
				var idx := skelett.find_bone("%sHand%s%d" % [seite, finger, glied])
				if idx < 0:
					continue
				var pose := skelett.get_bone_pose_rotation(idx) 					* Quaternion(Vector3.RIGHT, beugung[finger])
				if glied == 1:
					pose *= Quaternion(Vector3(0, 0, 1), spreizung[finger])
				skelett.set_bone_pose_rotation(idx, pose)


## Skaliert das Modell so, dass es `zielhoehe` misst.
func _auf_hoehe_bringen() -> void:
	if zielhoehe <= 0.0:
		return
	var hoehe := gemessene_hoehe()
	if hoehe < 0.01:
		push_warning("Figur: Modell '%s' hat keine messbare Höhe." % modell_pfad)
		return
	modell.scale *= zielhoehe / hoehe


## Nimmt die Arme aus der T-Pose herunter.
##
## Gedreht wird im **Skelettraum** und nicht in der Knochenachse: wie ein
## Oberarmknochen orientiert ist, hängt vom Werkzeug ab, das ihn gebaut hat.
## Die Richtung „nach unten" ist dagegen überall dieselbe. Die Unterarme und
## Hände folgen von selbst, weil sie am Oberarm hängen.
func _arme_senken() -> void:
	if is_zero_approx(arme_senken_grad):
		return
	var skelett := skelett_finden()
	if skelett == null:
		return

	# Die beiden Arme zeigen nach entgegengesetzten Seiten und müssen deshalb
	# um die Z-Achse in entgegengesetztem Sinn schwenken, damit beide sinken.
	var seiten := {"Left": -1.0, "Right": 1.0}

	# Zuerst sinken die Schultern selbst ein Stück — die T-Pose hält sie
	# hochgezogen wie beim Schulterzucken, und weil die Arme an ihnen hängen,
	# rücken sie damit zugleich näher an den Rumpf.
	for seite in seiten:
		var schulter := skelett.find_bone("%sShoulder" % seite)
		if schulter < 0:
			continue
		var lage := skelett.get_bone_global_pose(schulter)
		var drehung := Basis(Vector3.BACK, deg_to_rad(schultern_senken_grad) * seiten[seite])
		skelett.set_bone_global_pose(schulter, Transform3D(drehung * lage.basis, lage.origin))

	# Dann die Arme: fast senkrecht nach unten und leicht nach vorn — die
	# Schultergelenke sitzen hinter der Körpermitte, ohne die Vorlage hingen
	# die Hände hinter dem Gesäß statt neben dem Oberschenkel.
	for seite in seiten:
		var knochen := skelett.find_bone("%sArm" % seite)
		if knochen < 0:
			push_warning("Figur: Knochen '%sArm' fehlt — Arme bleiben waagerecht." % seite)
			continue
		var lage := skelett.get_bone_global_pose(knochen)
		var drehung := (
			Basis(Vector3.UP, deg_to_rad(arme_eindrehen_grad) * seiten[seite])
			* Basis(Vector3.RIGHT, -deg_to_rad(arme_vor_grad))
			* Basis(Vector3.BACK, deg_to_rad(arme_senken_grad) * seiten[seite])
		)
		skelett.set_bone_global_pose(knochen, Transform3D(drehung * lage.basis, lage.origin))

	# Zuletzt die Handgelenke: eine Hand in Ruhe fällt leicht nach innen ab,
	# ganz gestreckt wirkt sie wie ein Brett. Lokal gedreht wie die Finger.
	for seite in seiten:
		var hand := skelett.find_bone("%sHand" % seite)
		if hand < 0:
			continue
		skelett.set_bone_pose_rotation(hand,
			skelett.get_bone_pose_rotation(hand)
			* Quaternion(Vector3.RIGHT, deg_to_rad(handgelenk_grad)))


## Das erste Skelett im Modell, oder null. Hier docken später die Animationen an.
func skelett_finden() -> Skeleton3D:
	return _skelett_suchen(modell) if modell != null else null


func _skelett_suchen(knoten: Node) -> Skeleton3D:
	var skelett := knoten as Skeleton3D
	if skelett != null:
		return skelett
	for kind in knoten.get_children():
		var gefunden := _skelett_suchen(kind)
		if gefunden != null:
			return gefunden
	return null


## Höhe des geladenen Modells in Metern, aus den Ausmaßen aller sichtbaren
## Teile. 0, wenn nichts Sichtbares da ist.
func gemessene_hoehe() -> float:
	if modell == null:
		return 0.0
	var kasten := _ausmasse(modell)
	return kasten.size.y if kasten.has_volume() else 0.0


## Sammelt die Ausmaße aller sichtbaren Teile, im Raum der Figur.
func _ausmasse(knoten: Node) -> AABB:
	var gesamt := AABB()
	var erster := true

	for kind in knoten.get_children():
		var teil := _ausmasse(kind)
		if not teil.has_volume():
			continue
		gesamt = teil if erster else gesamt.merge(teil)
		erster = false

	var sichtbar := knoten as VisualInstance3D
	if sichtbar != null:
		# `get_aabb()` liefert lokale Maße — erst im Raum der Figur sind sie
		# vergleichbar, sonst zählt eine gedrehte Hand als Körpergröße.
		var eigen := (global_transform.affine_inverse() * sichtbar.global_transform) \
			* sichtbar.get_aabb()
		gesamt = eigen if erster else gesamt.merge(eigen)

	return gesamt
