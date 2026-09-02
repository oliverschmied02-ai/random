extends Node3D

## Die Tinder-Intro — wie alles anfing.
##
## Eine Nahaufnahme: Annes Hand mit dem Handy, abends, Bokeh-Lichter im
## Hintergrund. Auf dem Bildschirm läuft eine Dating-App („zünder"). Drei
## Profile will niemand — die wischt man nach links. Dann kommt Oliver.
## Anne denkt laut nach (die Zeilen stehen in `dialogue_lines.gd`), man
## blättert durch seine drei Fotos — auf jedem sieht er anders aus — und
## wischt nach rechts. Match. Dann beginnt Kapitel 1.
##
## Aufbau: das Handy ist ein Blender-Modell (`assets/intro/hand_handy.glb`),
## sein Bildschirm zeigt eine SubViewport-Textur, in der die ganze App als
## Control-Baum lebt. Gewischt wird mit Maus-Ziehen oder Pfeiltasten; der
## Daumen auf dem Glas wischt sichtbar mit. Esc überspringt die Intro.
##
## Für den headless Prüflauf ist die Logik von der Animation getrennt:
## `wische()`, `naechstes_foto()` und `gedanke_weiter()` schalten sofort,
## die Tweens sind reine Kosmetik.

const KAPITEL := "res://chapters/berlin/berlin_chapter.tscn"

const SCHIRM_BREITE := 540
const SCHIRM_HOEHE := 1170
const WISCH_SCHWELLE := 150.0

enum Zustand { WISCHEN, GEDANKEN, MATCH, ENDE }

## Für den Prüflauf: kein Szenenwechsel nach dem Match.
var test_kein_wechsel := false
var match_erreicht := false

var _zustand: int = Zustand.WISCHEN
var _index := 0                # 0..2 Scherz-Profile, 3 = Oliver
var _foto := 0                 # aktuelles Oliver-Foto
var _gedanke := -1             # -1 = noch nicht begonnen
var _zieht := false
var _zug := 0.0                # aktueller Kartenversatz in Schirm-Pixeln
var _karte_gesperrt := false   # solange eine Karte fliegt oder federt
var _zeit := 0.0

var _schirm: SubViewport
var _karte: Control
var _foto_feld: TextureRect
var _name_feld: Label
var _bio_feld: Label
var _punkte: HBoxContainer
var _stempel_nein: Label
var _stempel_ja: Label
var _match_schicht: Control
var _hand: Node3D
var _schirm_flaeche: MeshInstance3D
var _knopf_x: Control
var _knopf_herz: Control
var _daumen: Node3D
var _daumen_ruhe: Vector3
# Bei der echten Hand ist der Daumen Teil des Netzes — dann schnipst beim
# Wischen die ganze Hand (additiv auf die Atembewegung in _process).
var _hand_schnipser := 0.0
var _schirmlicht: OmniLight3D
var _gedanken_feld: RichTextLabel
var _hinweis: Label
var _schwarz: ColorRect
var _ton_wisch: AudioStreamPlayer
var _ton_zurueck: AudioStreamPlayer
var _ton_tipp: AudioStreamPlayer
var _ton_match: AudioStreamPlayer


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_umgebung_bauen()
	_hand_bauen()
	_schirm_bauen()
	_oberflaeche_bauen()
	_toene_bauen()
	_karte_fuellen()
	_einblenden()


# --- Szene ------------------------------------------------------------------


func _umgebung_bauen() -> void:
	var welt := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.028, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.22, 0.3)
	env.ambient_light_energy = 0.5
	welt.environment = env
	add_child(welt)

	var kamera := Camera3D.new()
	kamera.fov = 39.0
	add_child(kamera)
	kamera.position = Vector3(0.0, 0.015, 0.335)
	kamera.look_at(Vector3(0.0, -0.004, 0.0))
	kamera.make_current()

	# Warmes Zimmerlicht von oben links — mit Schatten, der erdet die Finger.
	var lampe := OmniLight3D.new()
	lampe.light_color = Color(1.0, 0.82, 0.6)
	lampe.light_energy = 0.5
	lampe.omni_range = 1.2
	# Kein Echtzeit-Schatten: die grobe Shadow-Map zeichnet harte Kanten
	# („Risse") auf Arm und Knöchel — die gebackene AO der Hand erdet schon.
	add_child(lampe)
	lampe.position = Vector3(-0.28, 0.3, 0.22)
	var rest := OmniLight3D.new()
	rest.light_color = Color(0.5, 0.6, 0.9)
	rest.light_energy = 0.2
	rest.omni_range = 1.5
	add_child(rest)
	rest.position = Vector3(0.35, 0.1, 0.15)

	# Das Leuchten des Bildschirms auf Daumen und Fingern.
	_schirmlicht = OmniLight3D.new()
	_schirmlicht.light_color = Color(0.75, 0.8, 1.0)
	_schirmlicht.light_energy = 0.3
	_schirmlicht.omni_range = 0.26
	add_child(_schirmlicht)
	_schirmlicht.position = Vector3(0.0, 0.0, 0.09)

	_bokeh_streuen()


