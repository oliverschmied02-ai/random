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
