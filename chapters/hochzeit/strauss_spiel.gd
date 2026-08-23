class_name StraussSpiel
extends Node3D

## Brautstrauß-Fangen — das Minispiel von Kapitel 3.
##
## **Zehn Sträuße fliegen, fünf müssen gefangen werden.** Geworfen wird von
## drei Positionen vor der Braut (Oliver und zwei Gäste), jeder Strauß
## kommt in einem Bogen auf die Kamera zu und dreht sich dabei.
##
## Gefangen wird mit den **Händen**: ein Ring in der Fangebene folgt der
## Maus, ein Klick schließt die Hände für einen Moment. Wer im richtigen
## Augenblick zugreift und die Hände am richtigen Ort hat, fängt.
##
## Warum ein Zeitfenster und kein Auto-Fangen: ohne Klick wäre es ein
## Mauszeiger-Spiel, das man nicht verlieren kann. Mit Klick ist es
## Verfolgen **und** Timing — dieselbe Doppelanforderung wie beim Werfen
## in den beiden Kapiteln davor, nur umgekehrt.

signal runde_geschafft

enum Zustand { INAKTIV, FANGEN, SIEG }

## Wie viele Sträuße je Runde fliegen und wie viele gefangen werden müssen.
const STRAEUSSE_PRO_RUNDE := 10
const FANG_ZIEL := 5

## Die Fangebene. Sie liegt bewusst **2,4 m vor der Kamera**, nicht auf
## Armlänge: bei 80 cm füllte der Fangring den halben Bildschirm und die
## Hände klebten an der Linse. Aus 2,4 m liest sich der Ring als Zielzone
## im Raum, und man sieht, was hinter ihm passiert.
const FANG_Z := 6.4
## Ruhehöhe der Hände.
const HAND_HOEHE := 1.34
## Wo die Braut steht (Blickrichtung -Z, auf den Traubogen).
const BRAUT := Vector3(0.0, 0.0, 9.0)
## Die drei Wurfpositionen vor ihr.
const WERFER: Array[Vector3] = [
	Vector3(-3.4, 1.45, 2.4), Vector3(0.2, 1.5, 1.9), Vector3(3.6, 1.45, 2.6),
]

@export_range(0.0002, 0.006, 0.0001) var maus_empfindlichkeit: float = 0.0026
@export_range(0.2, 3.0, 0.1) var gamepad_tempo: float = 1.6
## Halbe Breite und Höhe, in der die Hände bewegt werden können (Meter).
@export_range(0.5, 3.0, 0.1) var reichweite_breit: float = 1.7
@export_range(0.4, 2.0, 0.1) var reichweite_hoch: float = 1.15
## Wie weit vom Handmittelpunkt ein Strauß noch gefangen wird.
@export_range(0.2, 1.2, 0.05) var fang_radius: float = 0.58
## Wie lange die Hände nach einem Klick geschlossen bleiben.
@export_range(0.1, 1.0, 0.05) var greifdauer: float = 0.45
## Pause zwischen zwei Griffen.
@export_range(0.0, 1.0, 0.05) var greif_pause: float = 0.22
## Flugzeit eines Straußes.
@export_range(0.8, 3.0, 0.1) var flugzeit: float = 1.2
## Abstand zwischen zwei Würfen.
@export_range(0.5, 4.0, 0.1) var wurf_abstand: float = 1.9
@export_range(0.0, 6.0, 0.1) var intro_dauer: float = 2.8

const _STRAUSS := preload("res://assets/props/strauss.glb")

var zustand: Zustand = Zustand.INAKTIV
var gefangen: int = 0
var geworfen: int = 0
var verpasst: int = 0

var kamera: Camera3D
## Zeigt auf die Werfer, damit das Kapitel sie animieren kann.
var werfer_marken: Array[Vector3] = WERFER

var _ziel: Vector2 = Vector2.ZERO
var _maus: Vector2 = Vector2.ZERO
var _greift: float = 0.0
var _pause: float = 0.0
var _bis_naechster: float = 0.0
var _runde_laeuft := false
var _fliegende: Array = []      # je {node, start, ziel, uhr, drehachse}

