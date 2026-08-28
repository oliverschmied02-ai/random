class_name HochzeitChapter
extends Node3D

## Kapitel 3 — die Hochzeit an der Spree. Das **Finale** des Spiels.
##
## Ablauf:
##
##   Kapitelkarte → kurzer Dialog am Traubogen → spielbarer Weg zu den
##   Gästen → Regeln → Brautstrauß-Fangen (10 fliegen, 5 fangen) →
##   Sieg-Dialog → **Geschenkbildschirm** → Abspann → Titel.
##
## Der Geschenkbildschirm löst ein, was die Widmung am Anfang verspricht.
## Die Texte dazu stehen in `dialogue_lines_hochzeit.gd` und sind bewusst
## als Platzhalter markiert — sie gehören Oliver, nicht dem Code.

signal kapitel_abgeschlossen

## Für Prüfläufe: rafft alle Warte- und Blendzeiten.
@export var test_schnell: bool = false
## Für Prüfläufe: bleibt nach dem Abspann in der Szene.
@export var weiter_nach_abspann: bool = true

const _START_ANNE := Vector3(-6.5, 0.3, 16.0)
const _START_OLIVER := Vector3(-5.0, 0.25, 16.8)
## Wo Anne beim Fangen steht (die Spielkamera schaut über ihre Schulter).
const _SPIEL_ANNE := Vector3(0.0, 0.3, 9.0)
const _SPIEL_OLIVER := Vector3(3.6, 0.25, 2.6)
## Das Schlussbild: die beiden am Wasser, die Brücke hinter ihnen.
const _SCHLUSS_ANNE := Vector3(-0.9, 0.3, 1.5)
const _SCHLUSS_OLIVER := Vector3(0.9, 0.25, 1.5)

@onready var _player: Player = $Player
@onready var _oliver: Companion = $Oliver
@onready var _kamera_rig: Node3D = $ThirdPersonCamera
@onready var _filmkamera: Camera3D = $Filmkamera
@onready var _dialogue: DialogueBox = $UI/DialogueBox
@onready var _objective = $UI/ObjectiveLabel
@onready var _karte = $UI/ChapterCard
@onready var _strauss: StraussSpiel = $StraussSpiel
@onready var _kulisse: Node3D = $Kulisse
@onready var _menge: AudioStreamPlayer = $Klang/Menge
@onready var _jubel: AudioStreamPlayer = $Klang/Jubel

var _bogen_erreicht := false
var _blendschicht: CanvasLayer
var _blende: ColorRect


func _ready() -> void:
	_player.input_enabled = false
	_blendschicht_bauen()
	var zone := $Triggers/BogenZone as Area3D
	zone.body_entered.connect(func(koerper: Node3D) -> void:
		if koerper == _player:
			_bogen_erreicht = true)
	_ablauf.call_deferred()


func _wartezeit(sekunden: float) -> float:
	return 0.05 if test_schnell else sekunden


# --- Der rote Faden -----------------------------------------------------------


func _ablauf() -> void:
	# 1. Nach der Trauung: die beiden abseits, die Gäste am Bogen.
	_player.global_position = _START_ANNE
	_player.rotation.y = 2.5
	_oliver.hold()
	_oliver.global_position = _START_OLIVER
	_oliver.rotation.y = -0.7
	_film(Vector3(-9.6, 1.75, 18.4), Vector3(-5.4, 1.35, 16.2))
	_menge.play()
	await _karte.auftakt(HochzeitDialogue.KARTE_TITEL,
		HochzeitDialogue.KARTE_ZEILE)
	await _dialogue.play(HochzeitDialogue.AUFTAKT)

	# 2. Spielbarer Weg zum Traubogen.
	(_kamera_rig.get_node("SpringArm3D/Camera3D") as Camera3D).current = true
	_player.input_enabled = true
	_oliver.activate()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_objective.show_objective(HochzeitDialogue.ZIEL_BOGEN)
	while not _bogen_erreicht:
		await get_tree().process_frame
	_player.input_enabled = false
	_oliver.hold()
	_objective.clear()

	# 3. Die Regeln, dann das Spiel.
	_player.global_position = _SPIEL_ANNE
	_player.rotation.y = PI
	_oliver.global_position = _SPIEL_OLIVER
	_oliver.rotation.y = 0.35
	_film(Vector3(2.6, 1.7, 6.4), Vector3(0.4, 1.4, 8.6))
	await _dialogue.play(HochzeitDialogue.REGELN)
	_strauss.runde_geschafft.connect(_auf_runde_geschafft, CONNECT_ONE_SHOT)
	_strauss.starten()


