class_name FrankfurtChapter
extends Node3D

## Kapitel 2 — Frankfurt. Ablaufsteuerung, bewusst als **Sequenzkette**:
##
## Abschiedsrede → Blende → LKW-Fahrt auf der A5 → Blende → Ankunft in
## Frankfurt → spielbarer Lauf zur Apfelweinkneipe → hinein → Krug-Werfen
## → Sieg-Dialog → „Du hast es ins dritte Level geschafft." → Abspann.
##
## Nur der Lauf zur Kneipe ist frei spielbar; alles andere sind kurze,
## geschnittene Szenen mit der Filmkamera. Die Texte stehen in
## `dialogue_lines_ffm.gd`.

signal kapitel_abgeschlossen

## Fahrtempo des LKW in den Autobahn-Einstellungen (m/s).
@export_range(10.0, 35.0, 0.5) var fahrt_tempo: float = 21.0
## Für Prüfläufe: rafft alle Warte- und Fahrzeiten.
@export var test_schnell: bool = false

const _ABSCHIED_ANNE := Vector3(-0.5, 0.3, -4.0)
const _ABSCHIED_OLIVER := Vector3(1.2, 0.25, -4.3)
const _ANKUNFT_ANNE := Vector3(202.0, 0.3, 0.5)
const _ANKUNFT_OLIVER := Vector3(205.0, 0.25, -0.8)
## Beim Werfen stehen die beiden neben der Wurfbahn (die läuft bei
## x 399,2–400,8), im Schlussbild dann einander zugewandt in der Mitte.
const _KNEIPE_ANNE := Vector3(398.5, 0.3, -97.9)
const _KNEIPE_OLIVER := Vector3(401.9, 0.25, -98.2)
const _SCHLUSS_ANNE := Vector3(399.2, 0.3, -98.4)
const _SCHLUSS_OLIVER := Vector3(401.6, 0.25, -98.4)

## Die optionalen Fundstücke in der Gasse — Knotenname unter `Erinnerungen`
## und die Zeilen dazu. Sie halten den Lauf nicht an, sie warten aufs
## Ansprechen. Ein weiteres ergänzt man mit einer Instanz von
## `memory_point.tscn` und einer Zeile hier.
const _ERINNERUNGEN := [
	{"node": "ErinnerungFahrrad", "lines": FrankfurtDialogue.ERINNERUNG_FAHRRAD},
	{"node": "ErinnerungBembel", "lines": FrankfurtDialogue.ERINNERUNG_BEMBEL},
	{"node": "ErinnerungTische", "lines": FrankfurtDialogue.ERINNERUNG_TISCHE},
]

@onready var _player: Player = $Player
@onready var _oliver: Companion = $Oliver
@onready var _kamera_rig: Node3D = $ThirdPersonCamera
@onready var _filmkamera: Camera3D = $Filmkamera
@onready var _dialogue: DialogueBox = $UI/DialogueBox
@onready var _objective = $UI/ObjectiveLabel
@onready var _karte = $UI/ChapterCard
@onready var _krug: KrugSpiel = $KrugSpiel
@onready var _kulisse: Node3D = $Kulisse
@onready var _motor: AudioStreamPlayer = $Klang/Motor
@onready var _kneipenluft: AudioStreamPlayer = $Klang/Kneipenluft
@onready var _stadtluft: AudioStreamPlayer = $Klang/Stadtluft

var _tuer_erreicht := false
var _fahrt_laeuft := false
var _mitfahrt := false
var _blendschicht: CanvasLayer
var _blende: ColorRect
var _titelfeld: Label


func _ready() -> void:
	_player.input_enabled = false
	_blendschicht_bauen()
	var tuer := $Triggers/KneipenTuer as Area3D
	tuer.body_entered.connect(func(koerper: Node3D) -> void:
		if koerper == _player:
			_tuer_erreicht = true)

	for fundstueck in _ERINNERUNGEN:
		var punkt := get_node_or_null(
			"Erinnerungen/%s" % fundstueck["node"]) as Interactable
		if punkt == null:
			push_warning("Kapitel Frankfurt: Erinnerung '%s' fehlt."
				% fundstueck["node"])
			continue
		punkt.interacted.connect(_auf_erinnerung.bind(fundstueck["lines"], punkt))

	_ablauf.call_deferred()


