class_name LkwSpiel
extends Node3D

## Die Autobahnfahrt als Spiel: du lenkst den LKW selbst.
##
## Vorher war die Fahrt eine reine Filmsequenz. Jetzt übernimmt man nach
## dem Telefonat das Steuer: A/D (oder Pfeiltasten) wechseln die Spur,
## vor einem schleichen langsamere Autos, auf der Gegenfahrbahn kommt
## Verkehr entgegen. Wer auffährt, verliert Tempo und bekommt eine Hupe —
## kein Scheitern, nur Zeitverlust. Angekommen ist man nach fester
## Strecke, sobald genug Autos überholt sind.
##
## **Die Welt ist 620 m lang, die Fahrt braucht mehr.** Statt die Autobahn
## zu verlängern, springt die ganze Fahrt (LKW plus Verkehr) am Ende der
## Kulisse um eine Weltlänge zurück — auf einer geraden A5 mit Leitplanken
## im 4-m-Takt sieht niemand den Schnitt. Die Kilometeranzeige zählt
## unabhängig davon ehrlich herunter.
##
## Die Kamera sitzt wie in der Filmsequenz in der Kabine (Sitzposition in
## Modellkoordinaten!), mit denselben drei Wackel-Sinusschwingungen; beim
## Lenken neigt sie sich leicht mit.

signal fertig

## Fahrtempo des LKW in m/s, auf das er nach Remplern zurückbeschleunigt.
@export_range(10.0, 35.0, 0.5) var tempo_normal: float = 24.0
## Wie weit gefahren werden muss (Meter, ehrlich gezählt).
@export var ziel_strecke: float = 900.0
## Wie viele Autos überholt sein müssen.
@export var ziel_ueberholer: int = 5
## Seitliches Lenktempo in m/s.
@export_range(1.0, 8.0, 0.1) var lenk_tempo: float = 3.6

## Fahrbahngrenzen (Welt-Z): zwischen Mittelleitplanke und rechtem Rand,
## mit Luft — der LKW ist gut zwei Meter breit.
const Z_MIN := 298.0
const Z_MAX := 302.4
## Spurmitten der eigenen Richtung und der Gegenrichtung.
const SPUREN := [298.0, 301.6]
const GEGEN_SPUREN := [289.4, 293.0]
## Wrap: hinter dieser X-Marke springt die Fahrt eine Weltlänge zurück.
const WELT_ENDE := 250.0
const WELT_LAENGE := 500.0

var tempo: float = 0.0
var strecke: float = 0.0
var ueberholt: int = 0
var laeuft := false

var _lkw: Node3D
var _kamera: Camera3D
var _kulisse: Node
var _motor: AudioStreamPlayer
var _verkehr: Array = []       # je {node, tempo, gegen, gezaehlt}
var _uhr := 0.0
var _rempel_schutz := 0.0
var _stoss := 0.0
var _hud: CanvasLayer
var _stand: Label
var _banner: Label
var _hupe: AudioStreamPlayer

const _AUTO := preload("res://assets/props/auto.glb")


func starten(lkw: Node3D, kamera: Camera3D, kulisse: Node,
		motor: AudioStreamPlayer) -> void:
	_lkw = lkw
	_kamera = kamera
	_kulisse = kulisse
	_motor = motor
	tempo = tempo_normal
	_hud_bauen()
	_verkehr_bauen()
	_hupe_bauen()
	laeuft = true
	set_process(true)
	_banner.text = "DU FÄHRST!   A/D: Spur wechseln   ·   Überhole %d Autos" \
		% ziel_ueberholer
	_banner.visible = true
	get_tree().create_timer(3.0).timeout.connect(
		func() -> void: _banner.visible = false)


func _ready() -> void:
	set_process(false)


func _hud_bauen() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 2
	add_child(_hud)
	_stand = Label.new()
	_stand.position = Vector2(24, 18)
	_stand.add_theme_font_size_override("font_size", 22)
	_stand.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	_stand.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_stand.add_theme_constant_override("outline_size", 6)
	_hud.add_child(_stand)
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(0, 60)
	_banner.size = Vector2(0, 40)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 26)
	_banner.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.visible = false
	_hud.add_child(_banner)


