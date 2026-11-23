class_name TouchCamera
extends Camera2D
## Caméra du combat en mode mobile : un doigt glissé déplace la carte, deux doigts pincés zooment.
## Un toucher bref sans glisser est transmis comme un tap (signal `tapped`) : c'est lui qui joue.
## Les touchers sur l'interface (boutons, sorts) sont pris par l'interface et n'arrivent pas ici.

## Tap sur la carte, en coordonnées de l'écran (viewport).
signal tapped(screen_pos: Vector2)

## Au-delà de ce déplacement (unités d'écran), le toucher devient un glissement et non plus un tap.
const TAP_SLOP := 16.0
## Place laissée en bas pour la barre de sorts et autour du plateau, au zoom d'origine.
const HUD_SPACE := 110.0
const MARGIN := 40.0
## Zoom maximal (1 = taille du plateau sur PC).
const MAX_ZOOM := 2.6

var _bounds := Rect2() # rectangle du plateau dans le monde
var _fit_zoom := 1.0
var _touches: Dictionary = {} # index du doigt -> position à l'écran
var _moved := 0.0
var _gesture := false # deux doigts posés pendant ce toucher : pas de tap à la fin
var _pinch_dist := 0.0
var _pinch_mid := Vector2.ZERO


## `bounds` : rectangle du plateau dans le repère du monde.
func setup(bounds: Rect2) -> void:
	_bounds = bounds
	get_viewport().size_changed.connect(fit)
	fit()


## Zoom et position d'origine : tout le plateau visible, au-dessus de la barre de sorts.
func fit() -> void:
	var view := get_viewport_rect().size
	var need := _bounds.size + Vector2(MARGIN, MARGIN) * 2.0
	_fit_zoom = minf(view.x / need.x, (view.y - HUD_SPACE) / need.y)
	zoom = Vector2.ONE * _fit_zoom
	position = _bounds.get_center() + Vector2(0, HUD_SPACE * 0.5 / _fit_zoom)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_moved = 0.0
				_gesture = false
			else:
				_gesture = true
				_start_pinch()
		else:
			_touches.erase(event.index)
			if _touches.is_empty():
				if not _gesture and _moved < TAP_SLOP:
					tapped.emit(event.position)
			elif _touches.size() >= 2:
				_start_pinch()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if not _touches.has(event.index):
			return
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_moved += event.relative.length()
			if _moved >= TAP_SLOP:
				_pan(event.relative)
		else:
			_update_pinch()
		get_viewport().set_input_as_handled()


func _two() -> Array:
	var keys := _touches.keys()
	keys.sort()
	return [_touches[keys[0]], _touches[keys[1]]]


func _start_pinch() -> void:
	var p := _two()
	_pinch_dist = maxf((p[0] as Vector2).distance_to(p[1]), 1.0)
	_pinch_mid = (p[0] + p[1]) * 0.5


func _update_pinch() -> void:
	var p := _two()
	var dist := maxf((p[0] as Vector2).distance_to(p[1]), 1.0)
	var mid: Vector2 = (p[0] + p[1]) * 0.5
	# Le point du monde sous les doigts reste sous les doigts.
	var anchor := _screen_to_world(_pinch_mid)
	var z := clampf(zoom.x * dist / _pinch_dist, _fit_zoom * 0.8, maxf(MAX_ZOOM, _fit_zoom))
	zoom = Vector2.ONE * z
	position = anchor - (mid - get_viewport_rect().size * 0.5) / z
	_pinch_dist = dist
	_pinch_mid = mid
	_clamp()


func _pan(screen_delta: Vector2) -> void:
	position -= screen_delta / zoom.x
	_clamp()


func _screen_to_world(p: Vector2) -> Vector2:
	return position + (p - get_viewport_rect().size * 0.5) / zoom.x


## Le centre de l'écran reste au-dessus du plateau : impossible de perdre la carte.
func _clamp() -> void:
	var r := _bounds.grow(MARGIN)
	position = position.clamp(r.position, r.end + Vector2(0, HUD_SPACE / zoom.x))
