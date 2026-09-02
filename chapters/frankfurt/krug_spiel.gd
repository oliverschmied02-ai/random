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
@export_range(4.0, 20.0, 0.5) var wurf_tempo: float = 19.0
@export_range(0.4, 3.0, 0.1) var ladezeit: float = 1.1
@export_range(0.0, 0.4, 0.01) var kraft_einfluss: float = 0.10
@export_range(0.02, 0.4, 0.01) var idealzone: float = 0.15
@export_range(0.2, 3.0, 0.1) var wurf_pause: float = 0.8
@export_range(0.0, 6.0, 0.1) var intro_dauer: float = 2.4

const _BEMBEL := preload("res://assets/props/bembel.glb")
const _BALL := preload("res://assets/props/wurfball.glb")

## Mitte des Wurftischs (Oberkante) und Wurfpunkt, im Weltraum.
const TISCH := Vector3(400.0, 1.0, -103.0)
const WURF_PUNKT := Vector3(400.0, 1.35, -97.4)
## Ein Krug gilt als gefallen, wenn er so weit von seinem Startplatz weg ist.
const GEFALLEN_WEG := 0.35
## Wie viele Pyramiden auf dem Tisch stehen (je 3 + 2 + 1 Krüge).
## Achtzehn Krüge waren zu viele — ein guter Wurf räumt drei ab, und der
## Tisch wurde nicht leer, sondern zäh.
const TUERME := 2
## Wie viele Bälle eine Runde hat. Ohne Budget war das Spiel nicht zu
## verlieren — man warf einfach, bis der Tisch leer war. Acht Bälle für
## zwölf Krüge heißt: gute Würfe müssen mehrere fällen, schlampige Runden
## bauen die Türme neu auf (freundlich, wie beim Brautstrauß — kein
## Scheitern, nur nochmal).
const WURF_VORRAT := 8
## Maßstab der Krüge. Ein echter Bembel ist gut 30 cm hoch; in der ersten
## Fassung standen Miniaturen auf dem Tisch.
const KRUG_GROESSE := 1.25

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
## Stärke des Kamerastoßes, klingt in `_process` aus.
var _stoss: float = 0.0
var _kamera_ruhe: Vector3 = Vector3.ZERO
## Wie viele Krüge beim letzten Zählen lagen — für die Zurufe.
var _gefallen_zuletzt: int = 0
## Wächter gegen doppelten Rundenneustart, solange die Banner-Pause läuft.
var _neustart_laeuft := false
var _zuruf: Label
var _zuruf_tween: Tween


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
	kamera.fov = 46.0
	add_child(kamera)
	kamera.global_position = WURF_PUNKT + Vector3(0, 0.25, 1.6)
	kamera.look_at(TISCH + Vector3(0, 0.35, 0))


