class_name EffectData
extends Resource
## Un effet élémentaire de sort. Un sort applique sa liste d'effets, dans l'ordre,
## à chaque combattant présent dans sa zone.

enum Kind {
	DAMAGE, ## Retire min..max PV.
	HEAL, ## Rend min..max PV (sans dépasser le maximum).
	PUSH, ## Éloigne la cible du lanceur de `min_value` cases. Collision = dégâts.
	PULL, ## Rapproche la cible du lanceur de `min_value` cases.
	DASH, ## Le lanceur bondit sur la case ciblée (qui doit être libre).
	MOD_PM, ## Ajoute min..max PM (négatif = retrait) pendant `duration` tours.
	MOD_PA, ## Ajoute min..max PA (négatif = retrait) pendant `duration` tours.
}

@export var kind: Kind = Kind.DAMAGE
@export var min_value: int = 10
@export var max_value: int = 10
## Pour MOD_PM / MOD_PA : nombre de débuts de tour de la cible affectés.
## Si la cible est le combattant actif, l'effet s'applique aussi tout de suite.
@export_range(0, 10) var duration: int = 0


const SAME_AS_MIN := -9999


## Raccourci pour créer un effet en code (tests, outils). max omis = même valeur que min.
static func make(p_kind: Kind, p_min: int, p_max: int = SAME_AS_MIN, p_duration: int = 0) -> EffectData:
	var e := EffectData.new()
	e.kind = p_kind
	e.min_value = p_min
	e.max_value = p_min if p_max == SAME_AS_MIN else p_max
	e.duration = p_duration
	return e


func average() -> float:
	return (min_value + max_value) * 0.5


func describe() -> String:
	var amount := str(min_value) if min_value == max_value else "%d-%d" % [min_value, max_value]
	match kind:
		Kind.DAMAGE:
			return "%s dégâts" % amount
		Kind.HEAL:
			return "soin %s" % amount
		Kind.PUSH:
			return "pousse de %d" % min_value
		Kind.PULL:
			return "attire de %d" % min_value
		Kind.DASH:
			return "bond"
		Kind.MOD_PM:
			return "%+d PM (%d t.)" % [min_value, duration]
		Kind.MOD_PA:
			return "%+d PA (%d t.)" % [min_value, duration]
	return ""