func _process(delta: float) -> void:
	# Während der Autobahn-Sequenz rollt der LKW auch, wenn gerade ein
	# Dialog wartet — die Fahrt gehört der _process-Schleife.
	if _fahrt_laeuft and _kulisse.lkw_fahrt != null:
		_kulisse.lkw_fahrt.position.x += fahrt_tempo * delta


func _wartezeit(sekunden: float) -> float:
	return 0.05 if test_schnell else sekunden


# --- Der rote Faden -----------------------------------------------------------


func _ablauf() -> void:
	# 1. Abschied vor der Berliner Wohnung.
	_player.global_position = _ABSCHIED_ANNE
	_player.rotation.y = -PI / 2.0
	_oliver.hold()
	_oliver.global_position = _ABSCHIED_OLIVER
	_oliver.rotation.y = PI / 2.0
	_film(Vector3(-3.2, 1.75, -0.4), Vector3(0.5, 1.25, -4.2))
	await _karte.auftakt(FrankfurtDialogue.KARTE_TITEL, FrankfurtDialogue.KARTE_ZEILE)
	await _dialogue.play(FrankfurtDialogue.ABSCHIED)
	await get_tree().create_timer(_wartezeit(0.8)).timeout

	# 2. Blende → Autobahn.
	await _zwischentitel(FrankfurtDialogue.TITEL_AUTOBAHN)
	await _autobahn_sequenz()

	# 3. Blende → Ankunft in Frankfurt.
	await _zwischentitel(FrankfurtDialogue.TITEL_ANKUNFT)
	await _ankunft_sequenz()

	# 4. Spielbarer Lauf zur Kneipe.
	_objective.show_objective(FrankfurtDialogue.ZIEL_KNEIPE)
	while not _tuer_erreicht:
		await get_tree().process_frame
	_player.input_enabled = false
	_oliver.hold()
	_objective.clear()
	await _dialogue.play(FrankfurtDialogue.KNEIPE_TUER)

	# 5. Hinein in die Stube, das Spiel übernimmt.
	await _abblenden(0.7)
	_player.global_position = _KNEIPE_ANNE
	_player.rotation.y = 0.0
	_oliver.global_position = _KNEIPE_OLIVER
	_stadtluft.stop()
	_kneipenluft.play()
	_krug.starten()
	await _aufblenden(0.9)
	await _krug.runde_geschafft
	Spielstand.freischalten(2)
	await get_tree().create_timer(_wartezeit(2.4)).timeout
	_krug.abschluss_uebernehmen()

	# 6. Sieg-Sequenz: die beiden in der Stube, dann der Level-Übergang.
	_player.global_position = _SCHLUSS_ANNE
	_oliver.global_position = _SCHLUSS_OLIVER
	_player.rotation.y = -PI / 2.0
	_oliver.rotation.y = PI / 2.0
	# Nicht weiter zurück: die Innenkante der Vorderwand liegt bei z = -95,35.
	_film(Vector3(400.4, 1.75, -95.6), Vector3(400.4, 1.25, -98.4))
	await _dialogue.play(FrankfurtDialogue.GEWONNEN)
	await _level_uebergang()
	await _karte.abspann(FrankfurtDialogue.KARTE_TITEL, FrankfurtDialogue.KARTE_ZEILE)
	kapitel_abgeschlossen.emit()
	if not test_schnell:
		get_tree().change_scene_to_file(
			"res://chapters/hochzeit/hochzeit_chapter.tscn")


# --- Erinnerungen am Weg -------------------------------------------------------


## Ein Fundstück wurde angesprochen. Bewusst viel leichter als eine
## Sequenz: niemand wird umgestellt, die Kamera bleibt stehen, nur die
## Steuerung ruht für die zwei Sätze.
func _auf_erinnerung(_wer: Node3D, zeilen: Array, _punkt: Node3D) -> void:
	if not _player.input_enabled or _dialogue.is_playing():
		return
	_player.input_enabled = false
	await _dialogue.play(zeilen)
	# Nach dem Sieg gehört die Steuerung dem Spiel — dann nicht zurückgeben.
	if _krug.zustand == KrugSpiel.Zustand.INAKTIV and not _tuer_erreicht:
		_player.input_enabled = true


# --- Sequenzen -----------------------------------------------------------------