var _haende: Node3D
var _hand_links: MeshInstance3D
var _hand_rechts: MeshInstance3D
var _ring: MeshInstance3D
var _hand_stoff: StandardMaterial3D
var _ring_stoff: StandardMaterial3D

var _hud: CanvasLayer
var _stand_label: Label
var _zuruf: Label
var _zuruf_tween: Tween
var _banner: PanelContainer
var _banner_titel: Label
var _banner_zeile: Label

var _luftklang: AudioStreamPlayer
var _fangklang: AudioStreamPlayer
var _jubelklang: AudioStreamPlayer
var _siegklang: AudioStreamPlayer


func _ready() -> void:
	set_process(false)
	set_process_unhandled_input(false)
	_kamera_bauen()
	_haende_bauen()
	_hud_bauen()
	_toene_bauen()


func _kamera_bauen() -> void:
	kamera = Camera3D.new()
	kamera.fov = 62.0
	add_child(kamera)
	# **Ich-Perspektive**, auf Augenhöhe der Braut. Der erste Versuch stand
	# über ihrer Schulter — dann steht sie mitten im Bild und verdeckt genau
	# den Fangring, den man braucht. Von ihren Augen aus sieht man Bogen,
	# Gäste, Wasser und Brücke, und die Hände liegen vorn im Bild.
	kamera.global_position = BRAUT + Vector3(0.0, 1.62, -0.2)
	kamera.look_at(Vector3(0.0, 1.45, 2.2))


## Die Hände: zwei flache Schalen und ein Ring, der die Fangzone zeigt.
##
## Der Ring ist keine Zierde — ohne eine sichtbare Fangzone rät man, und
## das Spiel fühlt sich unfair an. Er wird beim Zugreifen kleiner und
## heller: das ist die ganze Rückmeldung, die der Griff braucht.
func _haende_bauen() -> void:
	_haende = Node3D.new()
	add_child(_haende)
	_hand_stoff = StandardMaterial3D.new()
	_hand_stoff.albedo_color = Color(0.86, 0.68, 0.58)
	_hand_stoff.roughness = 0.75

	for seite in [-1.0, 1.0]:
		var hand := MeshInstance3D.new()
		var form := SphereMesh.new()
		form.radius = 0.115
		form.height = 0.16
		form.material = _hand_stoff
		hand.mesh = form
		hand.scale = Vector3(1.25, 0.55, 1.0)
		_haende.add_child(hand)
		hand.position = Vector3(seite * 0.17, 0.0, 0.0)
		if seite < 0.0:
			_hand_links = hand
		else:
			_hand_rechts = hand

	_ring = MeshInstance3D.new()
	var reifen := TorusMesh.new()
	reifen.inner_radius = fang_radius - 0.05
	reifen.outer_radius = fang_radius
	reifen.rings = 24
	var leuchten := StandardMaterial3D.new()
	leuchten.albedo_color = Color(1.0, 0.96, 0.88, 0.5)
	leuchten.emission_enabled = true
	leuchten.emission = Color(1.0, 0.94, 0.80)
	leuchten.emission_energy_multiplier = 1.4
	leuchten.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	leuchten.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	reifen.material = leuchten
	_ring_stoff = leuchten
	_ring.mesh = reifen
	_ring.rotation.x = PI / 2.0
	_haende.add_child(_ring)
	_haende.global_position = Vector3(0.0, HAND_HOEHE, FANG_Z)
	_haende.visible = false


