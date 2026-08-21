class_name KrugSpiel
extends Node3D

## Krug-Werfen in der Apfelweinkneipe — das Minispiel von Kapitel 2.
##
## Drei Bembel-Pyramiden (3 + 2 + 1) stehen auf dem Wurftisch, geworfen
## wird mit Bällen, die Krüge sind echte starre Körper: Treffer kippen,
## schieben und räumen ab. **Gewonnen ist, wenn alle Krüge gefallen
## sind** — Bälle gibt es unbegrenzt, wie auf dem Jahrmarkt.
##
## Zielen und Werfen fühlen sich an wie beim Spritzen-Minispiel aus
## Kapitel 1: Fadenkreuz in der Ebene der Türme, Taste halten, im grünen
## Bereich loslassen. Die Wurfkraft wirkt nur auf die Höhe.

signal runde_geschafft

enum Zustand { INAKTIV, ZIELEN, LADEN, SIEG }

@export_range(0.2, 2.0, 0.05) var ziel_grenze: float = 1.3
@export_range(0.0002, 0.005, 0.0001) var maus_empfindlichkeit: float = 0.0011
@export_range(0.1, 2.0, 0.05) var gamepad_zielgeschwindigkeit: float = 0.55
@export_range(4.0, 20.0, 0.5) var wurf_tempo: float = 13.0
@export_range(0.4, 3.0, 0.1) var ladezeit: float = 1.1
@export_range(0.0, 0.4, 0.01) var kraft_einfluss: float = 0.10
@export_range(0.02, 0.4, 0.01) var idealzone: float = 0.15
@export_range(0.2, 3.0, 0.1) var wurf_pause: float = 0.8
@export_range(0.0, 6.0, 0.1) var intro_dauer: float = 2.4

const _BEMBEL := preload("res://assets/props/bembel.glb")

## Mitte des Wurftischs (Oberkante) und Wurfpunkt, im Weltraum.
const TISCH := Vector3(400.0, 1.0, -103.0)
const WURF_PUNKT := Vector3(400.0, 1.35, -97.4)
## Ein Krug gilt als gefallen, wenn er so weit von seinem Startplatz weg ist.
const GEFALLEN_WEG := 0.35

var zustand: Zustand = Zustand.INAKTIV
var wuerfe: int = 0

var kamera: Camera3D
var _ziel: Vector2 = Vector2.ZERO
var _kraft: float = 0.0
var _kraft_steigt: bool = true
var _maus: Vector2 = Vector2.ZERO
var _pause: float = 0.0
var _kruege: Array = []       # je {node, start}
var _baelle: Node3D
var _hud: CanvasLayer
var _fadenkreuz: Control
var _balken: Control
var _balken_fuellung: ColorRect
var _stand_label: Label
var _banner: PanelContainer
var _banner_titel: Label
var _banner_zeile: Label
var _wischklang: AudioStreamPlayer
var _klirrklang: AudioStreamPlayer3D
var _siegklang: AudioStreamPlayer


func _ready() -> void:
	set_process(false)
	set_process_unhandled_input(false)
	_baelle = Node3D.new()
	add_child(_baelle)
	_kamera_bauen()
	_tuerme_bauen()
	_hud_bauen()
	_toene_bauen()


func _kamera_bauen() -> void:
	kamera = Camera3D.new()
	kamera.fov = 55.0
	add_child(kamera)
	kamera.global_position = WURF_PUNKT + Vector3(0, 0.25, 1.6)
	kamera.look_at(TISCH + Vector3(0, 0.35, 0))


