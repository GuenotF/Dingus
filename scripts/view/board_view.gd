class_name BoardView
extends Node2D
## Dessine le sol et les calques de surbrillance (déplacement, portée, zone, survol).
## Formes temporaires dessinées en code : à remplacer par un TileMapLayer
## quand les graphismes définitifs arriveront.

const COLOR_TILE_A := Color("3d5a45")
const COLOR_TILE_B := Color("456650")
const COLOR_TILE_EDGE := Color(0, 0, 0, 0.25)
const COLOR_HOVER := Color(1, 1, 1, 0.9)
const COLOR_GRID_LINE := Color(0, 0, 0, 0.16)

# Couleurs prêtes à l'emploi pour les calques
const COLOR_REACHABLE := Color(0.35, 0.75, 1.0, 0.35)
const COLOR_PATH := Color(0.45, 0.9, 1.0, 0.75)
const COLOR_RANGE := Color(0.3, 0.55, 1.0, 0.45)
const COLOR_NO_LOS := Color(0.6, 0.6, 0.6, 0.30)
const COLOR_AREA := Color(1.0, 0.45, 0.2, 0.70)

var grid: BattleGrid
## false quand le sol vient d'une carte (TileMapLayer) : on ne dessine alors qu'un quadrillage discret.
var draw_ground := true
## Chaque calque : { "cells": Array[Vector2i], "color": Color, "shrink": float }
var layers: Array[Dictionary] = []
var hover_cell := Vector2i(-1, -1)
var hover_color := COLOR_HOVER

var _flash_cells: Array[Vector2i] = []
var _flash_amount := 0.0:
	set(value):
		_flash_amount = value
		queue_redraw()


func setup(p_grid: BattleGrid) -> void:
	grid = p_grid
	queue_redraw()


func set_layers(p_layers: Array[Dictionary], p_hover: Vector2i, p_hover_color: Color = COLOR_HOVER) -> void:
	layers = p_layers
	hover_cell = p_hover
	hover_color = p_hover_color
	queue_redraw()


static func layer(cells: Array, color: Color, shrink: float = 3.0) -> Dictionary:
	return {"cells": cells, "color": color, "shrink": shrink}


## Éclair sur les cases touchées par un sort.
func flash(cells: Array[Vector2i]) -> void:
	_flash_cells = cells
	_flash_amount = 1.0
	var tween := create_tween()
	tween.tween_property(self, "_flash_amount", 0.0, 0.45)


func _draw() -> void:
	if grid == null:
		return
	for y in grid.height:
		for x in grid.width:
			var cell := Vector2i(x, y)
			var poly := Iso.diamond(Iso.cell_to_world(cell))
			if draw_ground:
				var color := COLOR_TILE_A if (x + y) % 2 == 0 else COLOR_TILE_B
				draw_colored_polygon(poly, color)
				draw_polyline(_closed(poly), COLOR_TILE_EDGE, 1.0, true)
			elif not grid.is_obstacle(cell) and not grid.is_water(cell):
				draw_polyline(_closed(poly), COLOR_GRID_LINE, 1.0, true)

	for l in layers:
		for cell in l.cells:
			draw_colored_polygon(Iso.diamond(Iso.cell_to_world(cell), l.shrink), l.color)

	if _flash_amount > 0.0:
		for cell in _flash_cells:
			if grid.is_inside(cell):
				draw_colored_polygon(Iso.diamond(Iso.cell_to_world(cell)), Color(1, 0.95, 0.7, 0.8 * _flash_amount))

	if grid.is_inside(hover_cell):
		var hover_poly := Iso.diamond(Iso.cell_to_world(hover_cell), 1.0)
		draw_polyline(_closed(hover_poly), hover_color, 2.0, true)


func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var closed := poly.duplicate()
	closed.append(poly[0])
	return closed