func _bokeh_streuen() -> void:
	var bild: Texture2D = load("res://assets/intro/bokeh.png")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1408  # der Tag, an dem das Geschenk fällig ist
	var toene := [
		Color(1.0, 0.62, 0.28), Color(1.0, 0.78, 0.42), Color(0.95, 0.5, 0.3),
		Color(0.4, 0.7, 0.9), Color(0.9, 0.85, 0.6),
	]
	for i in 16:
		var fleck := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var mass := rng.randf_range(0.08, 0.42)
		quad.size = Vector2(mass, mass)
		fleck.mesh = quad
		var stoff := StandardMaterial3D.new()
		stoff.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		stoff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		stoff.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		stoff.albedo_texture = bild
		var ton: Color = toene[rng.randi() % toene.size()]
		stoff.albedo_color = Color(ton.r, ton.g, ton.b, rng.randf_range(0.10, 0.30))
		fleck.material_override = stoff
		add_child(fleck)
		fleck.position = Vector3(
			rng.randf_range(-1.1, 1.1),
			rng.randf_range(-0.55, 0.75),
			rng.randf_range(-2.4, -0.9)
		)
	add_child(fleck_licht())


func fleck_licht() -> Node3D:
	# Eine angedeutete Fensterkante weit hinten, kaum sichtbar.
	var kante := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 1.4)
	kante.mesh = quad
	var stoff := StandardMaterial3D.new()
	stoff.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stoff.albedo_color = Color(0.045, 0.05, 0.075)
	kante.material_override = stoff
	kante.position = Vector3(0.85, 0.15, -2.8)
	return kante


func _hand_bauen() -> void:
	_hand = Node3D.new()
	_hand.name = "Hand"
	add_child(_hand)
	# Leicht zurückgelehnt, wie man ein Handy eben hält.
	_hand.rotation_degrees = Vector3(-11.0, 0.0, 3.0)

	var modell: Node3D = (load("res://assets/intro/hand_handy.glb") as PackedScene).instantiate()
	_hand.add_child(modell)
	_daumen = modell.find_child("daumen", true, false)
	if _daumen != null:
		_daumen_ruhe = _daumen.position


func _schirm_bauen() -> void:
	_schirm = SubViewport.new()
	_schirm.size = Vector2i(SCHIRM_BREITE, SCHIRM_HOEHE)
	_schirm.disable_3d = true
	_schirm.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_schirm)

	# Die Bildfläche des Modells bekommt die Viewport-Textur — unbeleuchtet,
	# damit sie unabhängig vom Zimmerlicht lesbar bleibt, und mit
	# abgerundeten Ecken wie ein echtes Display.
	_schirm_flaeche = _hand.find_child("bildschirm", true, false) as MeshInstance3D
	var schatten := Shader.new()
	schatten.code = """
shader_type spatial;
render_mode unshaded;
uniform sampler2D bild : source_color;
void fragment() {
	vec2 mass = vec2(540.0, 1170.0);
	vec2 p = UV * mass;
	vec2 ecke = vec2(46.0);
	vec2 q = min(p, mass - p);
	if (q.x < ecke.x && q.y < ecke.y && length(q - ecke) > ecke.x) { discard; }
	ALBEDO = texture(bild, UV).rgb;
}
"""
	var stoff := ShaderMaterial.new()
	stoff.shader = schatten
	stoff.set_shader_parameter("bild", _schirm.get_texture())
	if _schirm_flaeche != null:
		_schirm_flaeche.set_surface_override_material(0, stoff)


# --- Die App auf dem Bildschirm ----------------------------------------------


