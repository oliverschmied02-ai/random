extends Node3D

## Kapitel 1 — Berlin. Ablaufsteuerung für Abholen und Spaziergang.
##
## Die Sequenzen stehen bewusst als gerade heruntergeschriebene Abfolgen da:
## wer sie liest, sieht die Szene vor sich. Ein Zustandsautomat oder ein
## visuelles Skriptsystem wäre für so wenige Schritte mehr Gerüst als Inhalt.
##
## Der Ablauf:
##   1. Oliver am Alexanderplatz treffen (Ansprechen mit E)
##   2. unterwegs das True-Crime-Gespräch — löst beim Vorbeigehen aus
##   3. Ankunft an der Dönerbude, danach das Spritzen-Minispiel
##   4. das Minispiel gewonnen → Abschlussszene und Abspann
##
## Die drei Stationen unterwegs sind Area3D-Knoten unter `Triggers`. Eine
## Station hinzuzufügen heißt: Area3D in die Szene, Zeile in `_STATIONEN`.
##
## Daneben liegen unter `Erinnerungen` optionale Fundstücke: Dinge, die niemand
## sehen muss. Sie halten den Weg nicht an, sondern warten darauf, angesprochen
## zu werden — deshalb Interactable statt Trigger.

signal kapitel_abgeschlossen

## Stationen unterwegs: Trigger-Knoten, Dialog, danach angezeigtes Ziel.
const _STATIONEN := [
	{
		"node": "TriggerCafe",
		"lines": BerlinDialogue.UNTERWEGS_CAFE,
		"ziel": "Weiter durch die Stadt",
	},
	{
		"node": "TriggerDoener",
		"lines": BerlinDialogue.ANKUNFT_DOENER,
		"ziel": "",
	},
]

## Optionale Fundstücke am Weg: Knoten unter `Erinnerungen`, dazu der Text.
const _ERINNERUNGEN := [
	{"node": "ErinnerungSchild", "lines": BerlinDialogue.ERINNERUNG_SCHILD},
	{"node": "ErinnerungBank", "lines": BerlinDialogue.ERINNERUNG_BANK},
	{"node": "ErinnerungFahrrad", "lines": BerlinDialogue.ERINNERUNG_FAHRRAD},
]

## Wie weit die Kamera fürs Gespräch zur Seite schwenkt. Genau hinter der
## Spielerin verdeckt sie Oliver komplett; seitlich stehen beide im Bild.
@export_range(0.0, 90.0, 5.0) var gespraechswinkel_grad: float = 48.0
## Wie lange höchstens darauf gewartet wird, dass Oliver sich neben die
## Spielerin stellt, bevor der Dialog trotzdem beginnt.
@export_range(0.0, 6.0, 0.5) var aufstell_wartezeit: float = 2.5

@export_group("Abschluss")
## Sekunden zwischen dem letzten Treffer und dem Beginn der Abschlussszene.
## Konfetti und Banner brauchen einen Moment, bevor etwas Neues anfängt.
@export_range(0.0, 6.0, 0.1) var abschluss_vorlauf: float = 2.2
## Dauer der Umstellung: beide drehen sich zueinander, die Kamera fährt hin.
@export_range(0.5, 6.0, 0.1) var abschluss_fahrt: float = 2.0
## Wie weit über dem Boden die Abschlusskamera zielt. Etwa Hüfthöhe, nicht
## Kopfhöhe: das Bild zielt in die Mitte der beiden Gestalten, sonst stehen sie
## in der unteren Hälfte und die Dialogbox schneidet ihnen die Füße ab.
@export_range(0.5, 2.5, 0.05) var abschluss_blickhoehe: float = 0.8
## Bildwinkel des Schlussbilds. Die Minispielkamera steht auf 27° — ein
## Teleobjektiv, das aus fünf Metern die Scheibe füllt. Aus zwei Metern passen
## damit keine zwei Menschen ins Bild; der Abschluss braucht einen weiteren Blick.
@export_range(25.0, 90.0, 1.0) var abschluss_bildwinkel: float = 50.0

