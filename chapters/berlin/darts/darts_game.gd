class_name DartsGame
extends Node3D

## Vaccination Darts — das Minispiel an der Dönerbude.
##
## Ablauf eines Wurfs: zielen, Maustaste halten, im grünen Bereich loslassen.
##
## Zwei Entscheidungen prägen das Spielgefühl:
##
## 1. Das Fadenkreuz bewegt sich in der **Ebene der Scheibe**, nicht über den
##    Bildschirm. Dadurch ist die Zielhilfe unabhängig von Auflösung und
##    Bildwinkel, und ein Treffer sieht genau da aus, wo man hingezielt hat.
##
## 2. Die Wurfkraft wirkt nur auf die **Höhe** des Einschlags, nie auf die
##    Seite. Das ist kein Zufall der Formel, sondern folgt daraus, dass die
##    ganze Anfangsgeschwindigkeit skaliert wird: waagerechter Weg und
##    Flugzeit ändern sich gegenläufig und heben sich auf. Wer daneben zielt,
##    trifft daneben; wer schlecht lädt, trifft zu hoch oder zu tief. Zwei
##    getrennte, verständliche Fehlerquellen statt einer diffusen.

signal runde_geschafft(punkte: int)

enum Zustand { INAKTIV, ZIELEN, LADEN, FLUG, RUNDENENDE }

@export_group("Zielen")
## Wie weit sich das Fadenkreuz von der Scheibenmitte entfernen lässt (Meter).
@export_range(0.2, 1.5, 0.05) var ziel_grenze: float = 0.45
## Meter Fadenkreuz-Weg pro Mauspixel.
@export_range(0.0002, 0.005, 0.0001) var maus_empfindlichkeit: float = 0.0011
## Meter pro Sekunde bei voll ausgelenktem Gamepad-Stick.
@export_range(0.1, 2.0, 0.05) var gamepad_zielgeschwindigkeit: float = 0.55

@export_group("Wurf")
## Grundgeschwindigkeit der Spritze in m/s. Höher heißt flachere Flugbahn und
## damit auch geringere Wirkung von Ladefehlern.
@export_range(5.0, 25.0, 0.5) var wurf_tempo: float = 13.0
## Sekunden für einen vollen Durchlauf des Kraftbalkens.
@export_range(0.4, 3.0, 0.1) var ladezeit: float = 1.1
## Wie stark ein Ladefehler die Geschwindigkeit verändert. 0,09 heißt: ganz
## daneben geladen verschiebt den Treffer um etwa 9 cm nach oben oder unten.
@export_range(0.0, 0.4, 0.01) var kraft_einfluss: float = 0.09
## Halbe Breite der grünen Zone um die Mitte des Balkens.
@export_range(0.02, 0.4, 0.01) var idealzone: float = 0.15

@export_group("Rückmeldung")
@export_range(0.0, 1.0, 0.01) var kamera_wackeln: float = 0.12
@export_range(0.2, 3.0, 0.1) var pause_nach_wurf: float = 0.9
@export_range(0.5, 6.0, 0.1) var pause_nach_runde: float = 2.4
## Sekunden für die Kamerafahrt von der Spielkamera auf die Scheibe.
@export_range(0.0, 4.0, 0.1) var kamerafahrt: float = 1.3

const _SYRINGE := preload("res://chapters/berlin/darts/syringe.tscn")

@onready var kamera: Camera3D = $Kamera
@onready var spieler_platz: Marker3D = $Plaetze/Spielerin
@onready var oliver_platz: Marker3D = $Plaetze/Oliver
@onready var _mitte: Marker3D = $Scheibe/Mitte
@onready var _wurf_punkt: Marker3D = $WurfPunkt
@onready var _treffer: Node3D = $Treffer
@onready var _einschlag: CPUParticles3D = $Einschlag
@onready var _konfetti: CPUParticles3D = $Konfetti
@onready var _hud = $DartsHud
@onready var _einschlagklang: AudioStreamPlayer3D = $Einschlagklang
@onready var _ladeklang: AudioStreamPlayer = $Ladeklang
@onready var _trefferklang: AudioStreamPlayer = $Trefferklang
@onready var _gewonnenklang: AudioStreamPlayer = $Gewonnenklang

var zustand: Zustand = Zustand.INAKTIV
var punkte: int = 0
var wurf_nummer: int = 1

var _ziel: Vector2 = Vector2.ZERO
var _kraft: float = 0.0
var _kraft_steigt: bool = true
var _maus_bewegung: Vector2 = Vector2.ZERO
var _kamera_ruhe: Transform3D
var _fahrt_start: Transform3D
var _wackeln: float = 0.0