func _hud_bauen() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 2
	_hud.visible = false
	add_child(_hud)

	_stand_label = Label.new()
	_stand_label.add_theme_font_size_override("font_size", 26)
	_stand_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92))
	_stand_label.add_theme_constant_override("outline_size", 5)
	_stand_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_stand_label.anchor_left = 0.5
	_stand_label.anchor_right = 0.5
	_stand_label.offset_left = -260.0
	_stand_label.offset_right = 260.0
	_stand_label.offset_top = 22.0
	_stand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_stand_label)

	_zuruf = Label.new()
	_zuruf.add_theme_font_size_override("font_size", 22)
	_zuruf.add_theme_color_override("font_color", Color(0.99, 0.90, 0.66))
	_zuruf.add_theme_constant_override("outline_size", 6)
	_zuruf.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_zuruf.anchor_left = 0.5
	_zuruf.anchor_right = 0.5
	_zuruf.offset_left = -300.0
	_zuruf.offset_right = 300.0
	_zuruf.offset_top = 62.0
	_zuruf.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zuruf.modulate.a = 0.0
	_hud.add_child(_zuruf)

	_banner = PanelContainer.new()
	var stil := StyleBoxFlat.new()
	stil.bg_color = Color(0, 0, 0, 0.5)
	stil.set_corner_radius_all(10)
	stil.content_margin_left = 26
	stil.content_margin_right = 26
	stil.content_margin_top = 14
	stil.content_margin_bottom = 16
	_banner.add_theme_stylebox_override("panel", stil)
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.anchor_top = 0.6
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var spalte := VBoxContainer.new()
	_banner_titel = Label.new()
	_banner_titel.add_theme_font_size_override("font_size", 34)
	_banner_titel.add_theme_color_override("font_color", Color(0.98, 0.90, 0.62))
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
	_luftklang = AudioStreamPlayer.new()
	_luftklang.stream = load("res://audio/wisch.wav")
	_luftklang.volume_db = -10.0
	add_child(_luftklang)
	_fangklang = AudioStreamPlayer.new()
	_fangklang.stream = load("res://audio/volltreffer.wav")
	_fangklang.volume_db = -3.0
	add_child(_fangklang)
	_jubelklang = AudioStreamPlayer.new()
	_jubelklang.stream = load("res://audio/jubel.wav")
	_jubelklang.volume_db = -6.0
	add_child(_jubelklang)
	_siegklang = AudioStreamPlayer.new()
	_siegklang.stream = load("res://audio/gewonnen.wav")
	add_child(_siegklang)


# --- Ablauf -------------------------------------------------------------------


func starten() -> void:
	kamera.current = true
	_hud.visible = true
	_haende.visible = true
	set_process(true)
	set_process_unhandled_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_stand_anzeigen()
	if intro_dauer > 0.0:
		_banner_zeigen("BRAUTSTRÄUSSE FANGEN",
			"%d fliegen, %d musst du fangen. Maus bewegen, klicken zum Zugreifen."
				% [STRAEUSSE_PRO_RUNDE, FANG_ZIEL])
		await get_tree().create_timer(intro_dauer).timeout
		_banner.visible = false
	zustand = Zustand.FANGEN
	_runde_starten()


func _runde_starten() -> void:
	gefangen = 0
	geworfen = 0
	verpasst = 0
	_bis_naechster = 0.8
	_runde_laeuft = true
	_stand_anzeigen()


func _banner_zeigen(titel: String, zeile: String) -> void:
	_banner_titel.text = titel
	_banner_zeile.text = zeile
	_banner.visible = true


func _stand_anzeigen() -> void:
	_stand_label.text = "GEFANGEN %d / %d   ·   STRÄUSSE %d / %d" % [
		gefangen, FANG_ZIEL, geworfen, STRAEUSSE_PRO_RUNDE]


func _process(delta: float) -> void:
	_pause = maxf(_pause - delta, 0.0)
	_greift = maxf(_greift - delta, 0.0)
	if zustand == Zustand.FANGEN:
		_haende_fuehren(delta)
		if Input.is_action_just_pressed(&"wurf") and _pause <= 0.0:
			greifen()
		_wuerfe_verwalten(delta)
	_fluege_bewegen(delta)


## Öffentlich, damit der Prüflauf zugreifen kann, ohne Eingaben zu spielen.
func greifen() -> void:
	_greift = greifdauer
	_pause = greifdauer + greif_pause


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_maus += (event as InputEventMouseMotion).relative


