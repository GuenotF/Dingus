extends SceneTree
## Génère les images de Kael dessinées par le code : effets dorés (planches d'une ligne),
## icônes de sorts (provisoires) et portrait rond tiré de la planche Idle.
##   godot --headless --path . -s res://tools/build_kael_assets.gd

const FRAMES := 15
const SIZE := 128
const ICON := 96
const GOLD := Color(1.0, 0.78, 0.25)
const LIGHT := Color(1.0, 0.96, 0.78)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/effects/holy")
	_sheet("eclat", _eclat)
	_sheet("lien", _lien)
	_sheet("halo", _halo)
	_sheet("egide", _egide)
	_icon("kael_chatiment", _icon_chatiment)
	_icon("kael_entrave", _icon_entrave)
	_icon("kael_imposition", _icon_imposition)
	_icon("kael_bouclier", _icon_bouclier)
	_portrait()
	quit()


# --- Outils de dessin : chaque forme renvoie une intensité de 0 à 1 --------------

static func _soft(d: float, width: float) -> float:
	return clampf(1.0 - d / width, 0.0, 1.0)


static func _ring(p: Vector2, center: Vector2, radius: float, width: float) -> float:
	return _soft(absf(p.distance_to(center) - radius), width)


static func _segment(p: Vector2, a: Vector2, b: Vector2, width: float) -> float:
	return _soft(p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)), width)


## Intensité -> couleur : or sur les bords, presque blanc au cœur.
static func _glow(v: float, fade: float) -> Color:
	var c := GOLD.lerp(LIGHT, clampf(v * 1.4 - 0.4, 0.0, 1.0))
	c.a = clampf(v * 1.5, 0.0, 1.0) * fade
	return c


func _sheet(file: String, shape: Callable) -> void:
	var img := Image.create(SIZE * FRAMES, SIZE, false, Image.FORMAT_RGBA8)
	for i in FRAMES:
		var t := i / float(FRAMES - 1)
		for y in SIZE:
			for x in SIZE:
				img.set_pixel(i * SIZE + x, y, shape.call(Vector2(x, y), t))
	img.save_png("res://assets/effects/holy/%s.png" % file)


## Châtiment : éclat de lumière à huit branches et onde qui s'élargit.
func _eclat(p: Vector2, t: float) -> Color:
	var c := Vector2(64, 64)
	var v := _ring(p, c, 8.0 + 46.0 * t, 7.0) * 0.8
	for k in 8:
		var dir := Vector2.from_angle(k * TAU / 8.0)
		var length := (56.0 if k % 2 == 0 else 34.0) * minf(1.0, t * 2.5)
		v = maxf(v, _segment(p, c + dir * 6.0, c + dir * length, 5.0 * (1.0 - t * 0.6)))
	v = maxf(v, _soft(p.distance_to(c), 22.0 * (1.0 - t)))
	return _glow(v, 1.0 - t * t)


## Entrave : cercle de maillons qui se resserre au sol.
func _lien(p: Vector2, t: float) -> Color:
	var c := Vector2(64, 64)
	var radius := lerpf(58.0, 34.0, minf(1.0, t * 1.8))
	var v := _ring(p, c, radius, 3.5)
	for k in 10:
		var link := c + Vector2.from_angle(k * TAU / 10.0 + t * 1.2) * radius
		v = maxf(v, _ring(p, link, 7.0, 3.0))
	v = maxf(v, _ring(p, c, radius * 0.6, 2.5) * 0.7)
	return _glow(v, clampf((1.0 - t) * 3.0, 0.0, 1.0))


## Imposition des mains : anneaux qui montent et étincelles en croix.
func _halo(p: Vector2, t: float) -> Color:
	var v := 0.0
	for k in 3:
		var u := t * 1.4 - k * 0.2
		if u < 0.0 or u > 1.0:
			continue
		var q := Vector2(p.x, (p.y - (104.0 - 70.0 * u)) * 2.6 + 64.0) # anneau aplati
		v = maxf(v, _ring(q, Vector2(64, 64), 30.0, 7.0) * (1.0 - u * 0.5))
	for k in 6:
		var s := Vector2(36.0 + (k * 23) % 58, 108.0 - fmod(t * 90.0 + k * 17.0, 90.0))
		v = maxf(v, maxf(_segment(p, s - Vector2(5, 0), s + Vector2(5, 0), 2.5), _segment(p, s - Vector2(0, 5), s + Vector2(0, 5), 2.5)))
	return _glow(v, clampf((1.0 - t) * 3.0, 0.0, 1.0))


