class_name HochzeitChapter
extends Node3D

## Kapitel 3 — die Hochzeit an der Spree. Das **Finale** des Spiels.
##
## Ablauf:
##
##   Kapitelkarte → kurzer Dialog am Traubogen → spielbarer Weg zu den
##   Gästen → Regeln → Brautstrauß-Fangen (10 fliegen, 5 fangen) →
##   Sieg-Dialog → **Truhen-Finale** (Zahlenpad, Code 42, der Rucksack
##   schwebt heraus) → **Geschenkbildschirm** → Abspann → Titel.
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
@onready var _figur_anne: Figur = $Player/Visual
@onready var _figur_oliver: Figur = $Oliver/Visual
@onready var _kamera_rig: Node3D = $ThirdPersonCamera
@onready var _filmkamera: Camera3D = $Filmkamera
@onready var _dialogue: DialogueBox = $UI/DialogueBox
@onready var _objective = $UI/ObjectiveLabel
@onready var _karte = $UI/ChapterCard
@onready var _strauss: StraussSpiel = $StraussSpiel
@onready var _kulisse: Node3D = $Kulisse
@onready var _menge: AudioStreamPlayer = $Klang/Menge
@onready var _jubel: AudioStreamPlayer = $Klang/Jubel

## Die Kapitelmusik (Kanon in D), wird im Finale abgelöst.
var _musik: AudioStreamPlayer

var _bogen_erreicht := false
var _blendschicht: CanvasLayer
var _blende: ColorRect
## Das Truhen-Finale — entsteht erst nach dem Sieg; für Prüfläufe lesbar.
var truhe: TruhenFinale


const _KLEID := preload("res://assets/hochzeit/kleid.glb")
const _STRAUSS := preload("res://assets/props/strauss.glb")
const _BANK := preload("res://assets/props/bank.glb")


func _ready() -> void:
	_player.input_enabled = false
	_kleid_anziehen()
	_blendschicht_bauen()
	# Dialog-Regie wie in Berlin: wer spricht, nickt und gestikuliert;
	# während des Gesprächs sehen die beiden einander an.
	_dialogue.zeile_begonnen.connect(_auf_sprechzeile)
	_dialogue.finished.connect(func() -> void: _figur_anne.schaue_an(null))
	# Bewusst KEIN Dauer-Ambiente in diesem Kapitel: sowohl die alte
	# Wellen-Möwen-Schleife als auch der synthetische Menge-/Stadt-Teppich
	# lasen sich als Meeresrauschen unter der Musik. Hier trägt allein
	# Olivers Lied; übrig bleiben nur Momentklänge (Jubel, Fanfare).
	# Kapitelmusik: der Kanon in D (Klavier, CC0) — DAS Hochzeitsstück.
	_musik = AudioStreamPlayer.new()
	_musik.stream = load("res://audio/musik/hochzeit.ogg")
	_musik.volume_db = -13.0
	_musik.bus = &"Musik" if AudioServer.get_bus_index("Musik") >= 0 else &"Master"
	add_child(_musik)
	_musik.play()
	var zone := $Triggers/BogenZone as Area3D
	zone.body_entered.connect(func(koerper: Node3D) -> void:
		if koerper == _player:
			_bogen_erreicht = true)
	_ablauf.call_deferred()


func _wartezeit(sekunden: float) -> float:
	return 0.05 if test_schnell else sekunden


## Wer spricht, nickt und bewegt die Hände; Anne sieht währenddessen zu
## Oliver hinüber (er erwidert das von selbst, sobald sie nah steht).
func _auf_sprechzeile(sprecher: String) -> void:
	match sprecher:
		"ANNE":
			_figur_anne.betone()
		"OLIVER":
			_figur_oliver.betone()
	_figur_anne.schaue_an(_oliver)


# --- Der rote Faden -----------------------------------------------------------