func _oberflaeche_bauen() -> void:
	var grund := ColorRect.new()
	grund.color = Color(0.05, 0.05, 0.075)
	grund.set_anchors_preset(Control.PRESET_FULL_RECT)
	_schirm.add_child(grund)

	# Statuszeile.
	var netz := _beschriftung("o2-de", 22, Color(0.65, 0.65, 0.7))
	netz.position = Vector2(24, 12)
	grund.add_child(netz)
	var uhr := _beschriftung("23:12", 22, Color(0.85, 0.85, 0.9))
	uhr.position = Vector2(SCHIRM_BREITE / 2.0 - 30, 12)
	grund.add_child(uhr)
	grund.add_child(_batterie(Vector2(SCHIRM_BREITE - 76, 16)))

	# Kopfzeile mit Flamme und Wortmarke.
	var flamme := Polygon2D.new()
	flamme.polygon = PackedVector2Array([
		Vector2(0, 26), Vector2(9, 4), Vector2(14, 16), Vector2(20, 0),
		Vector2(30, 22), Vector2(24, 38), Vector2(6, 38),
	])
	flamme.color = Color(1.0, 0.42, 0.2)
	flamme.position = Vector2(178, 54)
	grund.add_child(flamme)
	var marke := _beschriftung("zünder", 42, Color(1.0, 0.42, 0.2))
	marke.position = Vector2(220, 44)
	grund.add_child(marke)

	# Kartenbereich.
	var halter := Control.new()
	halter.position = Vector2(22, 122)
	halter.size = Vector2(SCHIRM_BREITE - 44, 872)
	grund.add_child(halter)

	_karte = PanelContainer.new()
	var rahmen := StyleBoxFlat.new()
	rahmen.bg_color = Color(0.11, 0.11, 0.14)
	rahmen.set_corner_radius_all(26)
	_karte.add_theme_stylebox_override("panel", rahmen)
	_karte.size = halter.size
	_karte.pivot_offset = Vector2(halter.size.x / 2.0, halter.size.y)
	halter.add_child(_karte)

	var innen := Control.new()
	innen.clip_contents = true
	_karte.add_child(innen)

	_foto_feld = TextureRect.new()
	_foto_feld.position = Vector2(8, 8)
	_foto_feld.size = Vector2(halter.size.x - 16, 640)
	_foto_feld.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_foto_feld.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_foto_feld.clip_contents = true
	innen.add_child(_foto_feld)

	# Dunkler Verlauf unter dem Foto, damit der Name lesbar bleibt.
	var verlauf := TextureRect.new()
	var farben := GradientTexture2D.new()
	farben.gradient = Gradient.new()
	farben.gradient.set_color(0, Color(0, 0, 0, 0))
	farben.gradient.set_color(1, Color(0, 0, 0, 0.75))
	farben.fill_from = Vector2(0.5, 0.0)
	farben.fill_to = Vector2(0.5, 1.0)
	verlauf.texture = farben
	verlauf.position = Vector2(8, 448)
	verlauf.size = Vector2(halter.size.x - 16, 200)
	verlauf.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	innen.add_child(verlauf)

	_name_feld = _beschriftung("", 44, Color.WHITE)
	_name_feld.position = Vector2(28, 580)
	innen.add_child(_name_feld)

	_bio_feld = _beschriftung("", 26, Color(0.78, 0.78, 0.84))
	_bio_feld.position = Vector2(28, 668)
	_bio_feld.size = Vector2(halter.size.x - 56, 130)
	_bio_feld.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	innen.add_child(_bio_feld)

	# Foto-Punkte (nur bei Oliver sichtbar).
	_punkte = HBoxContainer.new()
	_punkte.position = Vector2(halter.size.x / 2.0 - 42, 20)
	_punkte.add_theme_constant_override("separation", 12)
	innen.add_child(_punkte)

	_stempel_nein = _stempel("NEE", Color(0.95, 0.3, 0.3), 12.0)
	_stempel_nein.position = Vector2(halter.size.x - 190, 44)
	innen.add_child(_stempel_nein)
	_stempel_ja = _stempel("GEFÄLLT MIR", Color(0.3, 0.85, 0.45), -12.0)
	_stempel_ja.position = Vector2(30, 44)
	innen.add_child(_stempel_ja)

	# Knopfreihe unter der Karte — klickbar: der Tipp wird über die
	# Bildschirmebene zurückgerechnet (_tippen).
	_knopf_x = _rundknopf(Vector2(140, 1035), Color(0.95, 0.35, 0.35), false)
	grund.add_child(_knopf_x)
	_knopf_herz = _rundknopf(Vector2(400, 1035), Color(0.3, 0.85, 0.45), true)
	grund.add_child(_knopf_herz)

	_match_bauen(grund)


func _beschriftung(text: String, groesse: int, farbe: Color) -> Label:
	var feld := Label.new()
	feld.text = text
	feld.add_theme_font_size_override("font_size", groesse)
	feld.add_theme_color_override("font_color", farbe)
	return feld