## Bouclier de la foi : écu lumineux qui grandit puis s'efface.
func _egide(p: Vector2, t: float) -> Color:
	var grow := 0.6 + 0.5 * minf(1.0, t * 2.0)
	var d := _shield_distance((p - Vector2(64, 64)) / grow + Vector2(64, 64))
	var v := maxf(_soft(absf(d), 6.0), 0.35 if d < 0.0 else 0.0)
	return _glow(v, 0.85 * (1.0 - t * t))


## Distance signée à un écu centré en (64, 64) (négative à l'intérieur).
static func _shield_distance(p: Vector2) -> float:
	var points := PackedVector2Array([Vector2(36, 30), Vector2(92, 30), Vector2(90, 66), Vector2(78, 86),
		Vector2(64, 100), Vector2(50, 86), Vector2(38, 66)])
	var best := INF
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return -best if Geometry2D.is_point_in_polygon(p, points) else best


# --- Icônes (fond sombre bleu nuit, motif doré) ---------------------------------

func _icon(file: String, shape: Callable) -> void:
	var img := Image.create(ICON, ICON, false, Image.FORMAT_RGBA8)
	for y in ICON:
		for x in ICON:
			var p := Vector2(x, y) * (float(SIZE) / ICON)
			var back := Color(0.2, 0.16, 0.3).lerp(Color(0.05, 0.05, 0.1), clampf(p.distance_to(Vector2(64, 64)) / 80.0, 0.0, 1.0))
			var v: float = shape.call(p)
			var color := back.blend(_glow(v, 1.0))
			color.a = 1.0
			img.set_pixel(x, y, color)
	img.save_png("res://assets/ui/spells/%s.png" % file)


## Marteau de guerre qui frappe, avec des rayons.
func _icon_chatiment(p: Vector2) -> float:
	var v := _segment(p, Vector2(28, 104), Vector2(74, 54), 9.0)
	v = maxf(v, _segment(p, Vector2(60, 36), Vector2(94, 70), 20.0))
	for k in 5:
		var dir := Vector2.from_angle(-PI * 0.75 + k * PI / 8.0)
		v = maxf(v, _segment(p, Vector2(78, 50) + dir * 28.0, Vector2(78, 50) + dir * 48.0, 4.0))
	return v


## Deux cercles de maillons autour d'un point.
func _icon_entrave(p: Vector2) -> float:
	var v := _ring(p, Vector2(64, 64), 40.0, 5.0)
	for k in 8:
		v = maxf(v, _ring(p, Vector2(64, 64) + Vector2.from_angle(k * TAU / 8.0) * 40.0, 11.0, 4.5))
	return maxf(v, _soft(p.distance_to(Vector2(64, 64)), 18.0))


## Grande croix de soin entourée d'un halo.
func _icon_imposition(p: Vector2) -> float:
	var v := maxf(_segment(p, Vector2(64, 36), Vector2(64, 92), 14.0), _segment(p, Vector2(36, 64), Vector2(92, 64), 14.0))
	return maxf(v, _ring(p, Vector2(64, 64), 48.0, 5.0) * 0.8)


## Écu avec une croix.
func _icon_bouclier(p: Vector2) -> float:
	var d := _shield_distance(p)
	var v := maxf(_soft(absf(d), 7.0), 0.28 if d < 0.0 else 0.0)
	v = maxf(v, _segment(p, Vector2(64, 44), Vector2(64, 82), 7.0))
	return maxf(v, _segment(p, Vector2(50, 57), Vector2(78, 57), 7.0))


# --- Portrait -------------------------------------------------------------------

## Tête et épaules : frame 0 de l'Idle, orientation bas-gauche (ligne 3), détourées en rond.
func _portrait() -> void:
	var sheet := Image.load_from_file("res://assets/characters/kael/idle.png")
	sheet.convert(Image.FORMAT_RGBA8)
	var face := sheet.get_region(Rect2i(46, 3 * 128 + 36, 31, 31))
	face.resize(88, 88, Image.INTERPOLATE_LANCZOS)
	for y in 88:
		for x in 88:
			var inside := clampf(44.0 - Vector2(x + 0.5, y + 0.5).distance_to(Vector2(44, 44)), 0.0, 1.0)
			var c := face.get_pixel(x, y)
			c.a *= inside
			face.set_pixel(x, y, c)
	face.save_png("res://assets/ui/portraits/kael.png")
