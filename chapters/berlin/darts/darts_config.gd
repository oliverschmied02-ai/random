class_name DartsConfig
extends RefCounted

## Alle Regelwerte des Minispiels an einer Stelle.
##
## Wer die Schwierigkeit ändern will, ändert sie hier — im Spielcode steht
## keine einzige dieser Zahlen ein zweites Mal.

## Würfe pro Runde.
const WUERFE_PRO_RUNDE: int = 5

## Punktzahl, ab der die Runde als geschafft gilt.
const ZIELPUNKTZAHL: int = 60

## Radius der Scheibe in Metern. Etwas größer als eine echte Dartscheibe
## (0,226 m) — das Spiel soll gutmütig sein.
const SCHEIBEN_RADIUS: float = 0.30

## Ringe von innen nach außen: [Radius in Metern, Punkte].
##
## Die Wertung ist bewusst freundlich: Wer überhaupt trifft, bekommt Punkte,
## und fünf mittelmäßige Würfe reichen für die Zielpunktzahl.
const RINGE: Array = [
	[0.024, 50],
	[0.054, 25],
	[0.105, 20],
	[0.165, 15],
	[0.225, 10],
	[0.300, 5],
]

## Ab dieser Punktzahl gilt ein Wurf als richtig guter Treffer — stärkere
## Rückmeldung, mehr Partikel, kräftigeres Wackeln.
const GUTER_TREFFER: int = 25


## Punkte für einen Treffer im Abstand `radius` von der Scheibenmitte.
static func punkte_fuer_radius(radius: float) -> int:
	for ring in RINGE:
		if radius <= float(ring[0]):
			return int(ring[1])
	return 0


## Text für die Trefferanzeige. Danebengeworfen wird nicht bestraft, nur
## freundlich kommentiert.
static func treffer_text(punkte: int) -> String:
	if punkte >= 50:
		return "VOLLTREFFER!"
	if punkte >= GUTER_TREFFER:
		return "+%d!" % punkte
	if punkte > 0:
		return "+%d" % punkte
	return "daneben"
