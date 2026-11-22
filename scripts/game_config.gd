extends Node
## Réglages de la partie choisis dans le menu (autoload « GameConfig »).

const CLASS_PATHS: Array[String] = [
	"res://data/classes/guerrier.tres",
	"res://data/classes/druide.tres",
]

## Carte de combat (scène dessinée dans l'éditeur, voir scripts/map/battle_map.gd).
var map_path: String = "res://maps/demo.tscn"

## Index dans CLASS_PATHS, par joueur.
var player_classes: Array[int] = [0, 1]
## true = ce joueur est contrôlé par l'IA.
var player_is_ai: Array[bool] = [false, true]


func class_for(player: int) -> ClassData:
	return load(CLASS_PATHS[player_classes[player]])