func _tuerme_bauen() -> void:
	var rumpf := CylinderShape3D.new()
	rumpf.radius = 0.085 * KRUG_GROESSE
	rumpf.height = 0.26 * KRUG_GROESSE
	# Griffige, stumpfe Krüge — und gesäter Zufall, damit jeder Aufbau
	# gleich steht.
	var griff := PhysicsMaterial.new()
	griff.friction = 0.95
	griff.bounce = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1180
	# Genau ein Krugdurchmesser Abstand: die Krüge berühren sich, damit ein
	# Treffer durch den Stapel läuft.
	var breite := 0.172 * KRUG_GROESSE
	var etagenhoehe := 0.26 * KRUG_GROESSE
	for turm in TUERME:
		var mitte_x := TISCH.x + (turm - (TUERME - 1) * 0.5) * 1.55
		var reihen: Array = [[-breite, 0.0, breite],
			[-breite * 0.5, breite * 0.5], [0.0]]
		for etage in reihen.size():
			for versatz: float in reihen[etage]:
				var krug := RigidBody3D.new()
				krug.mass = 0.75
				krug.physics_material_override = griff
				krug.angular_damp = 0.35
				# Nicht einschlafen lassen: ein ruhender Körper nimmt den
				# Stoß aus `_kettenreaktion` nicht an — er bleibt stehen,
				# als wäre nichts gewesen. Zwölf wache Körper kosten nichts.
				krug.can_sleep = false
				# Eingefroren, bis das Spiel beginnt — sonst setzen sich die
				# Stapel während der langen Sequenzen davor von selbst.
				krug.freeze = true
				var form := CollisionShape3D.new()
				form.shape = rumpf
				form.position = Vector3(0, 0.13 * KRUG_GROESSE, 0)
				krug.add_child(form)
				var bild := _BEMBEL.instantiate() as Node3D
				bild.scale = Vector3.ONE * KRUG_GROESSE
				krug.add_child(bild)
				add_child(krug)
				# Reihenabstand = exakte Krughöhe: eine Etage, die auch nur
				# Millimeter über der unteren schwebt, plumpst beim Auftauen
				# auf und wirft den Turm von selbst um.
				krug.global_position = Vector3(
					mitte_x + versatz, TISCH.y + etage * etagenhoehe, TISCH.z)
				krug.rotation.y = rng.randf() * 0.3
				_kruege.append({"node": krug, "start": krug.global_position,
					"drehung": krug.rotation.y, "gefallen": false})
	_ziel = zielvorschlag()

	# Der Wurftisch selbst: sichtbar und fest.
	var tisch := StaticBody3D.new()
	var platte := CollisionShape3D.new()
	var kasten := BoxShape3D.new()
	kasten.size = Vector3(3.4, 0.12, 1.0)
	platte.shape = kasten
	tisch.add_child(platte)
	var bild := MeshInstance3D.new()
	var form := BoxMesh.new()
	form.size = Vector3(3.4, 0.12, 1.0)
	var stoff := StandardMaterial3D.new()
	stoff.albedo_texture = load("res://assets/texturen/ffm/holz.png")
	stoff.albedo_color = Color(0.72, 0.62, 0.52)
	stoff.uv1_triplanar = true
	stoff.uv1_scale = Vector3.ONE * 0.7
	stoff.roughness = 0.75
	form.material = stoff
	bild.mesh = form
	tisch.add_child(bild)
	add_child(tisch)
	tisch.global_position = TISCH - Vector3(0, 0.06, 0)
	for x in [-1.45, 1.45]:
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

	_zuruf = Label.new()
	_zuruf.add_theme_font_size_override("font_size", 22)
	_zuruf.add_theme_color_override("font_color", Color(0.98, 0.86, 0.55))
	_zuruf.add_theme_constant_override("outline_size", 6)
	_zuruf.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_zuruf.anchor_left = 0.5
	_zuruf.anchor_right = 0.5
	_zuruf.offset_left = -260.0
	_zuruf.offset_right = 260.0
	_zuruf.offset_top = 62.0
	_zuruf.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zuruf.modulate.a = 0.0
	_hud.add_child(_zuruf)

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
	# Kenney-Metallklang (CC0) — klingt nach echtem Krug statt Sinus-Klirren.
	_klirrklang.stream = load("res://audio/kenney/krug_klirren.ogg")
	_klirrklang.max_polyphony = 6
	_klirrklang.unit_size = 6.0
	add_child(_klirrklang)
	_klirrklang.global_position = TISCH
	_siegklang = AudioStreamPlayer.new()
	_siegklang.stream = load("res://audio/kenney/sieg_fanfare.ogg")
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
			"Alle Bembel vom Tisch — du hast %d Bälle! Taste halten, im grünen Bereich loslassen." % WURF_VORRAT)
		await get_tree().create_timer(intro_dauer).timeout
		_banner.visible = false
	zustand = Zustand.ZIELEN


func _banner_zeigen(titel: String, zeile: String) -> void:
	_banner_titel.text = titel
	_banner_zeile.text = zeile
	_banner.visible = true