func _tuerme_bauen() -> void:
	var rumpf := CylinderShape3D.new()
	rumpf.radius = 0.085
	rumpf.height = 0.26
	# Griffige, stumpfe Krüge — und gesäter Zufall, damit jeder Aufbau
	# gleich steht.
	var griff := PhysicsMaterial.new()
	griff.friction = 0.95
	griff.bounce = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1180
	for turm in 3:
		var mitte_x := TISCH.x + (turm - 1) * 1.25
		var reihen: Array = [[-0.19, 0.0, 0.19], [-0.095, 0.095], [0.0]]
		for etage in reihen.size():
			for versatz: float in reihen[etage]:
				var krug := RigidBody3D.new()
				krug.mass = 0.8
				krug.physics_material_override = griff
				krug.angular_damp = 1.5
				# Eingefroren, bis das Spiel beginnt — sonst setzen sich die
				# Stapel während der langen Sequenzen davor von selbst.
				krug.freeze = true
				var form := CollisionShape3D.new()
				form.shape = rumpf
				form.position = Vector3(0, 0.13, 0)
				krug.add_child(form)
				var bild := _BEMBEL.instantiate() as Node3D
				krug.add_child(bild)
				add_child(krug)
				# Reihenabstand = exakte Krughöhe: eine Etage, die auch nur
				# Millimeter über der unteren schwebt, plumpst beim Auftauen
				# auf und wirft den Turm von selbst um.
				krug.global_position = Vector3(
					mitte_x + versatz, TISCH.y + etage * 0.26, TISCH.z)
				krug.rotation.y = rng.randf() * 0.3
				_kruege.append({"node": krug, "start": krug.global_position})
	# Der Wurftisch selbst: sichtbar und fest.
	var tisch := StaticBody3D.new()
	var platte := CollisionShape3D.new()
	var kasten := BoxShape3D.new()
	kasten.size = Vector3(4.4, 0.12, 1.0)
	platte.shape = kasten
	tisch.add_child(platte)
	var bild := MeshInstance3D.new()
	var form := BoxMesh.new()
	form.size = Vector3(4.4, 0.12, 1.0)
	var stoff := StandardMaterial3D.new()
	stoff.albedo_color = Color(0.30, 0.21, 0.14)
	form.material = stoff
	bild.mesh = form
	tisch.add_child(bild)
	add_child(tisch)
	tisch.global_position = TISCH - Vector3(0, 0.06, 0)
	for x in [-1.9, 1.9]:
		var bein := MeshInstance3D.new()
		var holz := BoxMesh.new()
		holz.size = Vector3(0.12, 0.95, 0.7)
		holz.material = stoff
		bein.mesh = holz
		add_child(bein)
		bein.global_position = Vector3(TISCH.x + x, 0.48, TISCH.z)


func _hud_bauen() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 2
	_hud.visible = false
	add_child(_hud)

	_stand_label = Label.new()
	_stand_label.add_theme_font_size_override("font_size", 26)
	_stand_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	_stand_label.anchor_left = 0.5
	_stand_label.anchor_right = 0.5
	_stand_label.offset_left = -220.0
	_stand_label.offset_right = 220.0
	_stand_label.offset_top = 22.0
	_stand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_stand_label)

	_fadenkreuz = Control.new()
	for masse in [Vector2(18, 2), Vector2(2, 18)]:
		var strich := ColorRect.new()
		strich.color = Color(1, 1, 1, 0.9)
		strich.size = masse
		strich.position = -masse / 2.0
		_fadenkreuz.add_child(strich)
	_hud.add_child(_fadenkreuz)

	_balken = Control.new()
	_balken.anchor_left = 0.5
	_balken.anchor_right = 0.5
	_balken.anchor_top = 1.0
	_balken.anchor_bottom = 1.0
	_balken.offset_top = -70.0
	var grund := ColorRect.new()
	grund.color = Color(0, 0, 0, 0.55)
	grund.position = Vector2(-210, 0)
	grund.size = Vector2(420, 20)
	_balken.add_child(grund)
	var zone := ColorRect.new()
	zone.color = Color(0.3, 0.8, 0.4, 0.5)
	zone.position = Vector2(-210 + 420 * (0.5 - idealzone), 0)
	zone.size = Vector2(420 * idealzone * 2.0, 20)
	_balken.add_child(zone)
	_balken_fuellung = ColorRect.new()
	_balken_fuellung.color = Color(0.95, 0.9, 0.8)
	_balken_fuellung.position = Vector2(-210, 4)
	_balken_fuellung.size = Vector2(0, 12)
	_balken.add_child(_balken_fuellung)
	_hud.add_child(_balken)

	_banner = PanelContainer.new()
	var stil := StyleBoxFlat.new()
	stil.bg_color = Color(0, 0, 0, 0.55)
	stil.set_corner_radius_all(10)
	stil.content_margin_left = 26
	stil.content_margin_right = 26
	stil.content_margin_top = 14
	stil.content_margin_bottom = 16
	_banner.add_theme_stylebox_override("panel", stil)
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.anchor_top = 0.62
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var spalte := VBoxContainer.new()
	_banner_titel = Label.new()
	_banner_titel.add_theme_font_size_override("font_size", 34)
	_banner_titel.add_theme_color_override("font_color", Color(0.95, 0.8, 0.4))
	_banner_titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_zeile = Label.new()
	_banner_zeile.add_theme_font_size_override("font_size", 20)
	_banner_zeile.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spalte.add_child(_banner_titel)
	spalte.add_child(_banner_zeile)
	_banner.add_child(spalte)
	_banner.visible = false
	_hud.add_child(_banner)


