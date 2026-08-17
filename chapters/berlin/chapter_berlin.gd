extends Node3D

## Kapitel 1 — Berlin. Ablaufsteuerung für Abholen und Spaziergang.
##
## Die Sequenzen stehen bewusst als gerade heruntergeschriebene Abfolgen da:
## wer sie liest, sieht die Szene vor sich. Ein Zustandsautomat oder ein
## visuelles Skriptsystem wäre für so wenige Schritte mehr Gerüst als Inhalt.
##
## Der Ablauf:
##   1. Oliver vor seiner Bürotür abholen (Ansprechen mit E)
##   2. am geschlossenen Café — löst beim Vorbeigehen aus
##   3. auf dem Platz am Desinfektionsspender — ebenso
##   4. Ankunft an der Dönerbude, vorläufiges Kapitelende
##
## Die drei Stationen unterwegs sind Area3D-Knoten unter `Triggers`. Eine
## Station hinzuzufügen heißt: Area3D in die Szene, Zeile in `_STATIONEN`.

signal kapitel_abgeschlossen

## Stationen unterwegs: Trigger-Knoten, Dialog, danach angezeigtes Ziel.
const _STATIONEN := [
	{
		"node": "TriggerCafe",
		"lines": BerlinDialogue.UNTERWEGS_CAFE,
		"ziel": "Weiter durch die Stadt",
	},
	{
		"node": "TriggerPlatz",
		"lines": BerlinDialogue.UNTERWEGS_PLATZ,
		"ziel": "Weiter durch die Stadt",
	},
	{
		"node": "TriggerDoener",
		"lines": BerlinDialogue.ANKUNFT_DOENER,
		"ziel": "Kapitel 1 — Fortsetzung folgt",
	},
]

## Wie weit die Kamera fürs Gespräch zur Seite schwenkt. Genau hinter der
## Spielerin verdeckt sie Oliver komplett; seitlich stehen beide im Bild.
@export_range(0.0, 90.0, 5.0) var gespraechswinkel_grad: float = 48.0
## Wie lange höchstens darauf gewartet wird, dass Oliver sich neben die
## Spielerin stellt, bevor der Dialog trotzdem beginnt.
@export_range(0.0, 6.0, 0.5) var aufstell_wartezeit: float = 2.5

@onready var _player: Player = $Player
@onready var _camera: ThirdPersonCamera = $ThirdPersonCamera
@onready var _oliver: Companion = $Oliver
@onready var _dialogue: DialogueBox = $UI/DialogueBox
@onready var _objective = $UI/ObjectiveLabel

var _szene_laeuft: bool = false


func _ready() -> void:
	var tuer := _oliver.get_node("Interactable") as Interactable
	tuer.interacted.connect(_on_oliver_abgeholt)

	for station in _STATIONEN:
		var area := get_node_or_null("Triggers/%s" % station["node"]) as Area3D
		if area == null:
			push_warning("Kapitel Berlin: Trigger '%s' fehlt." % station["node"])
			continue
		area.body_entered.connect(_on_station_betreten.bind(station, area))

	_objective.show_objective("Oliver von der Arbeit abholen")


## Erste Station: das Abholen vor der Bürotür.
func _on_oliver_abgeholt(_interactor: Node3D) -> void:
	await _spiele_szene(BerlinDialogue.ABHOLEN)
	_oliver.activate()
	_objective.show_objective("Gemeinsam durch die Stadt")


## Die Stationen unterwegs lösen beim Betreten aus, nicht auf Tastendruck —
## sie sind Teil der Geschichte, keine optionalen Fundstücke.
func _on_station_betreten(body: Node3D, station: Dictionary, area: Area3D) -> void:
	if body != _player or _szene_laeuft:
		return
	area.set_deferred(&"monitoring", false)  # jede Station genau einmal

	await _spiele_szene(station["lines"])

	_oliver.activate()
	_objective.show_objective(station["ziel"])
	if station["node"] == "TriggerDoener":
		kapitel_abgeschlossen.emit()


## Der gemeinsame Ablauf jeder Gesprächsszene: Steuerung abgeben, Oliver
## danebenstellen, Kamera schwenken, reden lassen, alles zurückgeben.
func _spiele_szene(lines: Array) -> void:
	_szene_laeuft = true
	_player.input_enabled = false

	await _oliver_danebenstellen()
	_camera.aim_at_yaw(_gespraechs_winkel())

	await _dialogue.play(lines)

	_camera.release_aim()
	_player.input_enabled = true
	_szene_laeuft = false


## Holt Oliver an die Seite der Spielerin, wartet aber nicht ewig darauf —
## ein Gespräch, das nicht anfängt, weil jemand hängengeblieben ist, wäre
## schlimmer als ein Gespräch mit unsauberer Bildaufteilung.
func _oliver_danebenstellen() -> void:
	if _oliver.state == Companion.State.IDLE:
		_oliver.hold()  # wartet noch vor der Tür, bleibt einfach stehen
		return

	var rechts := _player.global_transform.basis.x
	rechts = Vector3(rechts.x, 0.0, rechts.z).normalized()
	_oliver.move_to(_player.global_position + rechts * 1.7)

	var angekommen := false
	var beim_ankommen := func() -> void: angekommen = true
	_oliver.arrived.connect(beim_ankommen, CONNECT_ONE_SHOT)

	var frist := get_tree().create_timer(aufstell_wartezeit)
	while not angekommen and frist.time_left > 0.0:
		await get_tree().process_frame

	if _oliver.arrived.is_connected(beim_ankommen):
		_oliver.arrived.disconnect(beim_ankommen)
	_oliver.hold()


## Blickrichtung entlang der Achse zwischen beiden Figuren, seitlich versetzt.
func _gespraechs_winkel() -> float:
	var zu_oliver := _oliver.global_position - _player.global_position
	zu_oliver.y = 0.0
	if zu_oliver.length() < 0.1:
		return _camera.rotation.y
	zu_oliver = zu_oliver.normalized()
	return atan2(-zu_oliver.x, -zu_oliver.z) + deg_to_rad(gespraechswinkel_grad)