func _batterie(ort: Vector2) -> Control:
	var halter := Control.new()
	halter.position = ort
	var huelle := Panel.new()
	var rand := StyleBoxFlat.new()
	rand.bg_color = Color(0, 0, 0, 0)
	rand.border_color = Color(0.7, 0.7, 0.75)
	rand.set_border_width_all(2)
	rand.set_corner_radius_all(4)
	huelle.add_theme_stylebox_override("panel", rand)
	huelle.size = Vector2(42, 20)
	halter.add_child(huelle)
	var stand := ColorRect.new()
	stand.color = Color(0.7, 0.7, 0.75)
	stand.position = Vector2(4, 4)
	stand.size = Vector2(13, 12)  # 31 % — es ist spät.
	halter.add_child(stand)
	var pol := ColorRect.new()
	pol.color = Color(0.7, 0.7, 0.75)
	pol.position = Vector2(44, 6)
	pol.size = Vector2(4, 8)
	halter.add_child(pol)
	return halter


func _stempel(text: String, farbe: Color, neigung: float) -> Label:
	var feld := _beschriftung(text, 40, farbe)
	var rand := StyleBoxFlat.new()
	rand.bg_color = Color(0, 0, 0, 0.15)
	rand.border_color = farbe
	rand.set_border_width_all(5)
	rand.set_corner_radius_all(10)
	rand.content_margin_left = 14
	rand.content_margin_right = 14
	rand.content_margin_top = 2
	rand.content_margin_bottom = 2
	feld.add_theme_stylebox_override("normal", rand)
	feld.rotation_degrees = neigung
	feld.modulate.a = 0.0
	return feld


func _rundknopf(mitte: Vector2, farbe: Color, herz: bool) -> Control:
	var halter := Control.new()
	halter.position = mitte
	var kreis := Panel.new()
	var form := StyleBoxFlat.new()
	form.bg_color = Color(0.09, 0.09, 0.12)
	form.border_color = farbe
	form.set_border_width_all(4)
	form.set_corner_radius_all(48)
	kreis.add_theme_stylebox_override("panel", form)
	kreis.size = Vector2(96, 96)
	kreis.position = Vector2(-48, -48)
	halter.add_child(kreis)
	if herz:
		var form2 := Polygon2D.new()
		form2.polygon = _herz_punkte(30.0)
		form2.color = farbe
		halter.add_child(form2)
	else:
		for winkel in [45.0, -45.0]:
			var strich := ColorRect.new()
			strich.color = farbe
			strich.size = Vector2(52, 9)
			strich.position = Vector2(-26, -4.5)
			strich.pivot_offset = strich.size / 2.0
			strich.rotation_degrees = winkel
			halter.add_child(strich)
	return halter


func _herz_punkte(mass: float) -> PackedVector2Array:
	var punkte := PackedVector2Array()
	for i in 24:
		var t := TAU * i / 24.0
		# Die klassische Herzkurve, y zeigt nach unten.
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		punkte.append(Vector2(x, y) * mass / 16.0)
	return punkte


func _match_bauen(grund: Control) -> void:
	_match_schicht = Control.new()
	_match_schicht.set_anchors_preset(Control.PRESET_FULL_RECT)
	_match_schicht.visible = false
	grund.add_child(_match_schicht)

	var folie := ColorRect.new()
	folie.color = Color(0.03, 0.02, 0.05, 0.96)
	folie.set_anchors_preset(Control.PRESET_FULL_RECT)
	_match_schicht.add_child(folie)

	var gruss := _beschriftung("Es ist ein Match!", 52, Color(1.0, 0.42, 0.2))
	gruss.position = Vector2(0, 300)
	gruss.size = Vector2(SCHIRM_BREITE, 80)
	gruss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_match_schicht.add_child(gruss)

	for daten in [
		["res://assets/intro/anne_match.jpg", Vector2(88, 470)],
		["res://assets/intro/oliver_foto_1.jpg", Vector2(292, 470)],
	]:
		var ring := Panel.new()
		var form := StyleBoxFlat.new()
		form.bg_color = Color(1, 1, 1, 0.9)
		form.set_corner_radius_all(88)
		ring.add_theme_stylebox_override("panel", form)
		ring.position = daten[1] as Vector2 - Vector2(6, 6)
		ring.size = Vector2(172, 172)
		_match_schicht.add_child(ring)
		var kopf := TextureRect.new()
		var foto: Texture2D = load(daten[0] as String)
		if foto.get_height() > foto.get_width():
			# Hochkant-Fotos oben quadratisch beschneiden, sonst verzerrt es.
			var quadrat := AtlasTexture.new()
			quadrat.atlas = foto
			quadrat.region = Rect2(0, 0, foto.get_width(), foto.get_width())
			foto = quadrat
		# Erst expand_mode, dann size — sonst klemmt die Textur-Mindestgröße
		# (640 px) die Zuweisung auf ihren eigenen Wert fest.
		kopf.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# STRETCH_SCALE füllt exakt die 160 px — COVERED malt über den Rand
		# hinaus, weil clip_contents nur Kinder beschneidet.
		kopf.stretch_mode = TextureRect.STRETCH_SCALE
		kopf.texture = foto
		kopf.position = daten[1]
		kopf.size = Vector2(160, 160)
		kopf.material = _kreis_maske()
		_match_schicht.add_child(kopf)

	var zeile := _beschriftung("Ihr habt euch geliked.", 26, Color(0.8, 0.8, 0.86))
	zeile.position = Vector2(0, 700)
	zeile.size = Vector2(SCHIRM_BREITE, 40)
	zeile.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_match_schicht.add_child(zeile)


