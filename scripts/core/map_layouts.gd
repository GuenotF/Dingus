class_name MapLayouts
extends RefCounted
## Cartes de test. Plus tard, elles pourront venir de fichiers de données ou de Tiled.

const TEST_SIZE := Vector2i(15, 15)

const TEST_OBSTACLES: Array[Vector2i] = [
	Vector2i(4, 3), Vector2i(4, 4), Vector2i(10, 3),
	Vector2i(7, 6), Vector2i(7, 7), Vector2i(7, 8),
	Vector2i(3, 9), Vector2i(11, 10), Vector2i(10, 10),
	Vector2i(5, 12), Vector2i(12, 6),
]

const TEST_SPAWNS: Array[Vector2i] = [Vector2i(2, 7), Vector2i(12, 7)]