@onready var _player: Player = $Player
@onready var _camera: ThirdPersonCamera = $ThirdPersonCamera
@onready var _oliver: Companion = $Oliver
@onready var _dialogue: DialogueBox = $UI/DialogueBox
@onready var _darts: DartsGame = $DartsGame
@onready var _objective = $UI/ObjectiveLabel
@onready var _karte = $UI/ChapterCard
@onready var _figur_anne: Figur = $Player/Visual
@onready var _figur_oliver: Figur = $Oliver/Visual
@onready var _platz_anne: Marker3D = $Abschluss/Anne
@onready var _platz_oliver: Marker3D = $Abschluss/Oliver
@onready var _abschluss_kamera: Marker3D = $Abschluss/Kamera

var _szene_laeuft: bool = false


func _ready() -> void:
	var tuer := _oliver.get_node("Interactable") as Interactable
	tuer.interacted.connect(_on_oliver_abgeholt)

	for station in _STATIONEN:
		var area := get_node_or_null("Triggers/%s" % station["node"]) as Area3D
		if area == null:
			push_warning("Kapitel Berlin: Trigger '%s' fehlt." % station["node"])
			continue
		area.body_entered.connect(_on_station_betreten.bind(station, area))

	for fundstueck in _ERINNERUNGEN:
		var punkt := get_node_or_null("Erinnerungen/%s" % fundstueck["node"]) as Interactable
		if punkt == null:
			push_warning("Kapitel Berlin: Erinnerung '%s' fehlt." % fundstueck["node"])
			continue
		punkt.interacted.connect(_on_erinnerung.bind(fundstueck["lines"], punkt))

	# Wer spricht, nickt dazu — die Dialogbox meldet jede neue Zeile.
	_dialogue.zeile_begonnen.connect(_auf_sprechzeile)

	_jacke_anziehen()
	_auftakt()


## Zieht Oliver für dieses Kapitel die Wachsjacke an: dieselbe outfit-
## Fläche, aber die umgemalte Textur (tools/make_barbour.py — Sakko-Pixel
## per Körperhöhen-Maske in Wachs-Oliv, Cordkragen). Nur ein Material-
## Override auf dieser Instanz; die anderen Kapitel behalten das Sakko.
func _jacke_anziehen() -> void:
	var jacke := load("res://assets/kleidung/oliver_barbour.png") as Texture2D
	if jacke == null or _figur_oliver.modell == null:
		return
	for kind in _figur_oliver.modell.find_children("*", "MeshInstance3D", true, false):
		var teil := kind as MeshInstance3D
		if teil == null or teil.mesh == null:
			continue
		for s in teil.mesh.get_surface_count():
			var material := teil.get_active_material(s) as BaseMaterial3D
			if material == null or material.resource_name != "outfit":
				continue
			var kopie := material.duplicate() as BaseMaterial3D
			kopie.albedo_texture = jacke
			kopie.roughness = 0.72  # Wachs glänzt stumpf, nicht wie Wolle
			teil.set_surface_override_material(s, kopie)


func _auf_sprechzeile(sprecher: String) -> void:
	match sprecher:
		"ANNE":
			_figur_anne.betone()
		"OLIVER":
			_figur_oliver.betone()


## Der Kapitelanfang: Titeltafel, dann geht das Bild auf. Die Steuerung ruht so
## lange — wer schon läuft, während der Titel noch steht, hat den Anfang verpasst.
func _auftakt() -> void:
	_player.input_enabled = false
	await _karte.auftakt("KAPITEL 1",
		"DAS ERSTE TREFFEN AM ALEXANDERPLATZ — 2020")
	_player.input_enabled = true
	_objective.show_objective("Triff Oliver am Alexanderplatz")


## Erste Station: das Abholen vor der Bürotür.
func _on_oliver_abgeholt(_interactor: Node3D) -> void:
	await _spiele_szene(BerlinDialogue.ABHOLEN)
	_oliver.activate()
	_objective.show_objective("Gemeinsam durch die Stadt")