func _kreis_maske() -> ShaderMaterial:
	var schatten := Shader.new()
	schatten.code = """
shader_type canvas_item;
void fragment() {
	vec2 p = UV - vec2(0.5);
	if (length(p) > 0.5) { discard; }
	COLOR = texture(TEXTURE, UV);
}
"""
	var stoff := ShaderMaterial.new()
	stoff.shader = schatten
	return stoff


func _toene_bauen() -> void:
	# Kenney-Aufnahmen (CC0, siehe audio/kenney/HERKUNFT.txt): echtes
	# Kartenwischen statt synthetischem Rauschen.
	_ton_wisch = _ton("res://audio/kenney/karte_wisch.ogg", -4.0)
	_ton_zurueck = _ton("res://audio/kenney/karte_zurueck.ogg", -7.0)
	_ton_tipp = _ton("res://audio/kenney/tipp.ogg", -8.0)
	_ton_match = _ton("res://audio/kenney/match.ogg", -3.0)
	# Die echte Stadtaufnahme (ferne Sirenen, ruhige Straße) — gedämpft,
	# als läge sie hinter Annes Fenster.
	var stadt := _ton("res://audio/stadt_ambiente.mp3", -20.0)
	stadt.play()

	var laeufer := AudioStreamPlayer.new()
	laeufer.stream = load("res://audio/titelmusik.wav")
	laeufer.volume_db = -18.0
	laeufer.bus = &"Musik" if AudioServer.get_bus_index("Musik") >= 0 else &"Master"
	add_child(laeufer)
	laeufer.play()


func _ton(pfad: String, pegel: float) -> AudioStreamPlayer:
	var spieler := AudioStreamPlayer.new()
	spieler.stream = load(pfad)
	spieler.volume_db = pegel
	add_child(spieler)
	return spieler


# --- Überblendungen und Gedanken ---------------------------------------------


func _einblenden() -> void:
	var schicht := CanvasLayer.new()
	schicht.layer = 10
	add_child(schicht)

	_schwarz = ColorRect.new()
	_schwarz.color = Color(0, 0, 0, 1)
	_schwarz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_schwarz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	schicht.add_child(_schwarz)
	create_tween().tween_property(_schwarz, ^"color:a", 0.0, 1.4)

	_gedanken_feld = RichTextLabel.new()
	_gedanken_feld.bbcode_enabled = true
	_gedanken_feld.scroll_active = false
	_gedanken_feld.anchor_left = 0.5
	_gedanken_feld.anchor_right = 0.5
	_gedanken_feld.anchor_top = 1.0
	_gedanken_feld.anchor_bottom = 1.0
	_gedanken_feld.offset_left = -430.0
	_gedanken_feld.offset_right = 430.0
	_gedanken_feld.offset_top = -170.0
	_gedanken_feld.offset_bottom = -60.0
	_gedanken_feld.add_theme_font_size_override("normal_font_size", 30)
	_gedanken_feld.add_theme_font_size_override("italics_font_size", 30)
	_gedanken_feld.mouse_filter = Control.MOUSE_FILTER_IGNORE
	schicht.add_child(_gedanken_feld)

	_hinweis = Label.new()
	_hinweis.text = "Ziehen, ←/→ oder die Knöpfe  ·  Esc überspringt"
	_hinweis.add_theme_font_size_override("font_size", 20)
	_hinweis.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	_hinweis.anchor_left = 0.5
	_hinweis.anchor_right = 0.5
	_hinweis.anchor_top = 1.0
	_hinweis.anchor_bottom = 1.0
	_hinweis.offset_left = -300.0
	_hinweis.offset_right = 300.0
	_hinweis.offset_top = -46.0
	_hinweis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	schicht.add_child(_hinweis)