func _film(ort: Vector3, blick: Vector3) -> void:
	_filmkamera.global_position = ort
	_filmkamera.look_at(blick)
	_filmkamera.current = true


func _autobahn_sequenz() -> void:
	var lkw: Node3D = _kulisse.lkw_fahrt
	lkw.position.x = -240.0
	_fahrt_laeuft = true
	# Die Kulisse dreht die Räder und lässt die Federung arbeiten, solange
	# hier ein Tempo steht.
	_kulisse.lkw_tempo = fahrt_tempo
	_motor.play()

	# Einstellung 1: die Kamera fährt seitlich mit.
	var uhr := 0.0
	var dauer := _wartezeit(4.0)
	while uhr < dauer:
		uhr += get_process_delta_time()
		_filmkamera.global_position = lkw.global_position + Vector3(-5.0, 2.6, 8.5)
		_filmkamera.look_at(lkw.global_position + Vector3(2.0, 1.4, 0.0))
		_filmkamera.current = true
		await get_tree().process_frame

	# Einstellung 2: aus der Kabine. Das Telefonat läuft von hier — man
	# sieht, was er sieht, während er mit ihr spricht.
	_mitfahrt = true
	_kabine_begleiten()
	await _dialogue.play(FrankfurtDialogue.ANRUF)
	_mitfahrt = false

	# Dann übernimmt man selbst das Steuer: Spurwechsel, Schleicher
	# überholen, Gegenverkehr drüben. Das Spiel bewegt den LKW ab hier
	# selbst — die Sequenzfahrt muss dafür loslassen.
	_fahrt_laeuft = false
	var fahrspiel := LkwSpiel.new()
	add_child(fahrspiel)
	if test_schnell:
		fahrspiel.ziel_strecke = 4.0
		fahrspiel.ziel_ueberholer = 0
	fahrspiel.starten(lkw, _filmkamera, _kulisse, _motor)
	await fahrspiel.fertig
	await get_tree().create_timer(_wartezeit(1.6)).timeout
	fahrspiel.abschluss_uebernehmen()
	_fahrt_laeuft = true

	# Einstellung 3: fest an der Brücke, der LKW zieht darunter durch.
	# Nach dem Weltumbruch des Spiels steht der LKW irgendwo — für die
	# Brückeneinstellung wird er kurz davor zurückgesetzt.
	lkw.position.x = 40.0
	lkw.position.z = 300.0
	lkw.rotation.y = PI / 2.0
	_film(Vector3(96.0, 2.2, 308.0), Vector3(70.0, 3.4, 300.0))
	uhr = 0.0
	dauer = _wartezeit(4.5)
	while uhr < dauer:
		uhr += get_process_delta_time()
		await get_tree().process_frame
	_fahrt_laeuft = false
	_kulisse.lkw_tempo = 0.0
	var leiser := create_tween()
	leiser.tween_property(_motor, ^"volume_db", -40.0, 1.0)
	leiser.tween_callback(_motor.stop)


## Die Kamera sitzt in der Kabine, hinter dem Lenkrad — nebenläufig zum
## wartenden Telefonat-Dialog.
##
## Das Fahrgefühl kommt hier fast ausschließlich aus dem **Wackeln**: drei
## überlagerte Sinusschwingungen (Fahrbahn, Federung, Motor) auf Position
## und Neigung. Der Blick geht bewusst leicht nach rechts vorn, damit
## Leitplanken und Leitpfosten durchs Bild ziehen — eine Kamera, die
## genau nach vorn schaut, sieht auf einer geraden Autobahn wie ein
## Standbild aus.
func _kabine_begleiten() -> void:
	var lkw: Node3D = _kulisse.lkw_fahrt
	var uhr := 0.0
	while _mitfahrt:
		uhr += get_process_delta_time()
		var ruckeln := Vector3(
			sin(uhr * 13.0) * 0.006,
			sin(uhr * 9.3) * 0.010 + sin(uhr * 24.0) * 0.003,
			sin(uhr * 7.1) * 0.005)
		# Der Sitzplatz **in Modellkoordinaten**: links, hinter dem Lenkrad.
		# Der LKW ist im Weltraum gedreht — wer hier Weltachsen addiert,
		# landet im Koffer und filmt eine weiße Wand (genau so passiert).
		_filmkamera.global_position = lkw.to_global(
			Vector3(-0.52, 2.16, 3.05) + ruckeln)
		_filmkamera.look_at(lkw.to_global(Vector3(
			-0.15, 0.60 + sin(uhr * 5.0) * 0.08, 45.0)))
		_filmkamera.rotation.z = sin(uhr * 3.7) * 0.006
		_filmkamera.current = true
		await get_tree().process_frame


