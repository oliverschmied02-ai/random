class_name TruhenFinale
extends Node3D

## Das Finale nach dem gewonnenen Straußfangen: eine verschlossene
## Schatztruhe auf dem roten Teppich. Anne läuft hin, ein Zahlenpad
## erscheint — **zwei Stellen**, dazu der Hinweis („Die Antwort auf die
## Frage nach dem Leben, dem Universum und dem ganzen Rest"). Bei 42
## springt das Schloss ab, der Deckel öffnet sich, und aus der Truhe
## schwebt ein Rucksack — das Geschenk.
##
## Falsche Codes schütteln das Pad und leeren die Eingabe; verlieren
## kann man hier nichts mehr, nur rätseln. Eingabe per Mausklick auf
## die Knöpfe oder direkt über die Zifferntasten.

signal geoeffnet

const _TRUHE := preload("res://assets/hochzeit/truhe.glb")
const _RUCKSACK := preload("res://assets/hochzeit/rucksack.glb")
const CODE := "42"

## Weltlage der Truhe (Front schaut nach +Z; `gier` dreht sie).
@export var ort: Vector3 = Vector3.ZERO
@export var gier: float = 0.0

var offen := false
## Für Prüfläufe lesbar: die aktuelle Eingabe.
var eingabe := ""

var _truhe: Node3D
var _deckel: Node3D
var _schloss: Node3D
var _rucksack: Node3D
var _zone: Area3D
var _erreicht := false

var _schicht: CanvasLayer
var _pad: PanelContainer
var _stellen: Array[Label] = []
var _hinweis: Label


func _ready() -> void:
	_truhe = _TRUHE.instantiate() as Node3D
	add_child(_truhe)
	_truhe.position = ort
	_truhe.rotation.y = gier
	_deckel = _truhe.find_child("deckel", true, false) as Node3D
	_schloss = _truhe.find_child("schloss", true, false) as Node3D

	# Warmes Licht, das erst beim Öffnen aufglüht.
	_zone = Area3D.new()
	# Die Spielerin liegt auf Kollisionsebene 2 (wie bei den Zonen der
	# Kapitel-Szenen) — die Standardmaske 1 sähe nur den Boden.
	_zone.collision_layer = 0
	_zone.collision_mask = 2
	var form := CollisionShape3D.new()
	var kugel := SphereShape3D.new()
	kugel.radius = 1.9
	form.shape = kugel
	_zone.add_child(form)
	add_child(_zone)
	_zone.position = ort + Vector3(0, 0.5, 0)
	# Nur die Spielerin zählt — Boden und Kulisse überlappen die Zone auch.
	_zone.body_entered.connect(func(koerper: Node3D) -> void:
		if koerper is Player:
			_erreicht = true)

	_pad_bauen()


## Wahr, sobald eine Spielerfigur die Truhe erreicht hat.
func erreicht() -> bool:
	return _erreicht


# --- Das Zahlenpad ---------------------------------------------------------------