## Zählt die erledigten Krüge. Erledigt ist ein Krug, wenn er **umliegt**,
## vom Tisch gefallen ist oder weit verschoben wurde — und er bleibt es
## dann auch (`gefallen` wird eingerastet).
##
## Die erste Fassung zählte nur die Verschiebung. Damit galt ein Turm, der
## in sich zusammenfiel und flach auf dem Tisch liegen blieb, als
## unangetastet: der Wurf sah gut aus und der Zähler sprang nicht. Auf dem
## Jahrmarkt zählt genau das Gegenteil — was liegt, ist gewonnen.
func gefallen_zaehler() -> int:
	var zahl := 0
	for eintrag in _kruege:
		if eintrag["gefallen"]:
			zahl += 1
			continue
		var krug: RigidBody3D = eintrag["node"]
		var weg: float = krug.global_position.distance_to(eintrag["start"])
		# Der Krug steht aufrecht, solange seine eigene Y-Achse nach oben
		# zeigt; unter 0,72 (gut 44°) kippt er.
		var aufrecht := krug.global_transform.basis.y.dot(Vector3.UP)
		if weg > GEFALLEN_WEG \
				or krug.global_position.y < TISCH.y - 0.12 \
				or aufrecht < 0.72:
			eintrag["gefallen"] = true
			zahl += 1
	return zahl


func _stand_anzeigen() -> void:
	_stand_label.text = "KRÜGE %d / %d   ·   BÄLLE %d" % [
		gefallen_zaehler(), _kruege.size(), WURF_VORRAT - wuerfe]


func _process(delta: float) -> void:
	_pause = maxf(_pause - delta, 0.0)
	_kamera_stossen(delta)
	_treffer_beobachten()
	match zustand:
		Zustand.ZIELEN:
			_zielen(delta)
			if Input.is_action_pressed(&"wurf") and _pause <= 0.0 \
					and wuerfe < WURF_VORRAT:
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
	# Bälle aufgebraucht und noch nicht alles unten: kurz warten, bis die
	# Physik ausgerollt ist (Nachzügler kippen noch), dann freundlich neu.
	elif zustand == Zustand.ZIELEN and wuerfe >= WURF_VORRAT \
			and _pause <= 0.0 and not _neustart_laeuft:
		_neustart_laeuft = true
		_neue_runde()


## Der Kamerastoß beim Einschlag. Er klingt exponentiell aus und rührt
## nur an der Position, nie an der Blickrichtung — eine verdrehte Kamera
## macht das Zielen unmöglich, ein verschobene nur lebendig.
func _kamera_stossen(delta: float) -> void:
	if kamera == null:
		return
	if _kamera_ruhe == Vector3.ZERO:
		_kamera_ruhe = kamera.position
	if _stoss <= 0.0001:
		kamera.position = _kamera_ruhe
		return
	_stoss = maxf(_stoss - delta * 0.42, 0.0)
	kamera.position = _kamera_ruhe + Vector3(
		randf_range(-_stoss, _stoss),
		randf_range(-_stoss, _stoss),
		randf_range(-_stoss, _stoss) * 0.4)


## Zählt neue Treffer und lässt Oliver etwas dazu sagen. Ein Begleiter,
## der bei einem umgeworfenen Turm stumm daneben steht, ist schlimmer
## als kein Begleiter.
func _treffer_beobachten() -> void:
	var jetzt := gefallen_zaehler()
	if jetzt == _gefallen_zuletzt:
		return
	var neu := jetzt - _gefallen_zuletzt
	_gefallen_zuletzt = jetzt
	if neu <= 0:
		return
	var rest := _kruege.size() - jetzt
	if rest == 0:
		return                      # den Sieg kommentiert die Sequenz
	elif rest == 1:
		_zuruf_zeigen("Einer noch!")
	elif neu >= 3:
		_zuruf_zeigen(["Alles weg!", "Der ganze Turm!"].pick_random())
	elif neu == 2:
		_zuruf_zeigen(["Doppelt.", "Zwei auf einmal."].pick_random())
	else:
		_zuruf_zeigen(["Sitzt.", "Guter Wurf.", "Weiter so."].pick_random())


