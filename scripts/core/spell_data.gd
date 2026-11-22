class_name SpellData
extends Resource
## Définition d'un sort (data/spells/*.tres), modifiable dans l'inspecteur de Godot.
## Le comportement vient de la liste `effects` : on combine des effets sans écrire de code.

enum AreaShape { SINGLE, CROSS }
enum TargetRule {
	ANY, ## N'importe quelle case.
	EMPTY, ## Case libre uniquement (ex. bond).
	FIGHTER, ## Case occupée par un combattant uniquement.
}

@export var spell_name: String = "Sort"
@export_range(0, 12) var pa_cost: int = 3
## Animation jouée par le lanceur (si sa classe a des sprites) : melee, kick, jump, cast...
@export var animation: String = "cast"
@export_group("Portée")
@export_range(0, 20) var range_min: int = 1
@export_range(0, 20) var range_max: int = 1
@export var needs_line_of_sight: bool = true
@export var line_only: bool = false
@export var target_rule: TargetRule = TargetRule.ANY
@export_group("Zone")
@export var area: AreaShape = AreaShape.SINGLE
@export_range(1, 5) var area_size: int = 1
## false : le lanceur n'est jamais touché par sa propre zone (ex. Nova autour de soi).
@export var affects_caster: bool = true
@export_group("Effets")
@export var effects: Array[EffectData] = []
@export_group("Visuel")
## Icône de la barre de sorts (SVG ou image, dessinée en clair sur fond sombre).
@export var icon: Texture2D
## Projectile lancé vers la cible (EffectAnimation, optionnel).
@export var projectile: Resource
## Effet joué sur la case ciblée au moment de l'impact (EffectAnimation, optionnel).
@export var impact: Resource
## Délai (s) entre le début de l'animation du lanceur et le départ du projectile / l'impact.
@export var cast_delay: float = 0.3
@export_group("Limites")
@export_range(1, 10) var casts_per_turn: int = 2
## Nombre de tours avant de pouvoir relancer (0 = pas de recharge).
@export_range(0, 10) var cooldown: int = 0


## Cases touchées si le sort est lancé sur `center`.
func affected_cells(center: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [center]
	if area == AreaShape.CROSS:
		for dist in range(1, area_size + 1):
			for dir in BattleGrid.DIRECTIONS:
				cells.append(center + dir * dist)
	return cells


func describe() -> String:
	var parts: Array[String] = []
	if range_max == 0:
		parts.append("sur soi")
	elif range_min == range_max:
		parts.append("portée %d" % range_max)
	else:
		parts.append("portée %d-%d" % [range_min, range_max])
	for e in effects:
		parts.append(e.describe())
	if area == AreaShape.CROSS:
		parts.append("zone en croix" if affects_caster or range_max > 0 else "autour de soi")
	if line_only:
		parts.append("en ligne")
	if not needs_line_of_sight and range_max > 0:
		parts.append("sans ligne de vue")
	parts.append("%d/tour" % casts_per_turn)
	if cooldown > 0:
		parts.append("recharge %d" % cooldown)
	return "  ·  ".join(parts)
