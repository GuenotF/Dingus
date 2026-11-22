class_name StatusEffect
extends RefCounted
## Bonus ou malus temporaire de PA / PM posé sur un combattant.

var kind: EffectData.Kind
var amount: int
var turns_left: int
var source: String
## Posé pendant le tour de son porteur : ce tour-là ne compte pas dans la durée.
var skip_next_expire: bool


func _init(p_kind: EffectData.Kind, p_amount: int, p_turns: int, p_source: String, p_on_active: bool = false) -> void:
	kind = p_kind
	amount = p_amount
	turns_left = p_turns
	source = p_source
	skip_next_expire = p_on_active


func label() -> String:
	var stat := "PM" if kind == EffectData.Kind.MOD_PM else "PA"
	return "%s%+d (%d)" % [stat, amount, turns_left]
