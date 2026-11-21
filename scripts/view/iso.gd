class_name Iso
extends RefCounted
## Conversions entre coordonnées de grille et position à l'écran (losanges 2:1).
## Quand tu passeras à de vrais graphismes, garde les mêmes dimensions de tuile
## (ou change-les ici seulement).

const TILE_W := 64.0
const TILE_H := 32.0


## Centre de la case à l'écran (dans le repère du plateau).
static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE_W * 0.5, (cell.x + cell.y) * TILE_H * 0.5)


## Case située sous un point de l'écran (dans le repère du plateau).
static func world_to_cell(pos: Vector2) -> Vector2i:
	var fx := pos.x / (TILE_W * 0.5)
	var fy := pos.y / (TILE_H * 0.5)
	return Vector2i(roundi((fy + fx) * 0.5), roundi((fy - fx) * 0.5))


## Sommets du losange d'une case (haut, droite, bas, gauche).
static func diamond(center: Vector2, shrink: float = 0.0) -> PackedVector2Array:
	var hw := TILE_W * 0.5 - shrink
	var hh := TILE_H * 0.5 - shrink * 0.5
	return PackedVector2Array([
		center + Vector2(0, -hh),
		center + Vector2(hw, 0),
		center + Vector2(0, hh),
		center + Vector2(-hw, 0),
	])