## Die Hände folgen der Maus in der Fangebene — mit Dämpfung, damit sie
## Gewicht haben. Ohne Dämpfung springen sie wie ein Mauszeiger.
func _haende_fuehren(delta: float) -> void:
	_ziel.x += _maus.x * maus_empfindlichkeit
	_ziel.y -= _maus.y * maus_empfindlichkeit
	_maus = Vector2.ZERO
	var stick := Vector2(
		Input.get_axis(&"look_left", &"look_right"),
		Input.get_axis(&"look_down", &"look_up"))
	_ziel += stick * gamepad_tempo * delta
	_ziel.x = clampf(_ziel.x, -reichweite_breit, reichweite_breit)
	_ziel.y = clampf(_ziel.y, -reichweite_hoch, reichweite_hoch)

	var soll := Vector3(_ziel.x, HAND_HOEHE + _ziel.y, FANG_Z)
	_haende.global_position = _haende.global_position.lerp(soll,
		clampf(delta * 14.0, 0.0, 1.0))

	# Zugreifen: Hände zusammen, Ring kleiner und heller.
	var zu := _greift > 0.0
	var spanne := 0.055 if zu else 0.17
	_hand_links.position.x = lerpf(_hand_links.position.x, -spanne, delta * 22.0)
	_hand_rechts.position.x = lerpf(_hand_rechts.position.x, spanne, delta * 22.0)
	var groesse := 0.72 if zu else 1.0
	_ring.scale = _ring.scale.lerp(Vector3.ONE * groesse, delta * 18.0)
	if _ring_stoff != null:
		_ring_stoff.emission_energy_multiplier = lerpf(
			_ring_stoff.emission_energy_multiplier, 3.4 if zu else 1.2,
			delta * 16.0)


func _wuerfe_verwalten(delta: float) -> void:
	if not _runde_laeuft:
		return
	if geworfen < STRAEUSSE_PRO_RUNDE:
		_bis_naechster -= delta
		if _bis_naechster <= 0.0:
			_werfen()
			_bis_naechster = wurf_abstand
	elif _fliegende.is_empty():
		_runde_beenden()


func _werfen() -> void:
	geworfen += 1
	var strauss := _STRAUSS.instantiate() as Node3D
	add_child(strauss)
	var start: Vector3 = WERFER[(geworfen - 1) % WERFER.size()]
	strauss.global_position = start
	# Das Ziel streut um die Ruhelage der Hände — sonst müsste man sich
	# nie bewegen.
	var streuung := Vector2(
		randf_range(-reichweite_breit, reichweite_breit) * 0.78,
		randf_range(-reichweite_hoch, reichweite_hoch) * 0.7)
	var ziel := Vector3(streuung.x, HAND_HOEHE + streuung.y, FANG_Z)
	_fliegende.append({
		"node": strauss,
		"start": start,
		"ziel": ziel,
		"uhr": 0.0,
		"achse": Vector3(randf_range(-1.0, 1.0), randf_range(-0.4, 0.4),
			randf_range(-1.0, 1.0)).normalized(),
		"tempo": randf_range(4.0, 7.5),
	})
	_luftklang.pitch_scale = randf_range(0.9, 1.15)
	_luftklang.play()
	_stand_anzeigen()


## Die Flugbahn ist eine Parabel zwischen zwei Punkten, ausgewertet über
## den Fortschritt — nicht aufsummiert. Der Einschlagzeitpunkt steht damit
## beim Abwurf fest und hängt nicht an der Bildrate (dieselbe Lehre wie
## beim Dart-Minispiel in Kapitel 1).
func _fluege_bewegen(delta: float) -> void:
	var fertig: Array = []
	for flug in _fliegende:
		flug["uhr"] += delta
		var t: float = flug["uhr"] / flugzeit
		var strauss: Node3D = flug["node"]
		if not is_instance_valid(strauss):
			fertig.append(flug)
			continue
		var start: Vector3 = flug["start"]
		var ziel: Vector3 = flug["ziel"]
		var ort := start.lerp(ziel, minf(t, 1.35))
		# Wurfbogen: 1,3 m Stich in der Mitte.
		ort.y += sin(clampf(t, 0.0, 1.0) * PI) * 1.3
		strauss.global_position = ort
		strauss.rotate(flug["achse"], flug["tempo"] * delta)

		if t >= 1.0 and not flug.get("bewertet", false):
			flug["bewertet"] = true
			if _fangversuch(ziel):
				_fangen(strauss)
				fertig.append(flug)
				continue
			else:
				_verpassen()
		# Nach dem Durchflug noch kurz weiterfliegen und dann verschwinden.
		if t > 1.35:
			strauss.queue_free()
			fertig.append(flug)
	for flug in fertig:
		_fliegende.erase(flug)


