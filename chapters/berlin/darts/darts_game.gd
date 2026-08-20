class_name DartsGame
extends Node3D

## Vaccination Darts — das Minispiel an der Dönerbude.
##
## **Zehn FFP2-Masken fallen, fünf Treffer gewinnen.** Eine Dartscheibe gibt
## es nicht mehr — geworfen wird mit Impfspritzen auf die fallenden Masken,
## Spritzen sind unbegrenzt (der Vorrat auf der Tonne füllt sich nach).
## Sind alle zehn Masken unten oder abgeworfen und fehlen noch Treffer,
## beginnt freundlich eine neue Runde.
##
## Ablauf eines Wurfs: zielen, Maustaste halten, im grünen Bereich loslassen.
##
## Zwei Entscheidungen prägen das Spielgefühl:
##
## 1. Das Fadenkreuz bewegt sich in der **Ebene der Fallzone**, nicht über den
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
## Groß genug für die fallenden Masken links und rechts der Scheibe.
@export_range(0.2, 2.0, 0.05) var ziel_grenze: float = 1.5
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
## Sekunden für die Einblendung „Impfspritzen werfen" vor der ersten Runde.
@export_range(0.0, 6.0, 0.1) var intro_dauer: float = 2.6

@export_group("Masken")
## Sekunden zwischen zwei fallenden Masken.
@export_range(0.8, 6.0, 0.1) var masken_takt: float = 2.1
## Fallgeschwindigkeit der Masken (m/s) — Papier fällt gemächlich.
@export_range(0.3, 3.0, 0.05) var masken_fall: float = 1.05
## Höhe, in der die Masken erscheinen.
@export_range(2.0, 6.0, 0.1) var masken_hoehe: float = 3.1
## Wie weit links und rechts der Scheibenmitte Masken fallen.
@export_range(0.4, 2.0, 0.05) var masken_breite: float = 1.1
## Für Prüfläufe abschaltbar — dann fallen nur von Hand gesetzte Masken.
@export var masken_spawn_aktiv: bool = true

const _SYRINGE := preload("res://chapters/berlin/darts/syringe.tscn")
const _MASKE := preload("res://assets/props/atemmaske.glb")

@onready var kamera: Camera3D = $Kamera
@onready var spieler_platz: Marker3D = $Plaetze/Spielerin
@onready var oliver_platz: Marker3D = $Plaetze/Oliver
@onready var _mitte: Marker3D = $Scheibe/Mitte
@onready var _wurf_punkt: Marker3D = $WurfPunkt
@onready var _treffer: Node3D = $Treffer
@onready var _vorrat: Node3D = $Vorrat
@onready var _einschlag: CPUParticles3D = $Einschlag
@onready var _konfetti: CPUParticles3D = $Konfetti
@onready var _hud = $DartsHud
@onready var _einschlagklang: AudioStreamPlayer3D = $Einschlagklang
@onready var _ladeklang: AudioStreamPlayer = $Ladeklang
@onready var _trefferklang: AudioStreamPlayer = $Trefferklang
@onready var _gewonnenklang: AudioStreamPlayer = $Gewonnenklang

var zustand: Zustand = Zustand.INAKTIV
var punkte: int = 0
## Wie viele Masken diese Runde schon erschienen sind (höchstens
## MASKEN_PRO_RUNDE) und wie viele davon erledigt sind (getroffen oder
## unten angekommen). Sind alle erledigt, endet die Runde.
var masken_erschienen: int = 0
var masken_erledigt: int = 0

var _ziel: Vector2 = Vector2.ZERO
var _kraft: float = 0.0
var _kraft_steigt: bool = true
var _maus_bewegung: Vector2 = Vector2.ZERO
var _kamera_ruhe: Transform3D
var _fahrt_start: Transform3D
var _wackeln: float = 0.0
var _masken: Array = []
var _masken_wurzel: Node3D
var _masken_uhr: float = 0.0
var _masken_zufall := RandomNumberGenerator.new()


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
	# Die Spritzen liegen schon beim Ankommen auf der Tonne bereit — der
	# Vorrat gehört zum Schauplatz, nicht erst zum gestarteten Spiel.
	_vorrat_fuellen()
	_masken_wurzel = Node3D.new()
	add_child(_masken_wurzel)
	_masken_zufall.seed = 2020


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
		fahrt.tween_callback(_intro_zeigen)
	else:
		_intro_zeigen()


## Blendet von der festgehaltenen Startlage zur Ruhelage. Von der jeweils
## aktuellen Lage aus zu interpolieren sähe aus wie ein Bremsvorgang, nicht wie
## eine geführte Fahrt.
func _kamera_blenden(anteil: float) -> void:
	kamera.global_transform = _fahrt_start.interpolate_with(_kamera_ruhe, anteil)