func _ablauf() -> void:
	# 1. Nach der Trauung: die beiden abseits, die Gäste am Bogen.
	_player.global_position = _START_ANNE
	_player.rotation.y = 2.5
	_oliver.hold()
	_oliver.global_position = _START_OLIVER
	_oliver.rotation.y = -0.7
	_film(Vector3(-9.6, 1.75, 18.4), Vector3(-5.4, 1.35, 16.2))
	# _menge bleibt stumm — das Rausch-Gemurmel klang wie Brandung.
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
	# Der Moment gehört gefeiert: Blütenkonfetti über den Gästen, und die
	# Stehenden hüpfen ein paar Sekunden mit.
	_konfetti_werfen()
	_gaeste_jubeln(4.0)
	await get_tree().create_timer(_wartezeit(2.6)).timeout
	_strauss.abschluss_uebernehmen()
	# Den gefangenen Strauß trägt sie ab jetzt in der rechten Hand —
	# durchs Schlussbild und bis zur Truhe.
	_strauss_in_die_hand()

	# 3b. Die Hochzeitsrede: das Paar setzt sich auf die Bank vor dem
	# Bogen, ein Redner tritt davor, die Kamera wandert über das Fest.
	await _rede_sequenz()

	# 4. Schlussbild am Wasser: die beiden vor der Brücke.
	_player.global_position = _SCHLUSS_ANNE
	_player.rotation.y = PI * 0.92
	_oliver.global_position = _SCHLUSS_OLIVER
	_oliver.rotation.y = -PI * 0.92
	_film(Vector3(0.0, 1.90, 6.4), Vector3(0.0, 1.62, 1.5))
	await _aufblenden(0.6)
	await _dialogue.play(HochzeitDialogue.GEWONNEN)

	# 5. Das Truhen-Finale: der Code öffnet das eigentliche Geschenk.
	await _truhen_finale()

	# 6. Der Geschenktext, dann der Abspann.
	await _geschenk_zeigen()
	await _karte.abspann(HochzeitDialogue.ABSPANN_TITEL,
		HochzeitDialogue.ABSPANN_ZEILE)
	kapitel_abgeschlossen.emit()
	if weiter_nach_abspann:
		get_tree().change_scene_to_file("res://ui/title_screen.tscn")


## Das Finale: eine verschlossene Truhe erscheint auf dem roten Teppich,
## Anne läuft hin, das Zahlenpad übernimmt (zwei Stellen, Hinweis auf die
## 42), und nach dem Öffnen schwebt der Rucksack heraus. Erst danach
## kommt der Geschenktext.
func _truhen_finale() -> void:
	await _abblenden(0.8)
	truhe = TruhenFinale.new()
	truhe.ort = Vector3(0.0, 0.06, 5.2)
	add_child(truhe)

	# Oliver tritt beiseite und schaut zu; Anne startet ein Stück entfernt.
	_oliver.global_position = Vector3(2.6, 0.25, 2.2)
	_oliver.rotation.y = -0.6
	_player.global_position = Vector3(0.0, 0.3, 13.0)
	_player.rotation.y = PI
	(_kamera_rig.get_node("SpringArm3D/Camera3D") as Camera3D).current = true
	var auf := create_tween()
	auf.tween_property(_blende, ^"color:a", 0.0, _wartezeit(0.8))
	await auf.finished

	_player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_objective.show_objective(HochzeitDialogue.ZIEL_TRUHE)
	while not truhe.erreicht():
		await get_tree().process_frame
	_player.input_enabled = false
	_objective.clear()

	# Anne neben die Truhe, Kamera nah — dann übernimmt das Zahlenpad.
	_player.global_position = Vector3(0.9, 0.3, 6.9)
	_player.rotation.y = 2.6
	_film(Vector3(-1.4, 1.35, 7.6), Vector3(0.2, 0.5, 5.2))
	truhe.pad_zeigen()
	await truhe.geoeffnet
	# Kein Musikwechsel mehr: Olivers Lied trägt durch — Truhe, Rucksack,
	# Geschenktext und Abspann. „Romantic Inspiration" ist raus.
	# Den schwebenden Rucksack in Ruhe wirken lassen — das ist das
	# Geschenk, der Moment darf stehen.
	await get_tree().create_timer(_wartezeit(7.5)).timeout


