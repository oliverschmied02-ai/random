class_name DartsConfig
extends RefCounted

## Alle Regelwerte des Minispiels an einer Stelle.
##
## Wer die Schwierigkeit ändern will, ändert sie hier — im Spielcode steht
## keine einzige dieser Zahlen ein zweites Mal.

## So viele Masken fallen in einer Runde. Sind alle unten oder abgeworfen,
## endet die Runde.
const MASKEN_PRO_RUNDE: int = 10

## So viele Treffer gewinnen die Runde.
const TREFFER_ZIEL: int = 5

## Punkte für eine abgeworfene Maske.
const MASKEN_PUNKTE: int = 20

## Punktzahl, ab der die Runde als geschafft gilt — genau TREFFER_ZIEL
## abgeworfene Masken. (Als Punktzahl gehalten, damit Anzeige und
## Prüfläufe weiter mit `punkte` arbeiten können.)
const ZIELPUNKTZAHL: int = TREFFER_ZIEL * MASKEN_PUNKTE

## Trefferradius um die Maskenmitte, in Metern. Großzügig — die Maske
## bewegt sich schließlich.
const MASKEN_RADIUS: float = 0.34

## Ab dieser Punktzahl gilt ein Wurf als richtig guter Treffer — stärkere
## Rückmeldung, mehr Partikel, kräftigeres Wackeln.
const GUTER_TREFFER: int = 20

## Wie viele Spritzen sichtbar auf der Stehtonne bereitliegen. Reine
## Ausstattung — geworfen werden darf unbegrenzt, der Vorrat füllt sich
## nach (Oliver legt nach).
const VORRAT_SPRITZEN: int = 5


## Text für die Trefferanzeige. Danebengeworfen wird nicht bestraft, nur
## freundlich kommentiert.
static func treffer_text(punkte: int) -> String:
	if punkte >= GUTER_TREFFER:
		return "GETROFFEN! +%d" % punkte
	if punkte > 0:
		return "+%d" % punkte
	return "daneben"