func _toene_bauen() -> void:
	_wischklang = AudioStreamPlayer.new()
	_wischklang.stream = load("res://audio/wisch.wav")
	_wischklang.volume_db = -6.0
	add_child(_wischklang)
	_klirrklang = AudioStreamPlayer3D.new()
	_klirrklang.stream = load("res://audio/klirren.wav")
	add_child(_klirrklang)
	_klirrklang.global_position = TISCH
	_siegklang = AudioStreamPlayer.new()
	_siegklang.stream = load("res://audio/gewonnen.wav")
	add_child(_siegklang)


func starten() -> void:
	for eintrag in _kruege:
		(eintrag["node"] as RigidBody3D).freeze = false
	kamera.current = true
	_hud.visible = true
	set_process(true)
	set_process_unhandled_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_stand_anzeigen()
	if intro_dauer > 0.0:
		_banner_zeigen("KRÜGE UMWERFEN",
			"Wirf alle Bembel vom Tisch! Taste halten, im grünen Bereich loslassen.")
		await get_tree().create_timer(intro_dauer).timeout
		_banner.visible = false
	zustand = Zustand.ZIELEN


func _banner_zeigen(titel: String, zeile: String) -> void:
	_banner_titel.text = titel
	_banner_zeile.text = zeile
	_banner.visible = true


func gefallen_zaehler() -> int:
	var zahl := 0
	for eintrag in _kruege:
		var krug: RigidBody3D = eintrag["node"]
		if krug.global_position.distance_to(eintrag["start"]) > GEFALLEN_WEG:
			zahl += 1
	return zahl


func _stand_anzeigen() -> void:
	_stand_label.text = "KRÜGE %d / %d   ·   WÜRFE %d" % [
		gefallen_zaehler(), _kruege.size(), wuerfe]


func _process(delta: float) -> void:
	_pause = maxf(_pause - delta, 0.0)
	match zustand:
		Zustand.ZIELEN:
			_zielen(delta)
			if Input.is_action_pressed(&"wurf") and _pause <= 0.0:
				zustand = Zustand.LADEN
				_kraft = 0.0
				_kraft_steigt = true
		Zustand.LADEN:
			_zielen(delta)
			_laden(delta)
			if not Input.is_action_pressed(&"wurf"):
				_werfen()
		_:
			pass
	_stand_anzeigen()
	if zustand in [Zustand.ZIELEN, Zustand.LADEN] \
			and gefallen_zaehler() >= _kruege.size():
		_sieg()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_maus += (event as InputEventMouseMotion).relative


func ziel_punkt() -> Vector3:
	return TISCH + Vector3(_ziel.x, 0.45 + _ziel.y, 0.0)


