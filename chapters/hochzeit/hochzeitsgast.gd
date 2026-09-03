class_name Hochzeitsgast
extends Figur

## Ein Gast auf der Hochzeit — eines der acht Mixamo-Modelle, per
## Material-Tönung variiert.
##
## Acht Modelle für fünfzig Menschen tragen nur, wenn die Kopien nicht wie
## Kopien aussehen. Die Regeln sind dieselben wie bei den Passanten in
## Kapitel 2: Größe streuen, Kleidung *und* Haar färben, Wiederholungen
## räumlich auseinanderziehen. Gefärbt wird als Multiplikation über die
## vorhandene Stofftextur (`albedo_color` wirkt auf `albedo_texture`),
## dadurch bleiben Falten und Webmuster erhalten — eine flächige Farbe
## sähe aus wie angemalt.
##
## Die Meshes heißen je Charakter anders (Tops, Shirt, Sweater, Hoodie,
## Suit, Cloth …), deshalb läuft die Zuordnung über Stichwörter im
## Mesh-Namen. Haut („Body") und Augen werden grundsätzlich nie gefärbt.
## Trägt ein Modell einen Anzug, bleibt das Hemd darunter ungefärbt —
## sonst verschwimmt der Kontrast am Kragen.

## Tönung für Oberteil/Jackett/Kleid. TRANSPARENT lässt das Original.
@export var oberteil: Color = Color.TRANSPARENT
## Tönung für die Hose. Bei Anzügen denselben Wert wie `oberteil` setzen.
@export var hose: Color = Color.TRANSPARENT
## Tönung für Haar und Bart. Werte über 1 hellen auf (grau, blond).
@export var haar_ton: Color = Color.TRANSPARENT
## Auf einen Stuhl setzen: Beine per Knochenpose beugen, Figur auf
## Sitzhöhe absenken. `sitzhoehe` ist die Sitzflächen-Oberkante in Metern.
@export var sitzend: bool = false
@export var sitzhoehe: float = 0.55

const _OBEN: Array[String] = ["tops", "sweater", "hoodie", "suit", "cloth"]
const _HEMD: Array[String] = ["shirt"]
const _UNTEN: Array[String] = ["pants", "bottoms"]
const _HAAR: Array[String] = ["hair", "beard"]


func _ready() -> void:
	super()
	if modell == null:
		return
	_toenen()
	if sitzend:
		_hinsetzen()
	_idle_einrichten()


# --- Idle-Leben ---------------------------------------------------------------
#
# Mocap und Gangwerk sind auf das RPM-Rig geeicht und bleiben hier aus —
# aber fünfzig komplett eingefrorene Menschen sehen aus wie Pappaufsteller.
# Diese dünne Schicht bewegt nur Brustkorb und Kopf: Atmen, ein ganz
# langsames Pendeln, beiläufiges Umherschauen. Jeder Gast bekommt eigene
# Frequenzen und Phasen, sonst atmet die ganze Reihe im Gleichtakt.
# Gesetzt wird im Skelettraum über der einmal eingerichteten Pose (auch
# der sitzenden), wie beim Armsenken in `Figur`.

var _idle_skelett: Skeleton3D
var _idle_spine: int = -1
var _idle_kopf: int = -1
var _idle_spine_basis: Basis
var _idle_kopf_basis: Basis
var _idle_zeit: float = 0.0
var _idle_saat: float = 0.0
var _idle_mass: float = 1.0


func _idle_einrichten() -> void:
	var skelett := skelett_finden()
	if skelett == null:
		return
	_idle_spine = skelett.find_bone("Spine2")
	_idle_kopf = skelett.find_bone("Head")
	if _idle_spine < 0 or _idle_kopf < 0:
		return
	_idle_skelett = skelett
	_idle_spine_basis = skelett.get_bone_global_pose(_idle_spine).basis
	_idle_kopf_basis = skelett.get_bone_global_pose(_idle_kopf).basis
	_idle_saat = fposmod(absf(position.x * 12.9898 + position.z * 78.233), TAU)
	# Sitzende bewegen sich verhaltener — sie hören zu, sie warten nicht.
	_idle_mass = 0.55 if sitzend else 1.0
	set_process(true)