## Die Hochzeitsrede nach dem gewonnenen Spiel: das Paar sitzt auf der
## Bank vor dem Bogen, ein Redner steht davor, die Kamera wandert in
## drei Einstellungen über das Fest. Die Audiodatei ist Olivers echte
## Rede (`res://audio/rede.ogg` oder `.mp3`, ~2 min) — **liegt keine im
## Projekt, läuft eine kurze stumme Fassung als Platzhalter.** Die Datei
## später einfach nach `audio/` legen, mehr braucht es nicht.
func _rede_sequenz() -> void:
	await _abblenden(0.6)

	var bank := _BANK.instantiate() as Node3D
	add_child(bank)
	bank.position = Vector3(0.0, 0.06, 5.1)
	bank.rotation.y = PI

	_player.global_position = Vector3(-0.38, 0.3, 5.0)
	_player.rotation.y = PI
	_oliver.global_position = Vector3(0.42, 0.25, 5.0)
	_oliver.rotation.y = PI
	# Mocap anhalten, sonst überschreibt der nächste Tick die Sitzpose.
	_figur_anne.set_physics_process(false)
	_figur_oliver.set_physics_process(false)
	var anne_versatz := _figur_hinsetzen(_figur_anne)
	var oliver_versatz := _figur_hinsetzen(_figur_oliver)

	# Der Redner: ein Gast im Anzug, seitlich vor dem Bogen, zum Paar
	# gedreht. Sein Idle-Leben (Atmen, Umherschauen) bringt er selbst mit.
	var redner := Hochzeitsgast.new()
	redner.modell_pfad = "res://actors/models/gast_7.glb"
	redner.zielhoehe = 1.84
	redner.mocap_aktiv = false
	redner.gangwerk_aktiv = false
	redner.position = Vector3(1.1, 0.0, 2.4)
	redner.rotation.y = atan2(-0.38 - 1.1, 5.0 - 2.4) + PI
	add_child(redner)

	# Ton: die Musik duckt sich, die Rede übernimmt.
	var rede: AudioStreamPlayer = null
	var dauer := 10.0
	for pfad in ["res://audio/rede.ogg", "res://audio/rede.mp3"]:
		if ResourceLoader.exists(pfad):
			rede = AudioStreamPlayer.new()
			rede.stream = load(pfad)
			rede.volume_db = -2.0
			add_child(rede)
			dauer = rede.stream.get_length()
			break
	var ducken := create_tween()
	ducken.tween_property(_musik, ^"volume_db", -26.0, _wartezeit(1.5))

	# Einstellung 1: über die Schultern des Paares auf Redner und Brücke.
	_film(Vector3(-2.6, 1.7, 8.8), Vector3(0.7, 1.15, 2.4))
	await _aufblenden(0.6)
	if rede != null:
		rede.play()
	var drittel := _wartezeit(maxf(dauer, 3.0) / 3.0)
	await get_tree().create_timer(drittel).timeout
	# Einstellung 2: am Bogen und am Redner vorbei auf das sitzende Paar.
	_film(Vector3(3.4, 1.5, 0.8), Vector3(-0.5, 0.95, 5.6))
	await get_tree().create_timer(drittel).timeout
	# Einstellung 3: weit von der Seite, Gäste und Speicher im Bild.
	_film(Vector3(-8.5, 2.6, 13.5), Vector3(0.6, 1.0, 3.2))
	await get_tree().create_timer(drittel).timeout

	await _abblenden(0.6)
	if rede != null and rede.playing:
		create_tween().tween_property(rede, ^"volume_db", -40.0, _wartezeit(0.8))
	# Aufstehen: Versatz zurücknehmen, der nächste Mocap-Tick stellt die
	# Knochen von selbst wieder in die Stand-Pose.
	_figur_anne.position.y += anne_versatz
	_figur_oliver.position.y += oliver_versatz
	_figur_anne.set_physics_process(true)
	_figur_oliver.set_physics_process(true)
	bank.queue_free()
	redner.queue_free()
	create_tween().tween_property(_musik, ^"volume_db", -13.0, _wartezeit(2.0))


