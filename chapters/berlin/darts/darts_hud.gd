extends CanvasLayer

## Anzeige des Minispiels: Wurfzähler, Punktestand, Fadenkreuz, Kraftbalken.
##
## Der Kraftbalken zeigt die Idealzone offen an. Eine versteckte Idealzone
## wäre Raten, keine Geschicklichkeit — und das Spiel soll niemanden ärgern.

const BALKEN_BREITE: float = 420.0

@onready var _wurf_label: Label = $Root/Kopf/Wurf
@onready var _punkte_label: Label = $Root/Kopf/Punkte
@onready var _fadenkreuz: Control = $Root/Fadenkreuz
@onready var _balken: Control = $Root/Kraftbalken
@onready var _balken_fuellung: ColorRect = $Root/Kraftbalken/Fuellung
@onready var _balken_zone: ColorRect = $Root/Kraftbalken/Idealzone
@onready var _banner: Control = $Root/Banner
@onready var _banner_titel: Label = $Root/Banner/VBox/Titel
@onready var _banner_zeile: Label = $Root/Banner/VBox/Zeile


func _ready() -> void:
	_balken.visible = false
	_banner.visible = false
	_fadenkreuz.visible = false


func setze_wurf(uebrig: int, gesamt: int) -> void:
	_wurf_label.text = "MASKEN %d / %d" % [uebrig, gesamt]


func setze_punkte(treffer: int, ziel: int) -> void:
	_punkte_label.text = "TREFFER: %d / %d" % [treffer, ziel]


## Zeigt die Idealzone an, in der die Wurfkraft genau passt.
func setze_idealzone(von: float, bis: float) -> void:
	_balken_zone.position.x = BALKEN_BREITE * von
	_balken_zone.size.x = BALKEN_BREITE * (bis - von)


func setze_kraft(anteil: float, sichtbar: bool) -> void:
	_balken.visible = sichtbar
	_balken_fuellung.size.x = BALKEN_BREITE * clampf(anteil, 0.0, 1.0)


func setze_fadenkreuz(bildschirm_position: Vector2, sichtbar: bool) -> void:
	_fadenkreuz.visible = sichtbar
	_fadenkreuz.position = bildschirm_position


## Lässt eine Punktzahl an der Einschlagstelle aufsteigen und verblassen.
func zeige_trefferpunkte(text: String, bildschirm_position: Vector2, gut: bool) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 34 if gut else 26)
	label.add_theme_color_override(
		&"font_color", Color(1, 0.85, 0.35) if gut else Color(0.92, 0.94, 0.97)
	)
	label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override(&"shadow_offset_y", 2)
	label.position = bildschirm_position
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(label)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, ^"position:y", bildschirm_position.y - 90.0, 1.1)
	tween.tween_property(label, ^"modulate:a", 0.0, 1.1).set_delay(0.35)
	tween.chain().tween_callback(label.queue_free)


func zeige_banner(titel: String, zeile: String) -> void:
	_banner_titel.text = titel
	_banner_zeile.text = zeile
	_banner.visible = true
	_banner.modulate.a = 0.0
	create_tween().tween_property(_banner, ^"modulate:a", 1.0, 0.4)


func verstecke_banner() -> void:
	_banner.visible = false
