class_name Syringe
extends Node3D

## Die geworfene Impfspritze.
##
## Die Flugbahn wird **analytisch** ausgewertet, nicht Schritt für Schritt
## aufsummiert. Schrittweise Integration wirkt naheliegend, verschiebt den
## Einschlag aber systematisch: bei 60 Hz landet ein exakt gezielter Wurf rund
## drei Zentimeter zu tief, weil sich in jedem Schritt ein halber
## Schwerkraftschritt Fehler ansammelt. Bei einer Scheibe mit 2,4 cm Innenring
## ist das der Unterschied zwischen Volltreffer und Nebenring.
##
## Mit der geschlossenen Form steht der Einschlagpunkt schon beim Abwurf fest,
## ist unabhängig von der Bildrate und in jedem Durchlauf gleich.

signal eingeschlagen(punkte: int, treffer_ort: Vector3, radius: float)

## Mittelpunkt der Scheibe, für die Auswertung des Trefferradius.
var scheiben_mitte: Vector3 = Vector3.ZERO

var _start: Vector3 = Vector3.ZERO
var _anfangsgeschwindigkeit: Vector3 = Vector3.ZERO
var _zeit: float = 0.0
var _flugzeit: float = 0.0
var _fliegt: bool = false
var _schwerkraft: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)


## Startet den Flug. Die Scheibe liegt in -Z-Richtung bei `ziel_ebene_z`.
func werfen(geschwindigkeit: Vector3, ziel_ebene_z: float, mitte: Vector3) -> void:
	_start = global_position
	_anfangsgeschwindigkeit = geschwindigkeit
	scheiben_mitte = mitte
	_zeit = 0.0

	# Waagerecht wirkt keine Schwerkraft, also ist der Zeitpunkt des
	# Durchstoßens direkt ausrechenbar.
	if geschwindigkeit.z >= -0.01:
		queue_free()  # nach hinten geworfen — kommt nie an
		return
	_flugzeit = (ziel_ebene_z - _start.z) / geschwindigkeit.z
	_fliegt = true
	_setze_lage(0.0)


func _physics_process(delta: float) -> void:
	if not _fliegt:
		return
	_zeit += delta
	if _zeit >= _flugzeit:
		_fliegt = false
		_setze_lage(_flugzeit)
		_einschlagen()
		return
	_setze_lage(_zeit)


## Position und Ausrichtung zum Zeitpunkt `t` des Wurfs.
func _setze_lage(t: float) -> void:
	global_position = (
		_start
		+ _anfangsgeschwindigkeit * t
		- Vector3.UP * 0.5 * _schwerkraft * t * t
	)
	var richtung := _anfangsgeschwindigkeit - Vector3.UP * _schwerkraft * t
	if richtung.length_squared() < 0.01:
		return
	richtung = richtung.normalized()
	var hoch := Vector3.UP
	if absf(richtung.dot(hoch)) > 0.99:
		hoch = Vector3.FORWARD
	# `look_at` richtet die -Z-Achse aus; dort sitzt die Nadel.
	look_at(global_position + richtung, hoch)


func _einschlagen() -> void:
	var versatz := global_position - scheiben_mitte
	var radius := Vector2(versatz.x, versatz.y).length()
	eingeschlagen.emit(DartsConfig.punkte_fuer_radius(radius), global_position, radius)
	_stecken_bleiben()


## Lässt die Spritze sichtbar in der Scheibe stecken: nur die halbe Nadel im
## Kork, das hintere Ende hängt durch — ein senkrecht steckender Wurf zeigt
## dem Betrachter nur seinen Deckel, erst die Schräglage macht die Silhouette
## mit Glaszylinder und Serum erkennbar.
func _stecken_bleiben() -> void:
	global_position += global_transform.basis.z * 0.09
	var spitze := global_position - global_transform.basis.z * 0.185
	rotate_object_local(Vector3.RIGHT, randf_range(0.25, 0.4))
	global_position = spitze + global_transform.basis.z * 0.185