func _ankunft_sequenz() -> void:
	_player.global_position = _ANKUNFT_ANNE
	_player.rotation.y = -PI / 2.0
	_oliver.global_position = _ANKUNFT_OLIVER
	_oliver.rotation.y = PI / 2.0
	_film(Vector3(200.0, 1.7, -3.2), Vector3(203.5, 1.35, 0.0))
	await _dialogue.play(FrankfurtDialogue.ANKUNFT)
	# Übergabe an die Spielerin: Verfolgerkamera an, Oliver folgt.
	(_kamera_rig.get_node("SpringArm3D/Camera3D") as Camera3D).current = true
	_player.input_enabled = true
	_oliver.activate()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Blenden und Übergänge -----------------------------------------------------


func _blendschicht_bauen() -> void:
	_blendschicht = CanvasLayer.new()
	_blendschicht.layer = 14
	add_child(_blendschicht)
	_blende = ColorRect.new()
	_blende.color = Color(0, 0, 0, 0)
	_blende.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blende.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blendschicht.add_child(_blende)
	_titelfeld = Label.new()
	_titelfeld.add_theme_font_size_override("font_size", 40)
	_titelfeld.add_theme_color_override("font_color", Color(0.93, 0.90, 0.82))
	_titelfeld.set_anchors_preset(Control.PRESET_FULL_RECT)
	_titelfeld.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titelfeld.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_titelfeld.modulate.a = 0.0
	_blendschicht.add_child(_titelfeld)


func _abblenden(dauer: float) -> void:
	var lauf := create_tween()
	lauf.tween_property(_blende, ^"color:a", 1.0, _wartezeit(dauer))
	await lauf.finished


func _aufblenden(dauer: float) -> void:
	var lauf := create_tween()
	lauf.tween_property(_blende, ^"color:a", 0.0, _wartezeit(dauer))
	await lauf.finished


## Schwarzblende mit Zwischentitel — der Schnitt zwischen den Sequenzen.
func _zwischentitel(text: String) -> void:
	await _abblenden(0.7)
	_titelfeld.text = text
	var auftritt := create_tween()
	auftritt.tween_property(_titelfeld, ^"modulate:a", 1.0, _wartezeit(0.6))
	auftritt.tween_interval(_wartezeit(1.5))
	auftritt.tween_property(_titelfeld, ^"modulate:a", 0.0, _wartezeit(0.6))
	await auftritt.finished
	await _aufblenden(0.8)


## Der Level-Übergang nach dem Sieg — wie in Kapitel 1, mit den Texten
## aus dialogue_lines_ffm.gd.
func _level_uebergang() -> void:
	await _abblenden(0.9)
	var mitte := VBoxContainer.new()
	mitte.set_anchors_preset(Control.PRESET_FULL_RECT)
	mitte.alignment = BoxContainer.ALIGNMENT_CENTER
	mitte.add_theme_constant_override("separation", 30)
	mitte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mitte.modulate.a = 0.0
	_blendschicht.add_child(mitte)
	for daten in [
		[FrankfurtDialogue.LEVEL_TITEL, 56, Color(0.96, 0.92, 0.84)],
		[FrankfurtDialogue.LEVEL_ZEILE, 28, Color(0.78, 0.76, 0.72)],
	]:
		var feld := Label.new()
		feld.text = daten[0]
		feld.add_theme_font_size_override("font_size", daten[1])
		feld.add_theme_color_override("font_color", daten[2])
		feld.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mitte.add_child(feld)
	var auftritt := create_tween()
	auftritt.tween_property(mitte, ^"modulate:a", 1.0, _wartezeit(1.2))
	await auftritt.finished
	var uhr := 0.0
	while uhr < _wartezeit(8.0) and not Input.is_anything_pressed():
		uhr += get_process_delta_time()
		await get_tree().process_frame
	var abgang := create_tween()
	abgang.tween_property(mitte, ^"modulate:a", 0.0, _wartezeit(0.6))
	await abgang.finished
	mitte.queue_free()
	await _aufblenden(1.2)
