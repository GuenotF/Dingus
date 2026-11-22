class_name SpellData
extends Resource
## Définition d'un sort. Chaque sort est un fichier .tres dans data/spells/,
## modifiable directement dans l'inspecteur de Godot.

enum AreaShape { SINGLE, CROSS }

@export var spell_name: String = "Sort"
@export_range(0, 12) var pa_cost: int = 3
@export_group("Portée")
@export_range(0, 20) var range_min: int = 1
@export_range(0, 20) var range_max: int = 1
@export var needs_line_of_sight: bool = true
@export var line_only: bool = false
@export_group("Effet")
@export var damage_min: int = 10
@export var damage_max: int = 12
@export var area: AreaShape = AreaShape.SINGLE
@export_range(1, 5) var area_size: int = 1
@export_group("Limites")
@export_range(1, 10) var casts_per_turn: int = 2


## Cases touchées si le sort est lancé sur `center`.
func affected_cells(center: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [center]
	if area == AreaShape.CROSS:
		for dist in range(1, area_size + 1):
			for dir in BattleGrid.DIRECTIONS:
				cells.append(center + dir * dist)
	return cells