## Die Stationen unterwegs lösen beim Betreten aus, nicht auf Tastendruck —
## sie sind Teil der Geschichte, keine optionalen Fundstücke.
func _on_station_betreten(body: Node3D, station: Dictionary, area: Area3D) -> void:
	if body != _player or _szene_laeuft:
		return
	area.set_deferred(&"monitoring", false)  # jede Station genau einmal

	await _spiele_szene(station["lines"])

	if station["node"] == "TriggerDoener":
		await _minispiel_starten()
		return

	_oliver.activate()
	_objective.show_objective(station["ziel"])


## Ein Fundstück am Weg. Bewusst viel leichter als eine Station: niemand wird
## umgestellt, die Kamera bleibt, wo sie ist. Nur die Steuerung ruht kurz, damit
## die Spielerin nicht mitten im Satz weiterläuft.
func _on_erinnerung(_interactor: Node3D, lines: Array, punkt: Node3D) -> void:
	if _szene_laeuft:
		return
	_szene_laeuft = true
	_player.input_enabled = false
	_figur_anne.schaue_an(punkt, 0.0)

	await _dialogue.play(lines)

	_figur_anne.schaue_an(null)
	_player.input_enabled = true
	_szene_laeuft = false


## Übergang in das Minispiel: beide gehen an die Scheibe, die Kamera fährt
## hinüber, danach hat das Minispiel die Kontrolle.
func _minispiel_starten() -> void:
	# Die Gesprächsszene gibt die Steuerung am Ende zurück — fürs Minispiel
	# muss sie gleich wieder weg, sonst läuft die Figur beim Zielen davon.
	_player.input_enabled = false
	_figur_anne.schaue_an(null)
	_objective.clear()
	await _figuren_an_die_scheibe()
	_darts.runde_geschafft.connect(_auf_runde_geschafft, CONNECT_ONE_SHOT)
	_darts.starten(_camera.camera)


## Schiebt Spielerin und Oliver auf ihre Plätze. Die Physik wird dafür kurz
## abgeschaltet: sonst arbeiten Schwerkraft und `move_and_slide()` gegen die
## Bewegung, und beide zittern auf dem Weg.
func _figuren_an_die_scheibe() -> void:
	_oliver.hold()
	_player.set_physics_process(false)
	_oliver.set_physics_process(false)

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_gehe_zu(tween, _player, _darts.spieler_platz.global_position)
	_gehe_zu(tween, _oliver, _darts.oliver_platz.global_position)
	await tween.finished


## Bewegt eine Figur zu `ziel` und dreht sie dabei zur Scheibe.
func _gehe_zu(tween: Tween, figur: Node3D, ziel: Vector3) -> void:
	tween.tween_property(figur, ^"global_position", ziel, 1.5)
	var zur_scheibe := _darts.ziel_punkt() - ziel
	zur_scheibe.y = 0.0
	if zur_scheibe.length() > 0.01:
		zur_scheibe = zur_scheibe.normalized()
		tween.tween_property(
			figur, ^"rotation:y", atan2(-zur_scheibe.x, -zur_scheibe.z), 1.5
		)


## Nach dem Abspann geht es weiter ins nächste Kapitel — Prüfläufe
## schalten das ab, damit die Szene für ihre Messungen stehen bleibt.
@export var weiter_nach_gewinn: bool = true


func _auf_runde_geschafft(_punkte: int) -> void:
	Spielstand.freischalten(1)
	await _level_uebergang()
	await _abschluss_szene()
	kapitel_abgeschlossen.emit()
	if weiter_nach_gewinn:
		get_tree().change_scene_to_file(
			"res://chapters/frankfurt/frankfurt_chapter.tscn")