func _auf_runde_geschafft() -> void:
	Spielstand.freischalten(3)
	_jubel.play()
	await get_tree().create_timer(_wartezeit(2.6)).timeout
	_strauss.abschluss_uebernehmen()

	# 4. Schlussbild am Wasser: die beiden vor der Brücke.
	_player.global_position = _SCHLUSS_ANNE
	_player.rotation.y = PI * 0.92
	_oliver.global_position = _SCHLUSS_OLIVER
	_oliver.rotation.y = -PI * 0.92
	_film(Vector3(0.0, 1.90, 6.4), Vector3(0.0, 1.62, 1.5))
	await _dialogue.play(HochzeitDialogue.GEWONNEN)

	# 5. Das Geschenk, dann der Abspann.
	await _geschenk_zeigen()
	await _karte.abspann(HochzeitDialogue.ABSPANN_TITEL,
		HochzeitDialogue.ABSPANN_ZEILE)
	kapitel_abgeschlossen.emit()
	if weiter_nach_abspann:
		get_tree().change_scene_to_file("res://ui/title_screen.tscn")


# --- Blenden und Bildschirme ---------------------------------------------------


func _blendschicht_bauen() -> void:
	_blendschicht = CanvasLayer.new()
	_blendschicht.layer = 14
	add_child(_blendschicht)
	_blende = ColorRect.new()
	_blende.color = Color(0, 0, 0, 0)
	_blende.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blende.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blendschicht.add_child(_blende)


func _film(ort: Vector3, blick: Vector3) -> void:
	_filmkamera.global_position = ort
	_filmkamera.look_at(blick)
	_filmkamera.current = true


func _abblenden(dauer: float) -> void:
	var lauf := create_tween()
	lauf.tween_property(_blende, ^"color:a", 1.0, _wartezeit(dauer))
	await lauf.finished


## Der Geschenkbildschirm — das Ende des Versprechens aus der Widmung.
##
## Bewusst ruhig gebaut: schwarz, drei Zeilen, kein Klang außer der
## Menge, die weit weg weiterfeiert. Er wartet auf einen Tastendruck und
## läuft nicht von selbst weiter — hier soll man lesen können.
func _geschenk_zeigen() -> void:
	await _abblenden(1.4)
	var mitte := VBoxContainer.new()
	mitte.set_anchors_preset(Control.PRESET_FULL_RECT)
	mitte.alignment = BoxContainer.ALIGNMENT_CENTER
	mitte.add_theme_constant_override("separation", 26)
	mitte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mitte.modulate.a = 0.0
	_blendschicht.add_child(mitte)

	var titel := Label.new()
	titel.text = HochzeitDialogue.GESCHENK_TITEL
	titel.add_theme_font_size_override("font_size", 58)
	titel.add_theme_color_override("font_color", Color(0.97, 0.93, 0.85))
	titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mitte.add_child(titel)
	for zeile in HochzeitDialogue.GESCHENK_ZEILEN:
		var feld := Label.new()
		feld.text = zeile
		feld.add_theme_font_size_override("font_size", 28)
		feld.add_theme_color_override("font_color", Color(0.80, 0.78, 0.74))
		feld.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		feld.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		feld.custom_minimum_size = Vector2(760, 0)
		mitte.add_child(feld)
	var fuss := Label.new()
	fuss.text = HochzeitDialogue.GESCHENK_FUSS
	fuss.add_theme_font_size_override("font_size", 22)
	fuss.add_theme_color_override("font_color", Color(0.64, 0.62, 0.58))
	fuss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mitte.add_child(fuss)

	var auftritt := create_tween()
	auftritt.tween_property(mitte, ^"modulate:a", 1.0, _wartezeit(1.6))
	await auftritt.finished
	# Warten, bis gelesen wurde — mit großzügiger Frist, falls niemand
	# drückt.
	var uhr := 0.0
	while uhr < _wartezeit(22.0) and not Input.is_anything_pressed():
		uhr += get_process_delta_time()
		await get_tree().process_frame
	var abgang := create_tween()
	abgang.tween_property(mitte, ^"modulate:a", 0.0, _wartezeit(1.0))
	await abgang.finished
	mitte.queue_free()