func _ready() -> void:
	# Das Minispiel steht von Anfang an in der Szene, seine Anzeige darf aber
	# erst mit ihm auftauchen — sonst liegen Wurfzähler und Punktestand schon
	# während des Spaziergangs über dem Bild.
	_hud.visible = false
	_hud.setze_idealzone(0.5 - idealzone, 0.5 + idealzone)
	# Die Ruhelage der Kamera einmal ausrechnen; die Fahrt blendet dorthin.
	kamera.look_at_from_position(kamera.global_position, _mitte.global_position, Vector3.UP)
	_kamera_ruhe = kamera.global_transform
	set_process(false)
	set_process_unhandled_input(false)


## Startet das Minispiel. `von_kamera` ist die Kamera, von der aus die Fahrt
## beginnt — normalerweise die Verfolgerkamera der Spielerin.
func starten(von_kamera: Camera3D = null) -> void:
	_neue_runde()
	_hud.visible = true
	_hud.verstecke_banner()
	set_process(true)
	set_process_unhandled_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_fahrt_start = von_kamera.global_transform if von_kamera != null else _kamera_ruhe
	kamera.global_transform = _fahrt_start
	kamera.current = true

	if kamerafahrt > 0.0:
		var fahrt := create_tween()
		fahrt.tween_method(_kamera_blenden, 0.0, 1.0, kamerafahrt) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		fahrt.tween_callback(func() -> void: zustand = Zustand.ZIELEN)
	else:
		zustand = Zustand.ZIELEN


## Blendet von der festgehaltenen Startlage zur Ruhelage. Von der jeweils
## aktuellen Lage aus zu interpolieren sähe aus wie ein Bremsvorgang, nicht wie
## eine geführte Fahrt.
func _kamera_blenden(anteil: float) -> void:
	kamera.global_transform = _fahrt_start.interpolate_with(_kamera_ruhe, anteil)


func _process(delta: float) -> void:
	_kamera_wackeln_anwenden(delta)

	match zustand:
		Zustand.ZIELEN:
			_zielen(delta)
			if Input.is_action_pressed(&"wurf"):
				zustand = Zustand.LADEN
				_kraft = 0.0
				_kraft_steigt = true
		Zustand.LADEN:
			_zielen(delta)
			_laden(delta)
			if not Input.is_action_pressed(&"wurf"):
				_werfen()
		_:
			_hud.setze_kraft(0.0, false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_maus_bewegung += (event as InputEventMouseMotion).relative


## Bewegt das Fadenkreuz in der Ebene der Scheibe.
func _zielen(delta: float) -> void:
	_ziel.x += _maus_bewegung.x * maus_empfindlichkeit
	_ziel.y -= _maus_bewegung.y * maus_empfindlichkeit
	_maus_bewegung = Vector2.ZERO

	var stick := Vector2(
		Input.get_axis(&"look_left", &"look_right"),
		Input.get_axis(&"look_down", &"look_up")
	)
	_ziel += stick * gamepad_zielgeschwindigkeit * delta
	_ziel = _ziel.limit_length(ziel_grenze)

	_hud.setze_fadenkreuz(kamera.unproject_position(ziel_punkt()), true)


func _laden(delta: float) -> void:
	var schritt := delta / maxf(ladezeit, 0.01)
	_kraft += schritt if _kraft_steigt else -schritt
	if _kraft >= 1.0:
		_kraft = 1.0
		_kraft_steigt = false
	elif _kraft <= 0.0:
		_kraft = 0.0
		_kraft_steigt = true
	_hud.setze_kraft(_kraft, true)

	# Der Ladeton steigt mit dem Balken. Damit hört man den Ladestand, statt ihn
	# nur zu sehen — beim Zielen schaut man ohnehin auf die Scheibe.
	if not _ladeklang.playing:
		_ladeklang.play()
	_ladeklang.pitch_scale = 0.8 + _kraft * 0.7


## Übergibt die Szene an den Abschluss: Anzeige weg, Eingaben aus, Kamera frei.
##
## Vor allem das Kamerawackeln muss enden — es schreibt jeden Frame die Position
## der Kamera neu und würde jede Fahrt, die das Kapitel danach fährt, überschreiben.
func abschluss_uebernehmen() -> void:
	zustand = Zustand.INAKTIV
	_wackeln = 0.0
	_ladeklang.stop()
	set_process(false)
	set_process_unhandled_input(false)
	_hud.visible = false


## Weltposition, auf die das Fadenkreuz zeigt.
func ziel_punkt() -> Vector3:
	return _mitte.global_position + Vector3(_ziel.x, _ziel.y, 0.0)


func _werfen() -> void:
	zustand = Zustand.FLUG
	_ladeklang.stop()
	_hud.setze_kraft(0.0, false)
	_hud.setze_fadenkreuz(Vector2.ZERO, false)

	var spritze: Syringe = _SYRINGE.instantiate()
	_treffer.add_child(spritze)
	spritze.global_position = _wurf_punkt.global_position
	spritze.eingeschlagen.connect(_auf_einschlag)
	spritze.werfen(
		_wurfgeschwindigkeit(ziel_punkt(), _kraft),
		_mitte.global_position.z,
		_mitte.global_position
	)


## Anfangsgeschwindigkeit für einen Wurf auf `ziel` mit Ladestand `kraft`.
##
## Bei kraft = 0,5 trifft die Spritze genau ins Ziel: die Formel löst den
## schrägen Wurf für eine feste Flugzeit. Abweichungen skalieren den ganzen
## Vektor — waagerecht bleibt der Treffer dadurch gleich, senkrecht wandert er.
func _wurfgeschwindigkeit(ziel: Vector3, kraft: float) -> Vector3:
	var start := _wurf_punkt.global_position
	var strecke := ziel - start
	var flugzeit := maxf(strecke.length() / maxf(wurf_tempo, 0.1), 0.05)
	var schwerkraft: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)

	var geschwindigkeit := strecke / flugzeit
	geschwindigkeit.y += 0.5 * schwerkraft * flugzeit
	return geschwindigkeit * (1.0 + (kraft - 0.5) * 2.0 * kraft_einfluss)