## Gefangen, wenn im Moment des Durchflugs zugegriffen wird **und** die
## Hände nah genug sind.
func _fangversuch(ziel: Vector3) -> bool:
	if _greift <= 0.0:
		return false
	var hier := _haende.global_position
	return Vector2(hier.x - ziel.x, hier.y - ziel.y).length() <= fang_radius


func _fangen(strauss: Node3D) -> void:
	gefangen += 1
	strauss.queue_free()
	_fangklang.pitch_scale = randf_range(0.95, 1.1)
	_fangklang.play()
	_jubelklang.play()
	_stand_anzeigen()
	if gefangen >= FANG_ZIEL:
		_sieg()
		return
	var rest := FANG_ZIEL - gefangen
	if rest == 1:
		_zuruf_zeigen("Noch einer!")
	else:
		_zuruf_zeigen(["Gefangen!", "Sauber.", "Weiter so!",
			"Der war schwer."].pick_random())


func _verpassen() -> void:
	verpasst += 1
	_stand_anzeigen()
	var offen := STRAEUSSE_PRO_RUNDE - geworfen + (FANG_ZIEL - gefangen)
	if offen <= FANG_ZIEL - gefangen:
		_zuruf_zeigen("Jetzt zählt jeder!")
	elif verpasst % 2 == 0:
		_zuruf_zeigen(["Daneben.", "Knapp!", "Der nächste kommt."].pick_random())


func _zuruf_zeigen(text: String) -> void:
	if _zuruf == null:
		return
	_zuruf.text = text
	if _zuruf_tween != null and _zuruf_tween.is_valid():
		_zuruf_tween.kill()
	_zuruf.modulate.a = 0.0
	_zuruf_tween = create_tween()
	_zuruf_tween.tween_property(_zuruf, ^"modulate:a", 1.0, 0.15)
	_zuruf_tween.tween_interval(1.2)
	_zuruf_tween.tween_property(_zuruf, ^"modulate:a", 0.0, 0.5)


## Alle zehn geworfen, das Ziel nicht erreicht: freundlich neu beginnen.
## Wie im Masken-Minispiel aus Kapitel 1 — verlieren soll hier niemand.
func _runde_beenden() -> void:
	if gefangen >= FANG_ZIEL:
		return
	_runde_laeuft = false
	_banner_zeigen("%d von %d" % [gefangen, FANG_ZIEL],
		"Die Gäste sammeln die Sträuße wieder ein. Noch eine Runde!")
	await get_tree().create_timer(2.6).timeout
	if zustand != Zustand.FANGEN:
		return
	_banner.visible = false
	_runde_starten()


func _sieg() -> void:
	zustand = Zustand.SIEG
	_runde_laeuft = false
	for flug in _fliegende:
		var strauss: Node3D = flug["node"]
		if is_instance_valid(strauss):
			strauss.queue_free()
	_fliegende.clear()
	_siegklang.play()
	_jubelklang.play()
	_banner_zeigen("GEFANGEN!",
		"%d von %d. Der Tag gehört dir." % [gefangen, STRAEUSSE_PRO_RUNDE])
	runde_geschafft.emit()


## Räumt Anzeige und Eingaben ab — die Schluss-Sequenz übernimmt.
func abschluss_uebernehmen() -> void:
	zustand = Zustand.INAKTIV
	set_process(false)
	set_process_unhandled_input(false)
	_hud.visible = false
	_haende.visible = false


## Nur für Prüfläufe: fängt den nächsten Strauß, der die Ebene erreicht.
func alle_fangen_test() -> void:
	gefangen = FANG_ZIEL - 1
	_stand_anzeigen()