func _pad_bauen() -> void:
	_schicht = CanvasLayer.new()
	_schicht.layer = 12
	_schicht.visible = false
	add_child(_schicht)

	_pad = PanelContainer.new()
	var stil := StyleBoxFlat.new()
	stil.bg_color = Color(0.07, 0.06, 0.05, 0.93)
	stil.border_color = Color(0.72, 0.60, 0.32)
	stil.set_border_width_all(2)
	stil.set_corner_radius_all(14)
	stil.content_margin_left = 34
	stil.content_margin_right = 34
	stil.content_margin_top = 24
	stil.content_margin_bottom = 26
	_pad.add_theme_stylebox_override("panel", stil)
	_pad.anchor_left = 0.5
	_pad.anchor_right = 0.5
	_pad.anchor_top = 0.5
	_pad.anchor_bottom = 0.5
	_pad.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pad.grow_vertical = Control.GROW_DIRECTION_BOTH
	_schicht.add_child(_pad)

	var spalte := VBoxContainer.new()
	spalte.add_theme_constant_override("separation", 14)
	_pad.add_child(spalte)

	var titel := Label.new()
	titel.text = "EIN SCHLOSS MIT ZWEI ZAHLEN"
	titel.add_theme_font_size_override("font_size", 24)
	titel.add_theme_color_override("font_color", Color(0.95, 0.88, 0.70))
	titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spalte.add_child(titel)

	_hinweis = Label.new()
	_hinweis.text = HochzeitDialogue.TRUHE_HINWEIS
	_hinweis.add_theme_font_size_override("font_size", 18)
	_hinweis.add_theme_color_override("font_color", Color(0.78, 0.75, 0.68))
	_hinweis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hinweis.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hinweis.custom_minimum_size = Vector2(420, 0)
	spalte.add_child(_hinweis)

	# Die zwei Stellen — groß und leer, damit klar ist: genau zwei Ziffern.
	var stellen := HBoxContainer.new()
	stellen.alignment = BoxContainer.ALIGNMENT_CENTER
	stellen.add_theme_constant_override("separation", 18)
	spalte.add_child(stellen)
	for i in 2:
		var feld := Label.new()
		feld.text = "_"
		feld.add_theme_font_size_override("font_size", 54)
		feld.add_theme_color_override("font_color", Color(0.97, 0.92, 0.78))
		feld.custom_minimum_size = Vector2(64, 0)
		feld.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var kasten := PanelContainer.new()
		var feld_stil := StyleBoxFlat.new()
		feld_stil.bg_color = Color(0.13, 0.11, 0.09)
		feld_stil.border_color = Color(0.55, 0.46, 0.26)
		feld_stil.set_border_width_all(1)
		feld_stil.set_corner_radius_all(8)
		kasten.add_theme_stylebox_override("panel", feld_stil)
		kasten.add_child(feld)
		stellen.add_child(kasten)
		_stellen.append(feld)

	# Das Pad: 1–9, darunter ⌫ 0 — Telefonanordnung.
	var gitter := GridContainer.new()
	gitter.columns = 3
	gitter.add_theme_constant_override("h_separation", 10)
	gitter.add_theme_constant_override("v_separation", 10)
	var mitte := HBoxContainer.new()
	mitte.alignment = BoxContainer.ALIGNMENT_CENTER
	mitte.add_child(gitter)
	spalte.add_child(mitte)
	for zeichen in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", " "]:
		if zeichen == " ":
			var platz := Control.new()
			platz.custom_minimum_size = Vector2(76, 56)
			gitter.add_child(platz)
			continue
		var knopf := Button.new()
		knopf.text = zeichen
		knopf.custom_minimum_size = Vector2(76, 56)
		knopf.add_theme_font_size_override("font_size", 26)
		knopf.focus_mode = Control.FOCUS_NONE
		knopf.pressed.connect(_auf_knopf.bind(zeichen))
		gitter.add_child(knopf)


func pad_zeigen() -> void:
	_schicht.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_process_unhandled_key_input(true)


func _unhandled_key_input(event: InputEvent) -> void:
	if offen or not _schicht.visible:
		return
	var taste := event as InputEventKey
	if taste == null or not taste.pressed:
		return
	if taste.keycode >= KEY_0 and taste.keycode <= KEY_9:
		ziffer_eingeben(str(taste.keycode - KEY_0))
	elif taste.keycode >= KEY_KP_0 and taste.keycode <= KEY_KP_9:
		ziffer_eingeben(str(taste.keycode - KEY_KP_0))
	elif taste.keycode == KEY_BACKSPACE:
		_loeschen()


func _auf_knopf(zeichen: String) -> void:
	if zeichen == "⌫":
		_loeschen()
	else:
		ziffer_eingeben(zeichen)