func _verkehr_bauen() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2306
	# Eigene Richtung: sechs Schleicher, verteilt nach vorn.
	for i in 6:
		var auto := _auto_setzen(rng,
			_lkw.global_position.x + 45.0 + i * 55.0 + rng.randf_range(-12.0, 12.0),
			SPUREN[rng.randi() % 2], PI / 2.0)
		_verkehr.append({"node": auto, "tempo": rng.randf_range(13.0, 17.5),
			"gegen": false, "gezaehlt": false})
	# Gegenverkehr: reine Kulisse, macht die Autobahn erst zur Autobahn.
	for i in 4:
		var auto := _auto_setzen(rng,
			_lkw.global_position.x + 80.0 + i * 110.0,
			GEGEN_SPUREN[rng.randi() % 2], -PI / 2.0)
		_verkehr.append({"node": auto, "tempo": rng.randf_range(20.0, 26.0),
			"gegen": true, "gezaehlt": true})


func _auto_setzen(rng: RandomNumberGenerator, x: float, z: float,
		gier: float) -> Node3D:
	# Die richtigen Karosserien mit Flottenfarben kommen aus der Kulisse;
	# ohne Kulisse (nackte Prüfstände) fällt es auf das alte Modell zurück.
	var auto: Node3D
	if _kulisse != null and _kulisse.has_method("auto_bauen"):
		auto = _kulisse.auto_bauen(rng)
	else:
		auto = _AUTO.instantiate() as Node3D
	add_child(auto)
	auto.global_position = Vector3(x, 0.0, z)
	auto.rotation.y = gier
	return auto


func _hupe_bauen() -> void:
	# Zweiklang-Hupe, direkt synthetisiert — kurz, stumpf, unmissverständlich.
	var takt := 22050
	var laenge := int(0.45 * takt)
	var daten := PackedByteArray()
	daten.resize(laenge * 2)
	for i in laenge:
		var t := float(i) / takt
		var huelle := minf(t / 0.02, 1.0) * minf((0.45 - t) / 0.08, 1.0)
		var wert := (sin(TAU * 420.0 * t) * 0.5 + sin(TAU * 330.0 * t) * 0.5) \
			* huelle * 0.5
		var ganz := int(clampf(wert, -1.0, 1.0) * 32767.0)
		daten.encode_s16(i * 2, ganz)
	var klang := AudioStreamWAV.new()
	klang.format = AudioStreamWAV.FORMAT_16_BITS
	klang.mix_rate = takt
	klang.data = daten
	_hupe = AudioStreamPlayer.new()
	_hupe.stream = klang
	_hupe.volume_db = -6.0
	add_child(_hupe)


func _process(delta: float) -> void:
	if not laeuft:
		return
	_uhr += delta
	_rempel_schutz = maxf(_rempel_schutz - delta, 0.0)
	_stoss = maxf(_stoss - delta * 0.25, 0.0)

	# Tempo erholt sich nach Remplern von selbst.
	tempo = move_toward(tempo, tempo_normal, delta * 4.0)
	strecke += tempo * delta

	# Lenken: Achse aus den normalen Bewegungstasten.
	var achse := Input.get_action_strength(&"move_right") \
		- Input.get_action_strength(&"move_left")
	var z_neu: float = clampf(_lkw.global_position.z + achse * lenk_tempo * delta,
		Z_MIN, Z_MAX)
	var seitlich: float = z_neu - _lkw.global_position.z
	_lkw.global_position.z = z_neu
	_lkw.global_position.x += tempo * delta
	# Leichtes Eindrehen in Lenkrichtung — rein optisch.
	_lkw.rotation.y = PI / 2.0 - achse * 0.045
	if _kulisse != null:
		_kulisse.lkw_tempo = tempo

	_verkehr_bewegen(delta)
	_rempler_pruefen()
	_welt_umbrechen()
	_kamera_setzen(seitlich, achse)

	if _motor != null:
		_motor.pitch_scale = 0.85 + tempo / tempo_normal * 0.35

	var rest_km := maxf((ziel_strecke - strecke) * 0.012, 0.0)
	_stand.text = "FRANKFURT %.1f km   ·   ÜBERHOLT %d/%d" \
		% [rest_km, mini(ueberholt, ziel_ueberholer), ziel_ueberholer]

	if strecke >= ziel_strecke and ueberholt >= ziel_ueberholer:
		_ankommen()


