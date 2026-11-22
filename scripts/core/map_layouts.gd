class_name MapLayouts
extends RefCounted
## Carte de test en code, utilisée par les tests et le simulateur d'équilibrage.
## En jeu, la carte vient d'une scène dessinée dans l'éditeur (maps/demo.tscn),
## dont les obstacles et les zones reprennent exactement ceux-ci.

const TEST_SIZE := Vector2i(15, 15)

const TEST_OBSTACLES: Array[Vector2i] = [
	Vector2i(4, 3), Vector2i(4, 4), Vector2i(10, 3),
	Vector2i(7, 6), Vector2i(7, 7), Vector2i(7, 8),
	Vector2i(3, 9), Vector2i(11, 10), Vector2i(10, 10),
	Vector2i(5, 12), Vector2i(12, 6),
]

## Case de départ par défaut de chaque équipe (doit appartenir à sa zone de placement).
const TEST_SPAWNS: Array[Vector2i] = [Vector2i(2, 7), Vector2i(12, 7)]

## Cases où chaque équipe peut se placer avant le combat.
const TEST_PLACEMENT: Array = [
	[Vector2i(1, 5), Vector2i(2, 5), Vector2i(2, 7), Vector2i(3, 7), Vector2i(1, 8), Vector2i(2, 9)],
	[Vector2i(13, 5), Vector2i(12, 5), Vector2i(12, 7), Vector2i(11, 7), Vector2i(13, 8), Vector2i(12, 9)],
]