## Kurze Einblendung, was hier gleich passiert — danach beginnt das Zielen.
func _intro_zeigen() -> void:
	if intro_dauer <= 0.0:
		zustand = Zustand.ZIELEN
		return
	_hud.zeige_banner(
		"IMPFSPRITZEN WERFEN",
		"%d Masken fallen — triff %d! Taste halten, im grünen Bereich loslassen. Spritzen gibt es genug."
			% [DartsConfig.MASKEN_PRO_RUNDE, DartsConfig.TREFFER_ZIEL]
	)
	await get_tree().create_timer(intro_dauer).timeout
	_hud.verstecke_banner()
	zustand = Zustand.ZIELEN


# --- Die fallenden Masken ---------------------------------------------------


## Lässt in regelmäßigen, leicht verzitterten Abständen Masken fallen und
## bewegt sie: gemächlich abwärts, seitlich pendelnd wie Papier, mit
## leichtem Trudeln. Unten angekommen zählt die Maske als verpasst; sind
## alle zehn erledigt und die Treffer reichen nicht, endet die Runde.
func _masken_pflegen(delta: float) -> void:
	var laeuft := zustand in [Zustand.ZIELEN, Zustand.LADEN, Zustand.FLUG]
	if laeuft and masken_spawn_aktiv \
			and masken_erschienen < DartsConfig.MASKEN_PRO_RUNDE:
		_masken_uhr -= delta
		if _masken_uhr <= 0.0:
			_masken_uhr = masken_takt * _masken_zufall.randf_range(0.75, 1.3)
			var seitlich := _masken_zufall.randf_range(-masken_breite, masken_breite)
			maske_setzen(
				_mitte.global_position + Vector3(seitlich, masken_hoehe - _mitte.global_position.y, 0.0),
				masken_fall * _masken_zufall.randf_range(0.85, 1.2))
			masken_erschienen += 1
			_hud.setze_wurf(
				DartsConfig.MASKEN_PRO_RUNDE - masken_erledigt,
				DartsConfig.MASKEN_PRO_RUNDE)

	for eintrag in _masken.duplicate():
		var teil: Node3D = eintrag["node"]
		eintrag["zeit"] += delta
		var ort: Vector3 = eintrag["heim"]
		ort.y -= eintrag["tempo"] * eintrag["zeit"]
		ort.x += 0.22 * sin(eintrag["zeit"] * 1.7 + eintrag["phase"])
		teil.global_position = ort
		teil.rotation = Vector3(
			0.35 * sin(eintrag["zeit"] * 2.3 + eintrag["phase"]),
			eintrag["zeit"] * 0.8,
			0.3 * sin(eintrag["zeit"] * 1.9))
		if ort.y < 0.3:
			_maske_entfernen(eintrag)
			_maske_erledigt()

	# Rundenende erst, wenn wirklich alle zehn durch sind und nichts mehr
	# fliegt — ein spätes Sieg-Ende übernimmt _auf_einschlag selbst.
	if laeuft and masken_spawn_aktiv \
			and masken_erledigt >= DartsConfig.MASKEN_PRO_RUNDE \
			and zustand != Zustand.FLUG:
		_runde_beenden()


## Eine Maske ist vom Tisch — getroffen oder unten angekommen.
func _maske_erledigt() -> void:
	masken_erledigt += 1
	_hud.setze_wurf(
		maxi(DartsConfig.MASKEN_PRO_RUNDE - masken_erledigt, 0),
		DartsConfig.MASKEN_PRO_RUNDE)


## Setzt eine Maske an eine Weltposition — vom Spawner und von Prüfläufen
## benutzt (`tempo` 0 hält sie für deterministische Würfe fest).
func maske_setzen(ort: Vector3, tempo: float = 0.0) -> void:
	var teil := _MASKE.instantiate() as Node3D
	# Das FFP2-Körbchen ist 13 cm breit — hochskaliert auf knapp einen
	# halben Meter, damit das fallende Ziel zur Trefferzone passt.
	teil.scale = Vector3.ONE * 3.6
	_masken_wurzel.add_child(teil)
	teil.global_position = ort
	_masken.append({
		"node": teil, "heim": ort, "tempo": tempo, "zeit": 0.0,
		"phase": _masken_zufall.randf() * TAU,
	})


func _maske_entfernen(eintrag: Dictionary) -> void:
	_masken.erase(eintrag)
	eintrag["node"].queue_free()


func masken_anzahl() -> int:
	return _masken.size()