## Setzt eine Spielfigur in Sitzpose — dieselbe Skelettraum-Technik wie
## bei den Gästen (`Hochzeitsgast._hinsetzen`), plus Oberarme leicht nach
## vorn, damit die Hände nicht in den Oberschenkeln stecken. Liefert den
## Höhenversatz zurück, damit die Sequenz ihn beim Aufstehen zurücknimmt.
func _figur_hinsetzen(figur: Figur, sitzhoehe: float = 0.47) -> float:
	var skelett := figur.skelett_finden()
	if skelett == null:
		return 0.0
	for seite in ["Left", "Right"]:
		var schenkel := skelett.find_bone("%sUpLeg" % seite)
		var schienbein := skelett.find_bone("%sLeg" % seite)
		if schenkel < 0 or schienbein < 0:
			return 0.0
		var lage := skelett.get_bone_global_pose(schenkel)
		skelett.set_bone_global_pose(schenkel, Transform3D(
			Basis(Vector3.RIGHT, -PI * 0.46) * lage.basis, lage.origin))
		lage = skelett.get_bone_global_pose(schienbein)
		skelett.set_bone_global_pose(schienbein, Transform3D(
			Basis(Vector3.RIGHT, PI * 0.44) * lage.basis, lage.origin))
	for paar: Array in [["Left", -1.0], ["Right", 1.0]]:
		var arm := skelett.find_bone("%sArm" % paar[0])
		if arm < 0:
			continue
		var lage := skelett.get_bone_global_pose(arm)
		skelett.set_bone_global_pose(arm, Transform3D(
			Basis(Vector3.RIGHT, -0.22)
			* Basis(Vector3(0, 0, 1), -0.18 * (paar[1] as float)) * lage.basis,
			lage.origin))
	var huefte := skelett.find_bone("Hips")
	if huefte < 0:
		return 0.0
	var hueft_welt := (skelett.global_transform
		* skelett.get_bone_global_pose(huefte).origin).y - figur.global_position.y
	var versatz := hueft_welt - sitzhoehe - 0.05
	figur.position.y -= versatz
	return versatz


## Das Hochzeitskleid: Mieder, Rock und Taillenband aus `kleid.glb`
## (gebaut auf Annes eigenem Avatar, `tools/make_kleid.py`) werden an
## das Skelett ihrer geladenen Figur gehängt — gleiche Knochennamen,
## gleiche Bindposen, die Godot-Skins finden ihre Knochen über den
## Namen. Das Kleid liegt über dem Alltagsoutfit; sichtbar bleiben von
## ihm nur Arme, Schultern und die Schuhe unterm bodenlangen Rock.
func _kleid_anziehen() -> void:
	var figur := _player.get_node_or_null("Visual") as Figur
	if figur == null:
		return
	var skelett := figur.skelett_finden()
	if skelett == null:
		return
	var kleid := _KLEID.instantiate() as Node3D
	for kind in kleid.find_children("*", "MeshInstance3D", true, false):
		var teil := kind as MeshInstance3D
		teil.get_parent().remove_child(teil)
		skelett.add_child(teil)
		# Die leichten Lagen — Tüll-Überrock und Schleier — bekommen einen
		# Wind-Shader: unten stärker als oben, damit der Stoff lebt statt
		# wie gegossen zu stehen.
		if teil.name == "kleid_tuell":
			teil.material_override = _windstoff(0.95, 0.10, 0.030)
		elif teil.name == "kleid_schleier":
			teil.material_override = _windstoff(1.55, 0.95, 0.022)
	kleid.queue_free()


## Ein durchscheinender Stoff, den der Spree-Wind bewegt. `oben`/`unten`
## grenzen die Höhenspanne ein (Skelettraum), dazwischen wächst der
## Ausschlag zum Saum hin an.
func _windstoff(oben: float, unten: float, staerke: float) -> ShaderMaterial:
	var wind := Shader.new()
	wind.code = """
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform vec4 farbe : source_color = vec4(1.0, 1.0, 1.0, 0.30);
uniform float staerke = 0.03;
uniform float oben = 1.0;
uniform float unten = 0.1;
void vertex() {
	float saum = clamp((oben - VERTEX.y) / max(oben - unten, 0.001), 0.0, 1.0);
	float boee = sin(TIME * 1.7 + VERTEX.y * 4.0 + VERTEX.x * 2.3) * 0.6
		+ sin(TIME * 2.9 + VERTEX.z * 5.1) * 0.4;
	VERTEX.x += boee * staerke * saum;
	VERTEX.z += cos(TIME * 1.3 + VERTEX.y * 3.2) * staerke * 0.6 * saum;
}
void fragment() {
	ALBEDO = farbe.rgb;
	ALPHA = farbe.a;
	ROUGHNESS = 0.9;
}
"""
	var stoff := ShaderMaterial.new()
	stoff.shader = wind
	stoff.set_shader_parameter("oben", oben)
	stoff.set_shader_parameter("unten", unten)
	stoff.set_shader_parameter("staerke", staerke)
	return stoff


