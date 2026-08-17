extends CanvasLayer

## Kapitelkarte: dieselbe Tafel am Anfang und am Ende eines Kapitels.
##
## Beide Male passiert dasselbe in unterschiedlicher Richtung — schwarzes Bild,
## Titel, Untertitel — und beide Male bewusst langsam. Ein harter Schnitt wirkt
## wie ein Absturz; das Verweilen gibt dem Moment Zeit, bevor etwas Neues
## anfängt.
##
## `auftakt()` beginnt schwarz und gibt das Bild frei, `abspann()` nimmt es weg
## und behält es. Beide kehren erst zurück, wenn alles gestanden hat.

@export_range(0.2, 4.0, 0.1) var verdunkeln_dauer: float = 1.6
@export_range(0.2, 4.0, 0.1) var titel_dauer: float = 1.4
@export_range(0.5, 10.0, 0.5) var stehen_lassen: float = 4.0
## Wie lange die Titeltafel am Kapitelanfang steht, bevor das Bild aufgeht.
@export_range(0.5, 6.0, 0.1) var auftakt_stehen: float = 1.8

@onready var _schwarz: ColorRect = $Schwarz
@onready var _titel: Label = $Mitte/VBox/Titel
@onready var _unterzeile: Label = $Mitte/VBox/Unterzeile
@onready var _hinweis: Label = $Mitte/VBox/Hinweis


func _ready() -> void:
	_schwarz.color.a = 0.0
	_titel.modulate.a = 0.0
	_unterzeile.modulate.a = 0.0
	_hinweis.modulate.a = 0.0
	visible = false


## Kapitelanfang: aus dem Schwarzen den Titel zeigen, dann das Bild freigeben.
func auftakt(titel: String, unterzeile: String) -> void:
	_beschriften(titel, unterzeile)
	_schwarz.color.a = 1.0
	visible = true

	var ablauf := create_tween()
	ablauf.tween_property(_titel, ^"modulate:a", 1.0, titel_dauer * 0.7)
	ablauf.tween_property(_unterzeile, ^"modulate:a", 1.0, titel_dauer * 0.5)
	ablauf.tween_interval(auftakt_stehen)
	ablauf.set_parallel(true)
	ablauf.tween_property(_titel, ^"modulate:a", 0.0, titel_dauer * 0.6)
	ablauf.tween_property(_unterzeile, ^"modulate:a", 0.0, titel_dauer * 0.6)
	ablauf.chain().tween_property(_schwarz, ^"color:a", 0.0, verdunkeln_dauer)
	await ablauf.finished

	visible = false


## Kapitelende: abblenden, Titel zeigen, stehen lassen.
func abspann(titel: String, unterzeile: String) -> void:
	_beschriften(titel, unterzeile)
	_schwarz.color.a = 0.0
	visible = true

	var ablauf := create_tween()
	ablauf.tween_property(_schwarz, ^"color:a", 1.0, verdunkeln_dauer)
	ablauf.tween_property(_titel, ^"modulate:a", 1.0, titel_dauer)
	ablauf.tween_property(_unterzeile, ^"modulate:a", 1.0, titel_dauer * 0.8)
	ablauf.tween_interval(stehen_lassen)
	# Der Hinweis kommt zuletzt und leise: erst wenn der Titel gestanden hat,
	# darf wieder von Bedienung die Rede sein.
	ablauf.tween_property(_hinweis, ^"modulate:a", 1.0, titel_dauer)
	await ablauf.finished


func _beschriften(titel: String, unterzeile: String) -> void:
	_titel.text = titel
	_unterzeile.text = unterzeile
	_titel.modulate.a = 0.0
	_unterzeile.modulate.a = 0.0
	_hinweis.modulate.a = 0.0
