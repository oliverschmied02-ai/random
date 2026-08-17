class_name Ton
extends RefCounted

## Lautstärken — überall erreichbar und über Sitzungen hinweg gemerkt.
##
## Zwei weit auseinanderliegende Stellen brauchen dieselben Werte: der
## Titelbildschirm und das Pausenmenü im laufenden Kapitel. Ein Knoten in einer
## Szene wäre beim Szenenwechsel weg.
##
## Deshalb statisch statt Autoload: keine Instanz, kein Knoten im Baum, und
## `Ton.lautstaerke(...)` funktioniert auch in den Prüfläufen, die den Baum
## selbst aufbauen. Geladen wird beim ersten Zugriff.
##
## Gespeichert wird in `user://einstellungen.cfg` — auf dem Mac unter
## *~/Library/Application Support/Godot/app_userdata/Our Story/*. Die Datei darf
## fehlen oder kaputt sein; dann gelten die Startwerte.

const DATEI := "user://einstellungen.cfg"
const BUSSE := {"musik": &"Musik", "klang": &"Klang"}
## Unterhalb dieses Anteils gilt ein Bus als stumm. Ein Regler ganz links soll
## Stille bedeuten, nicht „sehr leise" — logarithmisch ist −60 dB noch hörbar.
const STUMM_UNTER := 0.005

static var _werte := {"musik": 0.7, "klang": 0.85}
static var _geladen := false


## Lautstärke eines Busses als Anteil von 0 bis 1.
static func lautstaerke(schluessel: String) -> float:
	_sicherstellen()
	return _werte.get(schluessel, 1.0)


static func setze_lautstaerke(schluessel: String, wert: float) -> void:
	_sicherstellen()
	if not BUSSE.has(schluessel):
		push_warning("Ton: unbekannter Bus '%s'." % schluessel)
		return
	_werte[schluessel] = clampf(wert, 0.0, 1.0)
	_anwenden(schluessel)
	_speichern()


## Lädt die gespeicherten Werte einmalig und legt sie auf die Busse.
static func _sicherstellen() -> void:
	if _geladen:
		return
	_geladen = true
	_laden()
	for schluessel in _werte:
		_anwenden(schluessel)


## Rechnet den Anteil in Dezibel um. `linear_to_db` ist genau dafür da: ein
## Regler auf halber Strecke soll halb so laut klingen, nicht 3 dB leiser.
static func _anwenden(schluessel: String) -> void:
	var bus := AudioServer.get_bus_index(BUSSE[schluessel])
	if bus < 0:
		return
	var anteil: float = _werte[schluessel]
	AudioServer.set_bus_mute(bus, anteil < STUMM_UNTER)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(anteil, STUMM_UNTER)))


static func _laden() -> void:
	var datei := ConfigFile.new()
	if datei.load(DATEI) != OK:
		return
	for schluessel in _werte:
		_werte[schluessel] = clampf(
			float(datei.get_value("ton", schluessel, _werte[schluessel])), 0.0, 1.0
		)


static func _speichern() -> void:
	var datei := ConfigFile.new()
	for schluessel in _werte:
		datei.set_value("ton", schluessel, _werte[schluessel])
	datei.save(DATEI)