func _gedanke_zeigen(text: String) -> void:
	_gedanken_feld.text = "[center][i][color=#f2ead9]„%s“[/color][/i][/center]" % text
	_gedanken_feld.modulate.a = 0.0
	create_tween().tween_property(_gedanken_feld, ^"modulate:a", 1.0, 0.35)


func _gedanke_loeschen() -> void:
	_gedanken_feld.text = ""


# --- Kartenlogik (vom Prüflauf direkt aufrufbar) ------------------------------


func karten_index() -> int:
	return _index


func foto_index() -> int:
	return _foto


func zustand() -> int:
	return _zustand


func _profil(index: int) -> Dictionary:
	if index < BerlinDialogue.INTRO_PROFILE.size():
		return BerlinDialogue.INTRO_PROFILE[index]
	return BerlinDialogue.INTRO_OLIVER


func _karte_fuellen() -> void:
	var profil := _profil(_index)
	_name_feld.text = "%s, %d" % [profil["name"], profil["alter"]]
	_bio_feld.text = profil["bio"]
	_foto = 0
	for kind in _punkte.get_children():
		kind.queue_free()
	if profil.has("bilder"):
		_foto_feld.texture = load((profil["bilder"] as Array)[0] as String)
		for i in (profil["bilder"] as Array).size():
			var punkt := Panel.new()
			var form := StyleBoxFlat.new()
			form.bg_color = Color(1, 1, 1, 0.95 if i == 0 else 0.35)
			form.set_corner_radius_all(6)
			punkt.add_theme_stylebox_override("panel", form)
			punkt.custom_minimum_size = Vector2(12, 12)
			_punkte.add_child(punkt)
	else:
		_foto_feld.texture = load(profil["bild"] as String)


## Wischt die liegende Karte. Scherz-Profile lassen sich nur nach links
## wischen, Oliver nur nach rechts — die falsche Richtung federt zurück
## und Anne kommentiert. Gibt zurück, ob die Karte tatsächlich flog.
func wische(nach_rechts: bool) -> bool:
	if _zustand != Zustand.WISCHEN or _karte_gesperrt:
		return false
	var oliver := _index >= BerlinDialogue.INTRO_PROFILE.size()
	if nach_rechts != oliver:
		# Falsche Richtung — Scherz-Profile nach rechts, Oliver nach links.
		_abfedern(_profil(_index)["abwink"] as String)
		return false
	if oliver:
		# Erst beim Like meldet sich Annes Kopf zu Wort — das Match kommt,
		# wenn der letzte Gedanke gedacht ist. Vorher darf man in Ruhe
		# durch die Fotos blättern.
		_gedanken_starten()
	else:
		_wegfliegen(false)
	return true


func _wegfliegen(nach_rechts: bool) -> void:
	_karte_gesperrt = true
	_hinweis.visible = false
	_ton_wisch.play()
	_gedanke_loeschen()
	var ziel := (600.0 if nach_rechts else -600.0)
	var flug := create_tween().set_parallel(true)
	flug.tween_property(_karte, ^"position:x", ziel, 0.28)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flug.tween_property(_karte, ^"rotation_degrees", 18.0 * signf(ziel), 0.28)
	flug.tween_property(_karte, ^"modulate:a", 0.0, 0.28)
	_daumen_wischen(nach_rechts)
	await flug.finished
	_index += 1
	_zug = 0.0
	_karte_fuellen()
	_karte.position.x = 0.0
	_karte.rotation_degrees = 0.0
	_karte.scale = Vector2(0.92, 0.92)
	_karte.modulate.a = 0.0
	_stempel_dimmen()
	var auftritt := create_tween().set_parallel(true)
	auftritt.tween_property(_karte, ^"scale", Vector2.ONE, 0.22)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	auftritt.tween_property(_karte, ^"modulate:a", 1.0, 0.18)
	await auftritt.finished
	_karte_gesperrt = false
	if _index >= BerlinDialogue.INTRO_PROFILE.size():
		_hinweis.text = "Tipp aufs Foto: nächstes Bild  ·  Herz-Knopf: gefällt mir"
		_hinweis.visible = true


func _abfedern(spruch: String) -> void:
	_karte_gesperrt = true
	_ton_zurueck.play()
	var feder := create_tween()
	feder.tween_property(_karte, ^"position:x", _karte.position.x * 0.4, 0.1)
	feder.tween_property(_karte, ^"position:x", 0.0, 0.3)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	feder.parallel().tween_property(_karte, ^"rotation_degrees", 0.0, 0.2)
	_gedanke_zeigen(spruch)
	feder.finished.connect(func() -> void:
		_zug = 0.0
		_stempel_dimmen()
		_karte_gesperrt = false)