## Der Übergangsbildschirm nach dem Sieg: Schwarzblende, „Glückwunsch."
## und die Zeile zum zweiten Level (Texte in dialogue_lines.gd). Klick,
## Taste oder acht Sekunden führen weiter; die Schwarzblende löst sich
## dann über der anlaufenden Schlussszene.
func _level_uebergang() -> void:
	# Das GESCHAFFT-Banner des Minispiels erst kurz wirken lassen.
	await get_tree().create_timer(2.2).timeout

	var schicht := CanvasLayer.new()
	schicht.layer = 15
	add_child(schicht)
	var schwarz := ColorRect.new()
	schwarz.color = Color(0, 0, 0, 0)
	schwarz.set_anchors_preset(Control.PRESET_FULL_RECT)
	schwarz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	schicht.add_child(schwarz)

	var mitte := VBoxContainer.new()
	mitte.set_anchors_preset(Control.PRESET_FULL_RECT)
	mitte.alignment = BoxContainer.ALIGNMENT_CENTER
	mitte.add_theme_constant_override("separation", 30)
	mitte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mitte.modulate.a = 0.0
	schicht.add_child(mitte)
	for daten in [
		[BerlinDialogue.LEVEL_TITEL, 56, Color(0.96, 0.92, 0.84)],
		[BerlinDialogue.LEVEL_ZEILE, 28, Color(0.78, 0.76, 0.72)],
	]:
		var feld := Label.new()
		feld.text = daten[0]
		feld.add_theme_font_size_override("font_size", daten[1])
		feld.add_theme_color_override("font_color", daten[2])
		feld.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mitte.add_child(feld)

	var auftritt := create_tween()
	auftritt.tween_property(schwarz, ^"color:a", 1.0, 0.9)
	auftritt.tween_property(mitte, ^"modulate:a", 1.0, 1.2)
	await auftritt.finished

	# Weiter per Eingabe oder nach acht Sekunden — die Prüfläufe drücken nichts.
	var uhr := 0.0
	while uhr < 8.0 and not Input.is_anything_pressed():
		uhr += get_process_delta_time()
		await get_tree().process_frame

	var abgang := create_tween()
	abgang.tween_property(mitte, ^"modulate:a", 0.0, 0.6)
	await abgang.finished

	# Die Schwarzblende bleibt liegen und löst sich über der anlaufenden
	# Schlussszene — nebenläufig, damit die Kamerafahrt darunter beginnt.
	var blende := create_tween()
	blende.tween_interval(1.2)
	blende.tween_property(schwarz, ^"color:a", 0.0, 1.6)
	blende.tween_callback(schicht.queue_free)


## Der Abschluss: das Minispiel tritt ab, beide drehen sich zueinander, die
## Kamera geht auf Augenhöhe daneben, sie reden, dann der Abspann.
##
## Die Reihenfolge ist der ganze Trick. Erst wenn das Minispiel die Kamera
## losgelassen hat, darf die Fahrt beginnen; erst wenn beide stehen, darf
## geredet werden. Alles gleichzeitig sähe aus wie ein Umschnitt mitten im Satz.
func _abschluss_szene() -> void:
	await get_tree().create_timer(abschluss_vorlauf).timeout
	_darts.abschluss_uebernehmen()

	var kamera := _darts.kamera
	var von := kamera.global_transform
	var nach := _abschluss_lage()

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_stelle_gegenueber(tween, _player, _platz_anne.global_position, _platz_oliver.global_position)
	_stelle_gegenueber(tween, _oliver, _platz_oliver.global_position, _platz_anne.global_position)
	tween.tween_method(
		func(anteil: float) -> void:
			kamera.global_transform = von.interpolate_with(nach, anteil),
		0.0, 1.0, abschluss_fahrt
	)
	tween.tween_property(kamera, ^"fov", abschluss_bildwinkel, abschluss_fahrt)
	await tween.finished

	# Tiefenschärfe fürs Schlussbild: die beiden scharf, Berlin dahinter weich.
	# Nur hier — beim Zielen im Minispiel wäre Unschärfe eine Zumutung.
	var blende := CameraAttributesPractical.new()
	blende.dof_blur_far_enabled = true
	blende.dof_blur_far_distance = 7.0
	blende.dof_blur_far_transition = 5.0
	blende.dof_blur_amount = 0.07
	kamera.attributes = blende

	_figur_anne.schaue_an(_oliver)
	await _dialogue.play(BerlinDialogue.ABSCHLUSS)
	# Die Schlusskarte kündigt das nächste Kapitel an — dieselbe Karte
	# noch einmal mit "KAPITEL 1" las sich wie ein Neustart des Kapitels.
	await _karte.abspann("KAPITEL 2",
		"DER UMZUG NACH FRANKFURT")