func _auf_einschlag(treffer_punkte: int, ort: Vector3, _radius: float) -> void:
	punkte += treffer_punkte
	_hud.setze_punkte(punkte, DartsConfig.ZIELPUNKTZAHL)
	_hud.zeige_trefferpunkte(
		DartsConfig.treffer_text(treffer_punkte),
		kamera.unproject_position(ort) - Vector2(30, 40),
		treffer_punkte >= DartsConfig.GUTER_TREFFER
	)

	_einschlag.global_position = ort
	_einschlag.restart()
	_wackeln = kamera_wackeln * (1.6 if treffer_punkte >= DartsConfig.GUTER_TREFFER else 0.7)

	_einschlagklang.global_position = ort
	# Näher an der Mitte klingt der Treffer heller — dieselbe Aufnahme, nur
	# höher abgespielt. Billiger Trick, aber man hört sofort, ob es gut war.
	_einschlagklang.pitch_scale = 1.0 + 0.2 * (float(treffer_punkte) / 50.0)
	_einschlagklang.play()
	if treffer_punkte >= DartsConfig.GUTER_TREFFER:
		_trefferklang.play()

	await get_tree().create_timer(pause_nach_wurf).timeout

	if wurf_nummer >= DartsConfig.WUERFE_PRO_RUNDE:
		_runde_beenden()
		return
	wurf_nummer += 1
	_hud.setze_wurf(wurf_nummer, DartsConfig.WUERFE_PRO_RUNDE)
	zustand = Zustand.ZIELEN


func _runde_beenden() -> void:
	zustand = Zustand.RUNDENENDE
	_hud.setze_fadenkreuz(Vector2.ZERO, false)

	if punkte >= DartsConfig.ZIELPUNKTZAHL:
		_konfetti.restart()
		_gewonnenklang.play()
		_hud.zeige_banner(
			"GESCHAFFT",
			"%d Punkte. Oliver ist beeindruckt und wird es nie zugeben." % punkte
		)
		runde_geschafft.emit(punkte)
		return

	# Scheitern bleibt leicht: kurze freundliche Zeile, sofort neue Runde.
	_hud.zeige_banner(
		"Fast — noch eine Runde?",
		"%d von %d Punkten." % [punkte, DartsConfig.ZIELPUNKTZAHL]
	)
	await get_tree().create_timer(pause_nach_runde).timeout
	_hud.verstecke_banner()
	_neue_runde()
	zustand = Zustand.ZIELEN


func _neue_runde() -> void:
	punkte = 0
	wurf_nummer = 1
	_ziel = Vector2.ZERO
	for spritze in _treffer.get_children():
		spritze.queue_free()
	_hud.setze_wurf(wurf_nummer, DartsConfig.WUERFE_PRO_RUNDE)
	_hud.setze_punkte(punkte, DartsConfig.ZIELPUNKTZAHL)


func _kamera_wackeln_anwenden(delta: float) -> void:
	if _wackeln <= 0.0:
		return
	_wackeln = maxf(_wackeln - delta * 0.9, 0.0)
	var versatz := Vector3(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)
	) * _wackeln * 0.1
	kamera.global_position = _kamera_ruhe.origin + versatz