func _process(delta: float) -> void:
	if _idle_skelett == null:
		return
	_idle_zeit += delta
	var t := _idle_zeit + _idle_saat * 10.0
	# Atmen (Nicken des Brustkorbs) + langsames seitliches Pendeln.
	var atmen := 0.020 * sin(TAU * (0.24 + 0.04 * sin(_idle_saat)) * t)
	var pendeln := 0.017 * sin(0.31 * t + _idle_saat) \
		+ 0.008 * sin(0.53 * t + _idle_saat * 1.7)
	var lage := _idle_skelett.get_bone_global_pose(_idle_spine)
	_idle_skelett.set_bone_global_pose(_idle_spine, Transform3D(
		Basis(Vector3(0, 0, 1), pendeln * _idle_mass)
		* Basis(Vector3.RIGHT, -atmen * _idle_mass)
		* _idle_spine_basis, lage.origin))
	# Beiläufiger Blick: zwei ungleiche, langsame Wellen — kein Muster.
	var gier := (0.14 * sin(0.19 * t + _idle_saat)
		+ 0.07 * sin(0.67 * t + _idle_saat * 2.3)) * _idle_mass
	var nick := 0.04 * sin(0.27 * t + _idle_saat * 0.6) * _idle_mass
	lage = _idle_skelett.get_bone_global_pose(_idle_kopf)
	_idle_skelett.set_bone_global_pose(_idle_kopf, Transform3D(
		Basis(Vector3.UP, gier) * Basis(Vector3.RIGHT, nick)
		* _idle_kopf_basis, lage.origin))


## Setzt die Figur hin — dieselbe Skelettraum-Technik wie das Armsenken
## in `Figur`: Oberschenkel um die Skelett-X-Achse nach vorn (das Modell
## schaut im Skelettraum nach +Z), Unterschenkel wieder senkrecht nach
## unten, der Fuß folgt von selbst mit Netto-Drehung null und bleibt
## flach. Danach sinkt der ganze Knoten, bis das Gesäß (die Hüfthöhe)
## auf der Sitzfläche liegt.
func _hinsetzen() -> void:
	var skelett := skelett_finden()
	if skelett == null:
		return
	for seite in ["Left", "Right"]:
		var schenkel := skelett.find_bone("%sUpLeg" % seite)
		var schienbein := skelett.find_bone("%sLeg" % seite)
		if schenkel < 0 or schienbein < 0:
			return
		var lage := skelett.get_bone_global_pose(schenkel)
		skelett.set_bone_global_pose(schenkel, Transform3D(
			Basis(Vector3.RIGHT, -PI * 0.46) * lage.basis, lage.origin))
		lage = skelett.get_bone_global_pose(schienbein)
		skelett.set_bone_global_pose(schienbein, Transform3D(
			Basis(Vector3.RIGHT, PI * 0.44) * lage.basis, lage.origin))
	# Sitzende Arme: etwas weniger gesenkt und weiter vorn, sonst stecken
	# die Hände in den Oberschenkeln. Die Ruhelage steht schon — nur die
	# Oberarme werden nachgestellt.
	for paar: Array in [["Left", -1.0], ["Right", 1.0]]:
		var arm := skelett.find_bone("%sArm" % paar[0])
		if arm < 0:
			continue
		var lage := skelett.get_bone_global_pose(arm)
		skelett.set_bone_global_pose(arm, Transform3D(
			Basis(Vector3.RIGHT, -0.22)
			* Basis(Vector3.BACK, -0.18 * (paar[1] as float)) * lage.basis,
			lage.origin))
	# Absenken: Hüfthöhe messen (Weltraum, nach der Skalierung) und die
	# Differenz zur Sitzfläche vom Knoten abziehen.
	var huefte := skelett.find_bone("Hips")
	if huefte < 0:
		return
	var hueft_welt := (skelett.global_transform
		* skelett.get_bone_global_pose(huefte).origin).y - global_position.y
	position.y -= hueft_welt - sitzhoehe - 0.05


func _passt(name_klein: String, woerter: Array[String]) -> bool:
	for wort in woerter:
		if wort in name_klein:
			return true
	return false


func _toenen() -> void:
	var teile: Array = modell.find_children("*", "MeshInstance3D", true, false)
	# Anzugträger: das Hemd unter dem Jackett bleibt hell.
	var hat_anzug := false
	for kind in teile:
		if "suit" in String(kind.name).to_lower():
			hat_anzug = true
	for kind in teile:
		var teil := kind as MeshInstance3D
		if teil == null or teil.mesh == null:
			continue
		var name_klein := String(teil.name).to_lower()
		var ton := Color.TRANSPARENT
		if _passt(name_klein, _HAAR):
			ton = haar_ton
		elif _passt(name_klein, _OBEN):
			ton = oberteil
		elif _passt(name_klein, _HEMD):
			ton = Color.TRANSPARENT if hat_anzug else oberteil
		elif _passt(name_klein, _UNTEN):
			ton = hose
		if ton == Color.TRANSPARENT:
			continue
		for s in teil.mesh.get_surface_count():
			# Die Materialien hängen an allen Exemplaren desselben Modells —
			# deshalb je Fläche eine Kopie, nie das Original anfassen.
			var material := teil.get_active_material(s) as BaseMaterial3D
			if material == null:
				continue
			var kopie := material.duplicate() as BaseMaterial3D
			kopie.albedo_color = ton
			teil.set_surface_override_material(s, kopie)