## Ein Zuruf blendet über der Anzeige auf und wieder weg. Bewusst **nicht**
## die Dialogbox: die hält das Spiel an und würde jeden Treffer zu einer
## Unterbrechung machen.
func _zuruf_zeigen(text: String) -> void:
	if _zuruf == null:
		return
	_zuruf.text = "OLIVER:  " + text
	if _zuruf_tween != null and _zuruf_tween.is_valid():
		_zuruf_tween.kill()
	_zuruf.modulate.a = 0.0
	_zuruf_tween = create_tween()
	_zuruf_tween.tween_property(_zuruf, ^"modulate:a", 1.0, 0.18)
	_zuruf_tween.tween_interval(1.5)
	_zuruf_tween.tween_property(_zuruf, ^"modulate:a", 0.0, 0.6)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_maus += (event as InputEventMouseMotion).relative


func ziel_punkt() -> Vector3:
	return TISCH + Vector3(_ziel.x, 0.45 + _ziel.y, 0.0)


## Ein Ziel, das sicher einen Turm trifft: Mitte des ersten Turms, Höhe
## der unteren Reihe. Das Fadenkreuz startet hier, und der Prüflauf wirft
## darauf.
##
## Es ist gerechnet, nicht eingetippt: die Türme sind seit dem Feinschliff
## zweimal gewandert (weniger Türme, größere Krüge), und beide Male zeigte
## eine festgeschriebene Zielmarke danach in die Lücke oder über den Stapel
## hinweg.
func zielvorschlag() -> Vector2:
	if _kruege.is_empty():
		return Vector2.ZERO
	var mitte := 0.0
	var unterste := 1.0e9
	var anzahl := 0
	for eintrag in _kruege:
		var ort: Vector3 = eintrag["start"]
		unterste = minf(unterste, ort.y)
	for eintrag in _kruege:
		var ort: Vector3 = eintrag["start"]
		# Nur die unterste Reihe des ersten Turms zählt für die Mitte.
		if absf(ort.y - unterste) > 0.01 or ort.x > TISCH.x:
			continue
		mitte += ort.x
		anzahl += 1
	if anzahl == 0:
		return Vector2.ZERO
	mitte /= float(anzahl)
	# Auf halber Krughöhe der unteren Reihe: dort trägt der Treffer den
	# ganzen Stapel mit.
	var hoehe := unterste + 0.13 * KRUG_GROESSE
	return Vector2(mitte - TISCH.x, hoehe - (TISCH.y + 0.45))


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
	if wuerfe >= WURF_VORRAT:
		# Der letzte Ball: länger warten, bis Flug und Kettenreaktion
		# ausgerollt sind, bevor der Neustart entscheidet.
		_pause = wurf_pause + 2.4
	_wischklang.play()

	var ball := RigidBody3D.new()
	ball.mass = 0.95
	# Klein und schnell: ohne Dauerprüfung tunnelt die Kugel durch Krugwände,
	# und die Vorgabe-Dämpfung ließe den Wurf vor dem Tisch absacken.
	ball.continuous_cd = true
	ball.linear_damp = 0.0
	var form := CollisionShape3D.new()
	var kugel := SphereShape3D.new()
	kugel.radius = 0.055
	form.shape = kugel
	ball.add_child(form)
	ball.add_child(_BALL.instantiate())
	_baelle.add_child(ball)
	ball.global_position = WURF_PUNKT
	ball.linear_velocity = _wurfgeschwindigkeit(ziel_punkt(), _kraft)
	# Vorwärtsdrall: an den Nähten des Balls sieht man ihn rollen, und der
	# Drall lässt ihn nach dem Einschlag über den Tisch weiterlaufen.
	ball.angular_velocity = Vector3(-14.0, 0.0, 0.0)
	# Das Abwurftempo mitgeben: `body_entered` wird erst nach der aufgelösten
	# Kollision ausgeliefert, dort steht in `linear_velocity` nur noch der
	# Rest (gemessen: 6,6 statt 19). Wer daraus die Wucht rechnet, bekommt
	# ein Zehntel des Stoßes, den der Treffer verdient.
	ball.set_meta("abwurf", ball.linear_velocity.length())
	ball.contact_monitor = true
	ball.max_contacts_reported = 4
	ball.body_entered.connect(_auf_ball_treffer.bind(ball))
	get_tree().create_timer(5.0).timeout.connect(func() -> void:
		if is_instance_valid(ball):
			ball.queue_free())