func _verkehr_bewegen(delta: float) -> void:
	for eintrag in _verkehr:
		var auto: Node3D = eintrag["node"]
		var richtung := -1.0 if eintrag["gegen"] else 1.0
		auto.global_position.x += eintrag["tempo"] * richtung * delta
		if eintrag["gegen"]:
			# Gegenverkehr: weit hinter dem LKW wieder nach vorn.
			if auto.global_position.x < _lkw.global_position.x - 60.0:
				auto.global_position.x = _lkw.global_position.x \
					+ 160.0 + randf() * 120.0
			continue
		# Überholt: gezählt, sobald der LKW sauber vorbei ist.
		if not eintrag["gezaehlt"] \
				and auto.global_position.x < _lkw.global_position.x - 7.0:
			eintrag["gezaehlt"] = true
			ueberholt += 1
			_banner.text = "ÜBERHOLT!  %d/%d" % [ueberholt, ziel_ueberholer] \
				if ueberholt <= ziel_ueberholer else "FREIE FAHRT!"
			_banner.visible = true
			get_tree().create_timer(1.1).timeout.connect(
				func() -> void: _banner.visible = false)
		# Weit zurückgefallen: vorn als frisches Hindernis wieder rein.
		if auto.global_position.x < _lkw.global_position.x - 40.0:
			auto.global_position.x = _lkw.global_position.x \
				+ 90.0 + randf() * 80.0
			auto.global_position.z = SPUREN[randi() % 2]
			eintrag["tempo"] = randf_range(13.0, 17.5)
			eintrag["gezaehlt"] = false


func _rempler_pruefen() -> void:
	if _rempel_schutz > 0.0:
		return
	for eintrag in _verkehr:
		if eintrag["gegen"]:
			continue
		var auto: Node3D = eintrag["node"]
		var dx: float = auto.global_position.x - _lkw.global_position.x
		var dz: float = absf(auto.global_position.z - _lkw.global_position.z)
		# Der LKW ist lang: vorn zählt der Abstand zur Stoßstange.
		if dx > 0.0 and dx < 6.0 and dz < 1.7:
			tempo = maxf(tempo * 0.45, 7.0)
			_stoss = 1.0
			_rempel_schutz = 1.2
			_hupe.play()
			# Das getroffene Auto rettet sich nach vorn.
			eintrag["tempo"] = maxf(eintrag["tempo"], tempo_normal * 0.85)
			return


func _welt_umbrechen() -> void:
	if _lkw.global_position.x <= WELT_ENDE:
		return
	_lkw.global_position.x -= WELT_LAENGE
	for eintrag in _verkehr:
		(eintrag["node"] as Node3D).global_position.x -= WELT_LAENGE


func _kamera_setzen(seitlich: float, achse: float) -> void:
	# Dieselbe Kabinenkamera wie in der Filmsequenz — Sitz in
	# Modellkoordinaten, Wackeln aus drei Sinusschwingungen, dazu ein
	# Stoß nach Remplern und eine leichte Neigung beim Lenken.
	var ruckeln := Vector3(
		sin(_uhr * 13.0) * 0.006,
		sin(_uhr * 9.3) * 0.010 + sin(_uhr * 24.0) * 0.003,
		sin(_uhr * 7.1) * 0.005)
	ruckeln += Vector3(randf() - 0.5, randf() - 0.5, 0.0) * 0.05 * _stoss
	# Näher an der Scheibe als beim Telefonat: zum Fahren braucht man
	# Straße im Bild, nicht Armaturenbrett.
	_kamera.global_position = _lkw.to_global(Vector3(-0.52, 2.10, 3.85) + ruckeln)
	_kamera.look_at(_lkw.to_global(Vector3(
		-0.30, 1.55 + sin(_uhr * 5.0) * 0.08, 55.0)))
	_kamera.rotation.z = sin(_uhr * 3.7) * 0.006 - achse * 0.02
	_kamera.current = true


func _ankommen() -> void:
	laeuft = false
	set_process(false)
	_banner.text = "AUSFAHRT FRANKFURT"
	_banner.visible = true
	_stand.visible = false
	fertig.emit()


## Räumt HUD und Verkehr ab, wenn die Sequenz weiterzieht.
func abschluss_uebernehmen() -> void:
	_hud.visible = false
	for eintrag in _verkehr:
		(eintrag["node"] as Node3D).queue_free()
	_verkehr.clear()