## Öffentlich, damit der Prüflauf tippen kann. Zwei Ziffern → Prüfung.
func ziffer_eingeben(ziffer: String) -> void:
	if offen or eingabe.length() >= 2:
		return
	eingabe += ziffer
	_stellen_zeigen()
	if eingabe.length() == 2:
		if eingabe == CODE:
			_oeffnen()
		else:
			_falsch()


func _loeschen() -> void:
	eingabe = eingabe.left(maxi(eingabe.length() - 1, 0))
	_stellen_zeigen()


func _stellen_zeigen() -> void:
	for i in 2:
		_stellen[i].text = eingabe[i] if i < eingabe.length() else "_"


## Falscher Code: rot aufleuchten, schütteln, leeren.
func _falsch() -> void:
	for feld in _stellen:
		feld.add_theme_color_override("font_color", Color(0.92, 0.30, 0.26))
	var ruck := create_tween()
	var lage := _pad.position
	for versatz in [14.0, -11.0, 7.0, -4.0, 0.0]:
		ruck.tween_property(_pad, ^"position:x", lage.x + versatz, 0.05)
	await ruck.finished
	eingabe = ""
	_stellen_zeigen()
	for feld in _stellen:
		feld.add_theme_color_override("font_color", Color(0.97, 0.92, 0.78))


## Richtiger Code: Pad weg, Schloss fällt, Deckel auf, Licht an, der
## Rucksack schwebt heraus und dreht sich langsam.
func _oeffnen() -> void:
	offen = true
	var abgang := create_tween()
	abgang.tween_property(_pad, ^"modulate:a", 0.0, 0.35)
	abgang.tween_callback(func() -> void: _schicht.visible = false)

	# Das Schloss springt auf und fällt vor die Truhe.
	if _schloss != null:
		var fall := create_tween()
		fall.tween_property(_schloss, ^"position",
			_schloss.position + Vector3(0.06, -0.05, 0.16), 0.22)
		fall.parallel().tween_property(_schloss, ^"rotation:x", 0.9, 0.22)
		fall.tween_property(_schloss, ^"position:y",
			_schloss.position.y - 0.30, 0.30) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		fall.tween_callback(func() -> void: _schloss.visible = false)

	await get_tree().create_timer(0.45).timeout

	# Deckel auf — Scharnier liegt im GLB an der hinteren Oberkante.
	if _deckel != null:
		var auf := create_tween()
		auf.tween_property(_deckel, ^"rotation:x", -1.65, 1.1) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	var glut := OmniLight3D.new()
	glut.light_color = Color(1.0, 0.85, 0.55)
	glut.light_energy = 0.0
	glut.omni_range = 3.2
	add_child(glut)
	glut.position = ort + Vector3(0, 0.5, 0)
	var glimmen := create_tween()
	glimmen.tween_property(glut, ^"light_energy", 2.6, 0.9)

	await get_tree().create_timer(0.7).timeout

	# Der Rucksack: steigt aus der Truhe, dreht sich, schwebt dann oben.
	_rucksack = _RUCKSACK.instantiate() as Node3D
	add_child(_rucksack)
	_rucksack.position = ort + Vector3(0, 0.1, 0)
	_rucksack.scale = Vector3.ONE * 0.6
	var flug := create_tween()
	flug.tween_property(_rucksack, ^"position:y", ort.y + 1.35, 2.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	flug.parallel().tween_property(_rucksack, ^"scale", Vector3.ONE, 2.2)
	await flug.finished
	set_process(true)
	geoeffnet.emit()


## Das Schweben nach dem Aufstieg: langsame Drehung, leichtes Atmen.
func _process(delta: float) -> void:
	if _rucksack == null:
		return
	_rucksack.rotation.y += delta * 0.7
	_rucksack.position.y = ort.y + 1.35 \
		+ sin(Time.get_ticks_msec() / 1000.0 * 1.6) * 0.05


func _init() -> void:
	set_process(false)