## Der Ball hat etwas berührt. Hier hängt die gesamte Trefferrückmeldung:
## Klang mit gestreuter Tonhöhe, Staubwolke, Kamerastoß.
##
## Ein Treffer ohne Rückmeldung fühlt sich an wie ein Fehler im Spiel —
## das Auge glaubt der Physik erst, wenn Ton und Bild mitgehen.
func _auf_ball_treffer(koerper: Node, ball: RigidBody3D) -> void:
	if not is_instance_valid(ball):
		return
	# Beim ersten Aufprall zählt das Abwurftempo, danach der Rest.
	var wucht := ball.linear_velocity.length()
	if not ball.get_meta("verbraucht", false):
		wucht = maxf(wucht, float(ball.get_meta("abwurf", 0.0)))
		ball.set_meta("verbraucht", true)
	if wucht < 1.2:
		return
	_klirren(ball.global_position, wucht)
	if koerper is RigidBody3D:
		_staub(ball.global_position)
		_stoss = minf(_stoss + wucht * 0.0016, 0.09)
		_kettenreaktion(ball.global_position, wucht)


## Der Nachschub für die Physik: ein kleiner Stoß auf alle Krüge nah am
## Einschlag.
##
## **Warum das nötig ist.** Gemessen: ein Ball mit 19 m/s schlägt den
## getroffenen Krug 1,4 m weit aus dem Stapel — und rührt die Nachbarn um
## keine zwei Zentimeter an. Die Etagen darüber verlieren ihre Auflage,
## fallen 32 cm senkrecht herunter und stehen dann **aufrecht** auf dem
## Tisch. Das ist für starre Zylinder völlig richtig gerechnet und als
## Spiel unbrauchbar: man müsste jeden der zwölf Krüge einzeln treffen.
##
## Also hilft das Spiel der Physik nachweislich nach. Der Stoß geht vom
## Einschlagpunkt weg und greift **über** dem Schwerpunkt an — dadurch
## entsteht ein Drehmoment, die Krüge kippen statt zu rutschen. Nichts
## davon ist sichtbar; sichtbar ist nur, dass ein guter Treffer einen Turm
## räumt, wie er das auf dem Jahrmarkt auch tut.
func _kettenreaktion(ort: Vector3, wucht: float) -> void:
	# Mit 0.58/0.16 räumte ein mittiger Treffer fast immer den ganzen Turm —
	# zusammen mit unbegrenzten Bällen war das Spiel nicht zu verlieren.
	# Seit dem Ballbudget ist die Hilfe enger gefasst: nahe Nachbarn kippen
	# noch mit, aber ein Turm verlangt wieder einen sauberen Treffer.
	const REICHWEITE := 0.48
	for eintrag in _kruege:
		if eintrag["gefallen"]:
			continue
		var krug: RigidBody3D = eintrag["node"]
		var richtung := krug.global_position - ort
		var abstand := richtung.length()
		if abstand > REICHWEITE or abstand < 0.0001:
			continue
		var anteil := 1.0 - abstand / REICHWEITE
		# Waagerecht weg vom Einschlag, mit einem Hauch nach oben.
		var stoss := (richtung.normalized() * 0.9 + Vector3.UP * 0.25) \
			* wucht * anteil * 0.12
		krug.sleeping = false
		krug.apply_impulse(stoss, Vector3(0.0, 0.20 * KRUG_GROESSE, 0.0))


