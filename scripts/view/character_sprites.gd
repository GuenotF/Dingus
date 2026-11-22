class_name CharacterSprites
extends Resource
## Graphismes animés d'un personnage (data/sprites/*.tres).
## Chaque planche : `frames_per_row` images par ligne, une ligne par direction.
## Seules 4 directions servent sur la grille isométrique (ses diagonales à l'écran).

@export var frame_size: Vector2i = Vector2i(128, 128)
@export var frames_per_row: int = 15
@export_group("Ligne de la planche pour chaque direction")
## Case suivante en x+ (vers le bas à droite de l'écran).
@export var row_down_right: int = 1
## Case suivante en y+ (vers le bas à gauche).
@export var row_down_left: int = 3
## Case suivante en x- (vers le haut à gauche).
@export var row_up_left: int = 5
## Case suivante en y- (vers le haut à droite).
@export var row_up_right: int = 7
@export_group("Placement")
## Position des pieds dans une image (en pixels depuis le coin haut gauche), par défaut.
@export var feet_position: Vector2 = Vector2(64, 100)
## Pieds par direction (la posture change selon l'orientation). (0, 0) = utiliser feet_position.
@export var feet_down_right: Vector2 = Vector2.ZERO
@export var feet_down_left: Vector2 = Vector2.ZERO
@export var feet_up_left: Vector2 = Vector2.ZERO
@export var feet_up_right: Vector2 = Vector2.ZERO
## Hauteur du personnage au-dessus des pieds (pour placer le nom et la barre de PV).
@export var height: float = 74.0
@export var scale: float = 1.0
@export_group("")
@export var animations: Array[CharacterAnimation] = []

const DIRECTIONS := {
	Vector2i(1, 0): "dr",
	Vector2i(0, 1): "dl",
	Vector2i(-1, 0): "ul",
	Vector2i(0, -1): "ur",
}

var _cache: SpriteFrames


static func animation_key(anim_name: String, dir: Vector2i) -> String:
	return "%s_%s" % [anim_name, DIRECTIONS.get(dir, "dr")]


func has_animation(anim_name: String) -> bool:
	for a in animations:
		if a.name == anim_name:
			return true
	return false


func row_for(dir: Vector2i) -> int:
	match dir:
		Vector2i(1, 0):
			return row_down_right
		Vector2i(0, 1):
			return row_down_left
		Vector2i(-1, 0):
			return row_up_left
		_:
			return row_up_right


## Point des pieds dans l'image pour une direction de la grille.
func feet_for(dir: Vector2i) -> Vector2:
	var feet: Vector2
	match dir:
		Vector2i(1, 0):
			feet = feet_down_right
		Vector2i(0, 1):
			feet = feet_down_left
		Vector2i(-1, 0):
			feet = feet_up_left
		_:
			feet = feet_up_right
	return feet if feet != Vector2.ZERO else feet_position


## Construit (une seule fois) les SpriteFrames : une animation par nom et par direction.
func sprite_frames() -> SpriteFrames:
	if _cache:
		return _cache
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim in animations:
		if anim.texture == null:
			continue
		for dir in DIRECTIONS:
			var key := animation_key(anim.name, dir)
			frames.add_animation(key)
			frames.set_animation_speed(key, anim.fps)
			frames.set_animation_loop(key, anim.loop)
			var row := row_for(dir)
			for col in frames_per_row:
				var atlas := AtlasTexture.new()
				atlas.atlas = anim.texture
				atlas.region = Rect2(col * frame_size.x, row * frame_size.y, frame_size.x, frame_size.y)
				frames.add_frame(key, atlas)
	_cache = frames
	return frames
