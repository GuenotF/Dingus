class_name ObstacleView
extends Node2D
## Bloc en relief (cube isométrique) posé sur une case.
## Son origine est au centre de la case pour que le Y-sort fonctionne.

const HEIGHT := 28.0
const COLOR_TOP := Color("8a8f98")
const COLOR_LEFT := Color("5d626b")
const COLOR_RIGHT := Color("6f747d")


func _draw() -> void:
	var base := Iso.diamond(Vector2.ZERO, 2.0) # haut, droite, bas, gauche
	var up := Vector2(0, -HEIGHT)
	var top := PackedVector2Array([base[0] + up, base[1] + up, base[2] + up, base[3] + up])
	draw_colored_polygon(PackedVector2Array([base[3], base[2], base[2] + up, base[3] + up]), COLOR_LEFT)
	draw_colored_polygon(PackedVector2Array([base[2], base[1], base[1] + up, base[2] + up]), COLOR_RIGHT)
	draw_colored_polygon(top, COLOR_TOP)