func naechstes_foto() -> void:
	var profil := _profil(_index)
	if _zustand != Zustand.WISCHEN or not profil.has("bilder"):
		return
	var bilder: Array = profil["bilder"]
	_foto = (_foto + 1) % bilder.size()
	_foto_feld.texture = load(bilder[_foto] as String)
	_ton_tipp.play()
	for i in _punkte.get_child_count():
		var form: StyleBoxFlat = (_punkte.get_child(i) as Panel)\
			.get_theme_stylebox("panel")
		form.bg_color = Color(1, 1, 1, 0.95 if i == _foto else 0.35)


func _gedanken_starten() -> void:
	_zustand = Zustand.GEDANKEN
	_gedanke = 0
	_gedanke_zeigen(BerlinDialogue.INTRO_GEDANKEN[0])
	_hinweis.text = "Klick für den nächsten Gedanken"
	_hinweis.visible = true


func gedanke_weiter() -> void:
	if _zustand != Zustand.GEDANKEN:
		return
	_gedanke += 1
	if _gedanke < BerlinDialogue.INTRO_GEDANKEN.size():
		_gedanke_zeigen(BerlinDialogue.INTRO_GEDANKEN[_gedanke])
		return
	_match_starten()


func _match_starten() -> void:
	_zustand = Zustand.MATCH
	match_erreicht = true
	_karte_gesperrt = true
	_gedanke_loeschen()
	_hinweis.visible = false
	_ton_match.play()
	_daumen_wischen(true)
	var flug := create_tween().set_parallel(true)
	flug.tween_property(_karte, ^"position:x", 600.0, 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flug.tween_property(_karte, ^"rotation_degrees", 18.0, 0.3)
	await flug.finished
	_match_schicht.visible = true
	_match_schicht.modulate.a = 0.0
	create_tween().tween_property(_match_schicht, ^"modulate:a", 1.0, 0.5)
	if test_kein_wechsel:
		return
	await get_tree().create_timer(3.2).timeout
	_beenden()


func _beenden() -> void:
	if _zustand == Zustand.ENDE:
		return
	_zustand = Zustand.ENDE
	var blende := create_tween()
	blende.tween_property(_schwarz, ^"color:a", 1.0, 1.0)
	await blende.finished
	get_tree().change_scene_to_file(KAPITEL)


# --- Eingabe und Animation ----------------------------------------------------


func _unhandled_input(ereignis: InputEvent) -> void:
	if _zustand == Zustand.ENDE:
		return
	if ereignis is InputEventKey and ereignis.pressed and not ereignis.echo:
		match ereignis.keycode:
			KEY_ESCAPE:
				_beenden()
			KEY_LEFT, KEY_A:
				if _zustand == Zustand.WISCHEN:
					wische(false)
			KEY_RIGHT, KEY_D:
				if _zustand == Zustand.WISCHEN:
					wische(true)
			KEY_SPACE, KEY_UP, KEY_E:
				if _zustand == Zustand.GEDANKEN:
					gedanke_weiter()
				else:
					naechstes_foto()
			KEY_ENTER:
				if _zustand == Zustand.GEDANKEN:
					gedanke_weiter()
		return

	if ereignis is InputEventMouseButton and ereignis.button_index == MOUSE_BUTTON_LEFT:
		if _zustand == Zustand.GEDANKEN:
			if ereignis.pressed:
				gedanke_weiter()
			return
		if _zustand != Zustand.WISCHEN or _karte_gesperrt:
			return
		if ereignis.pressed:
			_zieht = true
		else:
			if not _zieht:
				return
			_zieht = false
			if absf(_zug) > WISCH_SCHWELLE:
				wische(_zug > 0.0)
				if _zustand == Zustand.WISCHEN and _karte_gesperrt == false:
					_zug_zuruecksetzen()
			elif absf(_zug) < 8.0:
				_tippen(ereignis.position)
				_zug_zuruecksetzen()
			else:
				_zug_zuruecksetzen()
		return

	if ereignis is InputEventMouseMotion and _zieht and not _karte_gesperrt:
		_zug += ereignis.relative.x * 0.55
		_zug = clampf(_zug, -420.0, 420.0)


## Rechnet einen Fensterpunkt auf die Bildschirmebene des Handys zurück:
## Kamerastrahl, Ebenenschnitt, lokale Quad-Koordinaten → Viewport-Pixel.
## Liegt der Punkt nicht auf dem Display, kommt (-1, -1) zurück.
func _schirm_punkt(fenster: Vector2) -> Vector2:
	if _schirm_flaeche == null:
		return Vector2(-1, -1)
	var kamera := get_viewport().get_camera_3d()
	if kamera == null:
		return Vector2(-1, -1)
	var von := kamera.project_ray_origin(fenster)
	var richtung := kamera.project_ray_normal(fenster)
	var lage := _schirm_flaeche.global_transform
	var normale := lage.basis.z.normalized()
	var nenner := normale.dot(richtung)
	if absf(nenner) < 0.0001:
		return Vector2(-1, -1)
	var t := (normale.dot(lage.origin) - normale.dot(von)) / nenner
	if t < 0.0:
		return Vector2(-1, -1)
	var lokal := lage.affine_inverse() * (von + richtung * t)
	# Die Bildfläche ist 0,066 × 0,140 m groß, Mitte im Ursprung.
	var u := (lokal.x + 0.033) / 0.066
	var v := (0.070 - lokal.y) / 0.140
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return Vector2(-1, -1)
	return Vector2(u * SCHIRM_BREITE, v * SCHIRM_HOEHE)


func _tippen(fenster: Vector2) -> void:
	var punkt := _schirm_punkt(fenster)
	if punkt.x < 0.0:
		return
	tippe_auf_schirm(punkt)


## Tipp in Viewport-Koordinaten der App (auch vom Prüflauf aufrufbar):
## ✕ lehnt ab, das Herz liket, ein Tipp aufs Foto blättert.
func tippe_auf_schirm(punkt: Vector2) -> void:
	if _zustand != Zustand.WISCHEN:
		return
	if punkt.distance_to(Vector2(140, 1035)) < 62.0:
		_knopf_druecken(_knopf_x, false)
	elif punkt.distance_to(Vector2(400, 1035)) < 62.0:
		_knopf_druecken(_knopf_herz, true)
	elif punkt.y < 810.0:
		naechstes_foto()


func _knopf_druecken(knopf: Control, herz: bool) -> void:
	var druck := create_tween()
	druck.tween_property(knopf, ^"scale", Vector2(1.25, 1.25), 0.09)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	druck.tween_property(knopf, ^"scale", Vector2.ONE, 0.16)
	wische(herz)


func _zug_zuruecksetzen() -> void:
	_zug = 0.0
	if _karte_gesperrt:
		return
	var feder := create_tween()
	feder.tween_property(_karte, ^"position:x", 0.0, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	feder.parallel().tween_property(_karte, ^"rotation_degrees", 0.0, 0.25)
	_stempel_dimmen()


func _stempel_dimmen() -> void:
	_stempel_nein.modulate.a = 0.0
	_stempel_ja.modulate.a = 0.0


func _daumen_wischen(nach_rechts: bool) -> void:
	if _daumen == null:
		# Ganze Hand schnipst kurz in Wischrichtung.
		var ziel := 4.0 if nach_rechts else -4.0
		var schnipser := create_tween()
		schnipser.tween_property(self, ^"_hand_schnipser", ziel, 0.14)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		schnipser.tween_property(self, ^"_hand_schnipser", 0.0, 0.45)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return
	var weg := Vector3(0.022 if nach_rechts else -0.022, 0.0, 0.004)
	var schwung := create_tween()
	schwung.tween_property(_daumen, ^"position", _daumen_ruhe + weg, 0.16)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	schwung.tween_property(_daumen, ^"position", _daumen_ruhe, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	_zeit += delta
	# Atmen: die Hand schwankt kaum sichtbar.
	if _hand != null:
		_hand.position.y = sin(_zeit * 1.4) * 0.0015
		_hand.rotation_degrees.z = 3.0 + sin(_zeit * 0.9) * 0.6
		_hand.rotation_degrees.x = -11.0 + sin(_zeit * 1.1) * 0.4
		_hand.rotation_degrees.y = _hand_schnipser
	# Das Bildschirmlicht flackert minimal, wie Bildwechsel eben leuchten.
	if _schirmlicht != null:
		_schirmlicht.light_energy = 0.3 + sin(_zeit * 7.3) * 0.02

	# Karte folgt dem Finger, solange gezogen wird.
	if _zieht and not _karte_gesperrt and _zustand == Zustand.WISCHEN:
		_karte.position.x = _zug
		_karte.rotation_degrees = _zug * 0.03
		var staerke := clampf((absf(_zug) - 30.0) / WISCH_SCHWELLE, 0.0, 1.0)
		_stempel_ja.modulate.a = staerke if _zug > 0.0 else 0.0
		_stempel_nein.modulate.a = staerke if _zug < 0.0 else 0.0
		if _daumen != null:
			_daumen.position = _daumen_ruhe + Vector3(_zug * 0.00004, 0.0, 0.001)