## Trifft der Einschlag `ort` eine Maske? Dann fällt sie und es gibt Punkte.
func _maske_punkte(ort: Vector3) -> int:
	for eintrag in _masken:
		var teil: Node3D = eintrag["node"]
		if teil.global_position.distance_to(ort) <= DartsConfig.MASKEN_RADIUS:
			_einschlag.global_position = teil.global_position
			_einschlag.restart()
			_maske_entfernen(eintrag)
			_maske_erledigt()
			return DartsConfig.MASKEN_PUNKTE
	return 0


func _process(delta: float) -> void:
	_kamera_wackeln_anwenden(delta)
	_masken_pflegen(delta)

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

	# Eine Spritze vom Vorrat auf der Tonne nehmen — die fliegt jetzt.
	# Ist die Tonne leer, legt Oliver nach: Spritzen sind unbegrenzt.
	if _vorrat.get_child_count() > 0:
		_vorrat.get_child(_vorrat.get_child_count() - 1).queue_free()
	if _vorrat.get_child_count() <= 1:
		_vorrat_fuellen()

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


func _auf_einschlag(_ring_punkte: int, ort: Vector3, _radius: float) -> void:
	# Gezählt werden abgeworfene Masken, nicht die Ringe der alten Scheibe —
	# die hängt nur noch als Zielwand dahinter.
	var treffer_punkte := _maske_punkte(ort)
	punkte += treffer_punkte
	_hud.setze_punkte(punkte / DartsConfig.MASKEN_PUNKTE, DartsConfig.TREFFER_ZIEL)
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

	# Gewonnen wird sofort mit dem fünften Treffer; verloren erst, wenn alle
	# Masken durch sind (das prüft _masken_pflegen). Ansonsten: weiterwerfen,
	# Spritzen gehen nicht aus.
	if punkte >= DartsConfig.ZIELPUNKTZAHL:
		_runde_beenden()
		return
	if zustand == Zustand.FLUG:
		zustand = Zustand.ZIELEN


func _runde_beenden() -> void:
	zustand = Zustand.RUNDENENDE
	_hud.setze_fadenkreuz(Vector2.ZERO, false)

	if punkte >= DartsConfig.ZIELPUNKTZAHL:
		_konfetti.restart()
		_gewonnenklang.play()
		_hud.zeige_banner(
			"GESCHAFFT",
			"%d Masken abgeworfen. Oliver ist beeindruckt und wird es nie zugeben."
				% DartsConfig.TREFFER_ZIEL
		)
		runde_geschafft.emit(punkte)
		return

	# Scheitern bleibt leicht: kurze freundliche Zeile, sofort neue Runde.
	_hud.zeige_banner(
		"Fast — noch eine Runde?",
		"%d von %d Masken getroffen. Es fallen gleich wieder %d."
			% [punkte / DartsConfig.MASKEN_PUNKTE, DartsConfig.TREFFER_ZIEL,
				DartsConfig.MASKEN_PRO_RUNDE]
	)
	await get_tree().create_timer(pause_nach_runde).timeout
	_hud.verstecke_banner()
	_neue_runde()
	zustand = Zustand.ZIELEN


func _neue_runde() -> void:
	punkte = 0
	masken_erschienen = 0
	masken_erledigt = 0
	_ziel = Vector2.ZERO
	for spritze in _treffer.get_children():
		spritze.queue_free()
	for eintrag in _masken.duplicate():
		_maske_entfernen(eintrag)
	_masken_uhr = 0.6
	_vorrat_fuellen()
	_hud.setze_wurf(DartsConfig.MASKEN_PRO_RUNDE, DartsConfig.MASKEN_PRO_RUNDE)
	_hud.setze_punkte(punkte / DartsConfig.MASKEN_PUNKTE, DartsConfig.TREFFER_ZIEL)


## Legt Spritzen auf die Stehtonne neben dem Wurfpunkt — leicht
## aufgefächert, wie hingelegt statt einsortiert. Reine Ausstattung, der
## Nachschub ist unbegrenzt.
func _vorrat_fuellen() -> void:
	for alt in _vorrat.get_children():
		alt.queue_free()
	for i in DartsConfig.VORRAT_SPRITZEN:
		var spritze := _SYRINGE.instantiate() as Node3D
		_vorrat.add_child(spritze)
		var mitte := i - (DartsConfig.VORRAT_SPRITZEN - 1) * 0.5
		spritze.position = Vector3(mitte * 0.075, 0.034, mitte * 0.03)
		spritze.rotation = Vector3(0.0, -PI * 0.5 + mitte * 0.14, 0.0)


func _kamera_wackeln_anwenden(delta: float) -> void:
	if _wackeln <= 0.0:
		return
	_wackeln = maxf(_wackeln - delta * 0.9, 0.0)
	var versatz := Vector3(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)
	) * _wackeln * 0.1
	kamera.global_position = _kamera_ruhe.origin + versatz