## Blütenkonfetti beim gewonnenen Fangen: drei Salven über den Stuhlreihen,
## rosa und weiße Blättchen, die trudelnd zu Boden segeln.
func _konfetti_werfen() -> void:
	for ort in [Vector3(-4.5, 2.4, 8.2), Vector3(0.0, 2.7, 9.0),
			Vector3(4.5, 2.4, 8.2)]:
		var salve := CPUParticles3D.new()
		salve.one_shot = true
		salve.amount = 70
		salve.lifetime = 3.4
		salve.explosiveness = 0.92
		salve.direction = Vector3.UP
		# Eng gebündelt und nicht zu schnell — eine weite, schnelle Salve
		# las sich im Bild wie Schneetreiben über der ganzen Szene.
		salve.spread = 40.0
		salve.initial_velocity_min = 1.4
		salve.initial_velocity_max = 2.8
		salve.gravity = Vector3(0.0, -1.4, 0.0)
		salve.damping_min = 0.6
		salve.damping_max = 1.4
		salve.angular_velocity_min = -220.0
		salve.angular_velocity_max = 220.0
		salve.scale_amount_min = 0.7
		salve.scale_amount_max = 1.3
		var blatt := QuadMesh.new()
		blatt.size = Vector2(0.06, 0.06)
		var stoff := StandardMaterial3D.new()
		stoff.albedo_color = Color(1.0, 0.62, 0.72)
		stoff.vertex_color_use_as_albedo = true
		stoff.roughness = 1.0
		stoff.cull_mode = BaseMaterial3D.CULL_DISABLED
		stoff.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		blatt.material = stoff
		salve.mesh = blatt
		salve.color_ramp = _konfetti_farben()
		add_child(salve)
		salve.global_position = ort
		salve.emitting = true
		# Räumt sich selbst weg, wenn alles gelandet ist.
		get_tree().create_timer(salve.lifetime + 1.0).timeout.connect(
			salve.queue_free)


func _konfetti_farben() -> Gradient:
	var verlauf := Gradient.new()
	verlauf.set_color(0, Color(1.0, 0.72, 0.80))
	verlauf.set_color(1, Color(1.0, 0.98, 0.94))
	return verlauf


## Die stehenden Gäste hüpfen ein paar Sekunden — jeder mit eigenem
## Rhythmus und Versatz, damit es nach Jubel aussieht, nicht nach Ballett.
func _gaeste_jubeln(dauer: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 92023
	var gaeste: Array[Node3D] = _kulisse.gaeste
	for gast in gaeste:
		if gast.get("sitzend"):
			continue
		# Nicht alle: gut zwei Drittel springen, der Rest freut sich still.
		if rng.randf() < 0.3:
			continue
		var boden := gast.position.y
		var hop := create_tween()
		hop.tween_interval(rng.randf_range(0.0, 0.5))
		var takt := rng.randf_range(0.30, 0.42)
		var hoehe := rng.randf_range(0.12, 0.22)
		var spruenge := int(dauer / (takt * 2.0))
		for i in spruenge:
			hop.tween_property(gast, ^"position:y", boden + hoehe, takt) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			hop.tween_property(gast, ^"position:y", boden, takt) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


## Der gefangene Brautstrauß wandert in Annes rechte Hand — ein
## BoneAttachment am Handknochen, der Strauß leicht gekippt, damit die
## Blüten nach vorn-oben zeigen, während der Arm hängt.
func _strauss_in_die_hand() -> void:
	var figur := _player.get_node_or_null("Visual") as Figur
	if figur == null:
		return
	var skelett := figur.skelett_finden()
	if skelett == null or skelett.find_bone("RightHand") < 0:
		return
	var halter := BoneAttachment3D.new()
	halter.bone_name = "RightHand"
	skelett.add_child(halter)
	var strauss := _STRAUSS.instantiate() as Node3D
	halter.add_child(strauss)
	strauss.scale = Vector3.ONE * 0.8
	strauss.position = Vector3(0.0, 0.09, 0.02)
	strauss.rotation = Vector3(0.5, 0.0, 0.25)


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


func _aufblenden(dauer: float) -> void:
	var lauf := create_tween()
	lauf.tween_property(_blende, ^"color:a", 0.0, _wartezeit(dauer))
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