## Wohin die Abschlusskamera schaut: auf die Mitte zwischen beiden, auf
## Kopfhöhe. Aus den Marker-Positionen gerechnet und nicht aus den Figuren,
## damit die Lage schon feststeht, während die beiden noch unterwegs sind.
func _abschluss_lage() -> Transform3D:
	var mitte := (_platz_anne.global_position + _platz_oliver.global_position) * 0.5
	mitte.y = minf(_platz_anne.global_position.y, _platz_oliver.global_position.y)
	mitte.y += abschluss_blickhoehe
	var lage := Transform3D(Basis.IDENTITY, _abschluss_kamera.global_position)
	return lage.looking_at(mitte, Vector3.UP)


## Schiebt eine Figur auf ihren Platz und dreht sie dabei zur anderen.
func _stelle_gegenueber(tween: Tween, figur: Node3D, platz: Vector3, gegenueber: Vector3) -> void:
	var ziel := Vector3(platz.x, figur.global_position.y, platz.z)
	tween.tween_property(figur, ^"global_position", ziel, abschluss_fahrt)

	var hin := gegenueber - platz
	hin.y = 0.0
	if hin.length() > 0.01:
		hin = hin.normalized()
		tween.tween_property(
			figur, ^"rotation:y", atan2(-hin.x, -hin.z), abschluss_fahrt
		)


## Der gemeinsame Ablauf jeder Gesprächsszene: Steuerung abgeben, Oliver
## danebenstellen, Kamera schwenken, reden lassen, alles zurückgeben.
func _spiele_szene(lines: Array) -> void:
	_szene_laeuft = true
	_player.input_enabled = false

	await _oliver_danebenstellen()
	_camera.aim_at_yaw(_gespraechs_winkel())

	# Für die Dauer des Gesprächs sehen die beiden einander an; Oliver tut das
	# im gehaltenen Zustand von selbst, sobald Anne nah ist.
	_figur_anne.schaue_an(_oliver)
	await _dialogue.play(lines)
	_figur_anne.schaue_an(null)

	_camera.release_aim()
	_player.input_enabled = true
	_szene_laeuft = false


## Holt Oliver an die Seite der Spielerin, wartet aber nicht ewig darauf —
## ein Gespräch, das nicht anfängt, weil jemand hängengeblieben ist, wäre
## schlimmer als ein Gespräch mit unsauberer Bildaufteilung.
func _oliver_danebenstellen() -> void:
	if _oliver.state == Companion.State.IDLE:
		_oliver.hold()  # wartet noch vor der Tür, bleibt einfach stehen
		return

	var rechts := _player.global_transform.basis.x
	rechts = Vector3(rechts.x, 0.0, rechts.z).normalized()
	_oliver.move_to(_player.global_position + rechts * 1.7)

	# Als Dictionary und nicht als einfaches `bool`: GDScript-Lambdas fangen
	# lokale Variablen **als Kopie** ein. Ein `angekommen = true` im Lambda
	# bliebe hier draußen wirkungslos, und die Schleife liefe immer in die
	# volle Wartezeit — das Gespräch begänne jedes Mal 2,5 s zu spät.
	var stand := {"angekommen": false}
	var beim_ankommen := func() -> void: stand["angekommen"] = true
	_oliver.arrived.connect(beim_ankommen, CONNECT_ONE_SHOT)

	var frist := get_tree().create_timer(aufstell_wartezeit)
	while not stand["angekommen"] and frist.time_left > 0.0:
		await get_tree().process_frame

	if _oliver.arrived.is_connected(beim_ankommen):
		_oliver.arrived.disconnect(beim_ankommen)
	_oliver.hold()


## Blickrichtung entlang der Achse zwischen beiden Figuren, seitlich versetzt.
func _gespraechs_winkel() -> float:
	var zu_oliver := _oliver.global_position - _player.global_position
	zu_oliver.y = 0.0
	if zu_oliver.length() < 0.1:
		return _camera.rotation.y
	zu_oliver = zu_oliver.normalized()
	return atan2(-zu_oliver.x, -zu_oliver.z) + deg_to_rad(gespraechswinkel_grad)
