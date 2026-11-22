class_name CharacterAnimation
extends Resource
## Une animation d'un personnage : une planche où chaque ligne est une direction
## et chaque colonne une image.

## Nom utilisé par le jeu : idle, walk, hit, die, ou le nom donné dans un sort (melee, kick...).
@export var name: String = "idle"
@export var texture: Texture2D
@export var fps: float = 15.0
@export var loop: bool = false
