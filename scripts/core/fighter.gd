class_name Fighter
extends RefCounted
## Données d'un combattant. Logique pure, sans affichage.

var id: int
var display_name: String
var team: int
var cell: Vector2i
var class_data: ClassData

var max_hp: int = 100
var hp: int = 100
var max_pa: int = 6
var pa: int = 6
var max_pm: int = 3
var pm: int = 3

var spells: Array[SpellData] = []
var statuses: Array[StatusEffect] = []
var _casts_this_turn: Dictionary = {} # SpellData -> nombre de lancers
var _cooldowns: Dictionary = {} # SpellData -> tours restants


func _init(p_id: int, p_name: String, p_team: int, p_cell: Vector2i, p_class: ClassData = null) -> void:
	id = p_id
	display_name = p_name
	team = p_team
	cell = p_cell
	class_data = p_class
	if p_class:
		max_hp = p_class.max_hp
		hp = max_hp
		max_pa = p_class.max_pa
		pa = max_pa
		max_pm = p_class.max_pm
		pm = max_pm
		spells = p_class.spells.duplicate()


func preferred_range() -> int:
	return class_data.preferred_range if class_data else 1


## Début du tour de ce combattant : recharge PA/PM (bonus et malus compris)
## et fait avancer les recharges de sorts.
func start_turn() -> void:
	pa = maxi(0, max_pa + status_total(EffectData.Kind.MOD_PA))
	pm = maxi(0, max_pm + status_total(EffectData.Kind.MOD_PM))
	_casts_this_turn.clear()
	for spell in _cooldowns.keys():
		_cooldowns[spell] -= 1
		if _cooldowns[spell] <= 0:
			_cooldowns.erase(spell)


## Fin du tour de ce combattant : les statuts vieillissent. Ils restent donc affichés
## pendant tout le tour qu'ils affectent.
func end_turn() -> void:
	for s in statuses:
		if s.skip_next_expire:
			s.skip_next_expire = false
		else:
			s.turns_left -= 1
	statuses = statuses.filter(func(s: StatusEffect) -> bool: return s.turns_left > 0)


func status_total(kind: EffectData.Kind) -> int:
	var total := 0
	for s in statuses:
		if s.kind == kind:
			total += s.amount
	return total


func is_alive() -> bool:
	return hp > 0


func casts_this_turn(spell: SpellData) -> int:
	return _casts_this_turn.get(spell, 0)


func cooldown_left(spell: SpellData) -> int:
	return _cooldowns.get(spell, 0)


func register_cast(spell: SpellData) -> void:
	pa -= spell.pa_cost
	_casts_this_turn[spell] = casts_this_turn(spell) + 1
	if spell.cooldown > 0:
		_cooldowns[spell] = spell.cooldown


## Applique des dégâts et renvoie les dégâts réellement subis.
func take_damage(amount: int) -> int:
	var dealt := clampi(amount, 0, hp)
	hp -= dealt
	return dealt


## Soigne et renvoie les PV réellement rendus.
func heal(amount: int) -> int:
	var healed := clampi(amount, 0, max_hp - hp)
	hp += healed
	return healed
