class_name BoardView
extends Node2D
## Dessine le sol et les surbrillances (zone de déplacement, chemin, survol).
## Formes temporaires dessinées en code : à remplacer par un TileMapLayer
## quand les graphismes définitifs arriveront.

const COLOR_TILE_A := Color("3d5a45")
const COLOR_TILE_B := Color("456650")
const COLOR_TILE_EDGE := Color(0, 0, 0, 0.25)
const COLOR_REACHABLE := Color(0.35, 0.75, 1.0, 0.35)
const COLOR_PATH := Color(0.45, 0.9, 1.0, 0.75)
const COLOR_HOVER := Color(1, 1, 1, 0.9)

var grid: BattleGrid
var reachable: Dictionary = {}
var path: Array[Vector2i] = []
var hover_cell := Vector2i(-1, -1)


func setup(p_grid: BattleGrid) -> void:
	grid = p_grid
	queue_redraw()


func set_highlights(p_reachable: Dictionary, p_path: Array[Vector2i], p_hover: Vector2i) -> void:
	reachable = p_reachable
	path = p_path
	hover_cell = p_hover
	queue_redraw()


func _draw() -> void:
	if grid == null:
		return
	for y in grid.height:
		for x in grid.width:
			var cell := Vector2i(x, y)
			var center := Iso.cell_to_world(cell)
			var poly := Iso.diamond(center)
			var color := COLOR_TILE_A if (x + y) % 2 == 0 else COLOR_TILE_B
			draw_colored_polygon(poly, color)
			draw_polyline(_closed(poly), COLOR_TILE_EDGE, 1.0, true)

	for cell in reachable:
		draw_colored_polygon(Iso.diamond(Iso.cell_to_world(cell), 3.0), COLOR_REACHABLE)

	for cell in path:
		draw_colored_polygon(Iso.diamond(Iso.cell_to_world(cell), 6.0), COLOR_PATH)

	if grid.is_inside(hover_cell):
		var hover_poly := Iso.diamond(Iso.cell_to_world(hover_cell), 1.0)
		draw_polyline(_closed(hover_poly), COLOR_HOVER, 2.0, true)


func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var closed := poly.duplicate()
	closed.append(poly[0])
	return closed
