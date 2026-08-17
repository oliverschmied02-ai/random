extends CanvasLayer

## Abspann eines Kapitels: Bild verdunkeln, Titel einblenden, stehen lassen.
##
## Bewusst langsam. Ein harter Schnitt auf Schwarz wirkt wie ein Absturz; das
## Verweilen danach gibt dem Moment Zeit, bevor irgendetwas Neues anfängt.

@export_range(0.2, 4.0, 0.1) var verdunkeln_dauer: float = 1.6
@export_range(0.2, 4.0, 0.1) var titel_dauer: float = 1.4
@export_range(0.5, 10.0, 0.5) var stehen_lassen: float = 4.0

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


## Blendet ab und zeigt den Titel. Kehrt zurück, wenn alles gestanden hat.
func zeige(titel: String, unterzeile: String) -> void:
	_titel.text = titel
	_unterzeile.text = unterzeile
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