func _zielen(delta: float) -> void:
	_ziel.x += _maus.x * maus_empfindlichkeit
	_ziel.y -= _maus.y * maus_empfindlichkeit
	_maus = Vector2.ZERO
	var stick := Vector2(
		Input.get_axis(&"look_left", &"look_right"),
		Input.get_axis(&"look_down", &"look_up"))
	_ziel += stick * gamepad_zielgeschwindigkeit * delta
	_ziel = _ziel.limit_length(ziel_grenze)
	_fadenkreuz.position = kamera.unproject_position(ziel_punkt())
	_fadenkreuz.visible = true


func _laden(delta: float) -> void:
	var schritt := delta / maxf(ladezeit, 0.01)
	_kraft += schritt if _kraft_steigt else -schritt
	if _kraft >= 1.0:
		_kraft = 1.0
		_kraft_steigt = false
	elif _kraft <= 0.0:
		_kraft = 0.0
		_kraft_steigt = true
	_balken.visible = true
	_balken_fuellung.size.x = 420.0 * clampf(_kraft, 0.0, 1.0)


func _werfen() -> void:
	zustand = Zustand.ZIELEN
	_pause = wurf_pause
	_balken.visible = false
	wuerfe += 1
	_wischklang.play()

	var ball := RigidBody3D.new()
	ball.mass = 0.55
	# Klein und schnell: ohne Dauerprüfung tunnelt die Kugel durch Krugwände,
	# und die Vorgabe-Dämpfung ließe den Wurf vor dem Tisch absacken.
	ball.continuous_cd = true
	ball.linear_damp = 0.0
	var form := CollisionShape3D.new()
	var kugel := SphereShape3D.new()
	kugel.radius = 0.055
	form.shape = kugel
	ball.add_child(form)
	var bild := MeshInstance3D.new()
	var rund := SphereMesh.new()
	rund.radius = 0.055
	rund.height = 0.11
	var stoff := StandardMaterial3D.new()
	stoff.albedo_color = Color(0.75, 0.2, 0.15)
	stoff.roughness = 0.6
	rund.material = stoff
	bild.mesh = rund
	ball.add_child(bild)
	_baelle.add_child(ball)
	ball.global_position = WURF_PUNKT
	ball.linear_velocity = _wurfgeschwindigkeit(ziel_punkt(), _kraft)
	ball.body_entered.connect(func(_koerper: Node) -> void:
		if not _klirrklang.playing:
			_klirrklang.play())
	ball.contact_monitor = true
	ball.max_contacts_reported = 2
	get_tree().create_timer(5.0).timeout.connect(func() -> void:
		if is_instance_valid(ball):
			ball.queue_free())


func _wurfgeschwindigkeit(ziel: Vector3, kraft: float) -> Vector3:
	var strecke := ziel - WURF_PUNKT
	var flugzeit := maxf(strecke.length() / maxf(wurf_tempo, 0.1), 0.05)
	var schwerkraft: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)
	var geschwindigkeit := strecke / flugzeit
	geschwindigkeit.y += 0.5 * schwerkraft * flugzeit
	return geschwindigkeit * (1.0 + (kraft - 0.5) * 2.0 * kraft_einfluss)


func _sieg() -> void:
	zustand = Zustand.SIEG
	_fadenkreuz.visible = false
	_balken.visible = false
	_siegklang.play()
	_banner_zeigen("ALLE TÜRME!", "%d Würfe. Der Tisch ist leer." % wuerfe)
	runde_geschafft.emit()


## Räumt Anzeige und Eingaben ab — die Sieg-Sequenz übernimmt.
func abschluss_uebernehmen() -> void:
	zustand = Zustand.INAKTIV
	set_process(false)
	set_process_unhandled_input(false)
	_hud.visible = false


## Nur für Prüfläufe: stößt alle Krüge vom Tisch.
func alle_umwerfen_test() -> void:
	for eintrag in _kruege:
		var krug: RigidBody3D = eintrag["node"]
		krug.apply_impulse(Vector3(randf_range(-0.5, 0.5), 1.5, 3.5))