## Klirren mit gestreuter Tonhöhe. Immer derselbe Ton bei jedem Treffer
## ist das zweite, was künstlich klingt (das erste ist kein Ton).
func _klirren(ort: Vector3, wucht: float) -> void:
	_klirrklang.global_position = ort
	_klirrklang.pitch_scale = randf_range(0.86, 1.18)
	_klirrklang.volume_db = lerpf(-12.0, 1.0, clampf(wucht / 14.0, 0.0, 1.0))
	_klirrklang.play()


## Eine kurze Staubwolke am Einschlagpunkt — Steinzeug auf Holz staubt.
func _staub(ort: Vector3) -> void:
	var wolke := GPUParticles3D.new()
	var stoff := ParticleProcessMaterial.new()
	stoff.direction = Vector3(0, 1, 0)
	stoff.spread = 70.0
	stoff.initial_velocity_min = 0.4
	stoff.initial_velocity_max = 1.6
	stoff.gravity = Vector3(0, -1.2, 0)
	stoff.scale_min = 0.4
	stoff.scale_max = 1.1
	stoff.color = Color(0.86, 0.82, 0.72, 0.55)
	wolke.process_material = stoff
	var korn := QuadMesh.new()
	korn.size = Vector2(0.035, 0.035)
	var korn_stoff := StandardMaterial3D.new()
	korn_stoff.albedo_color = Color(0.88, 0.84, 0.74, 0.5)
	korn_stoff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	korn_stoff.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	korn_stoff.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	korn.material = korn_stoff
	wolke.draw_pass_1 = korn
	wolke.amount = 14
	wolke.lifetime = 0.7
	wolke.one_shot = true
	wolke.explosiveness = 0.9
	add_child(wolke)
	wolke.global_position = ort
	wolke.emitting = true
	get_tree().create_timer(1.4).timeout.connect(func() -> void:
		if is_instance_valid(wolke):
			wolke.queue_free())


func _wurfgeschwindigkeit(ziel: Vector3, kraft: float) -> Vector3:
	var strecke := ziel - WURF_PUNKT
	var flugzeit := maxf(strecke.length() / maxf(wurf_tempo, 0.1), 0.05)
	var schwerkraft: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)
	var geschwindigkeit := strecke / flugzeit
	geschwindigkeit.y += 0.5 * schwerkraft * flugzeit
	return geschwindigkeit * (1.0 + (kraft - 0.5) * 2.0 * kraft_einfluss)


## Alle Bälle geworfen, aber es stehen noch Krüge: Türme zurückstellen,
## neue Bälle. Freundlich wie beim Brautstrauß — kein Scheitern, nur
## nochmal. Läuft nebenläufig; gewinnt der letzte Ball währenddessen
## doch noch, bricht der Zustandswechsel auf SIEG den Neustart ab.
func _neue_runde() -> void:
	_banner_zeigen("ALLE BÄLLE GEWORFEN",
		"Macht nichts — die Türme stehen wieder auf. Neue Runde, %d Bälle!"
		% WURF_VORRAT)
	await get_tree().create_timer(2.2).timeout
	if zustand != Zustand.ZIELEN:
		_neustart_laeuft = false
		return
	for eintrag in _kruege:
		var krug: RigidBody3D = eintrag["node"]
		krug.freeze = true
		krug.linear_velocity = Vector3.ZERO
		krug.angular_velocity = Vector3.ZERO
		krug.global_position = eintrag["start"]
		krug.rotation = Vector3(0.0, eintrag["drehung"], 0.0)
		eintrag["gefallen"] = false
	await get_tree().physics_frame
	for eintrag in _kruege:
		(eintrag["node"] as RigidBody3D).freeze = false
	wuerfe = 0
	_gefallen_zuletzt = 0
	_banner.visible = false
	_neustart_laeuft = false


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
