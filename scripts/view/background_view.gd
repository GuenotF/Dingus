class_name BackgroundView
extends Node2D
## Fond d'écran du combat, derrière la carte. Trois niveaux cumulatifs :
##   1  HALO      dégradé radial teinté par la carte + vignette sur les bords
##   2  SOCLE     + tranche et ombre sous la carte (le plateau « flotte »)
##   3  AMBIANCE  + particules lentes (sable, pollen, lucioles) qui dérivent derrière la carte
## Purement visuel : aucune logique de jeu.

const HALO := 1
const SOCLE := 2
const AMBIANCE := 3

## Niveau d'effets actif (réglable plus tard dans les paramètres).
static var variant := AMBIANCE

const SOCLE_DEPTH := 22.0
## Décalage sous le plateau : les tuiles ont déjà une petite tranche, le socle prend le relais.
const SOCLE_START := 10.0

var _tint := Color("232830")
var _corners := PackedVector2Array() # haut, droite, bas, gauche du plateau


## `grid` : grille de combat ; `map` : fournit la teinte et l'ambiance.
func setup(grid: BattleGrid, map: BattleMap) -> void:
	z_index = -5
	_tint = map.background_color
	var last := Vector2i(grid.width - 1, grid.height - 1)
	_corners = PackedVector2Array([
		Iso.cell_to_world(Vector2i.ZERO) + Vector2(0, -Iso.TILE_H * 0.5),
		Iso.cell_to_world(Vector2i(last.x, 0)) + Vector2(Iso.TILE_W * 0.5, 0),
		Iso.cell_to_world(last) + Vector2(0, Iso.TILE_H * 0.5),
		Iso.cell_to_world(Vector2i(0, last.y)) + Vector2(-Iso.TILE_W * 0.5, 0),
	])

	_build_backdrop()
	if variant >= AMBIANCE:
		_build_particles(map.ambiance, Iso.cell_to_world(last) * 0.5 + Vector2(0, 20))
	queue_redraw()


# --- Dégradé + vignette (en coordonnées d'écran, indépendants de la caméra) --------------

func _build_backdrop() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -100
	add_child(layer)

	var halo := Gradient.new()
	halo.set_color(0, _tint.lightened(0.12))
	halo.set_color(1, _tint.darkened(0.62))
	layer.add_child(_radial_rect(halo, 0.95))

	var vignette := Gradient.new()
	vignette.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	vignette.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.35)])
	layer.add_child(_radial_rect(vignette, 1.0))


func _radial_rect(gradient: Gradient, radius: float) -> TextureRect:
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5 + 0.5 * radius, 0.5)
	tex.width = 256
	tex.height = 256
	var rect := TextureRect.new()
	rect.texture = tex
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


# --- Socle -------------------------------------------------------------------------------

func _draw() -> void:
	if variant < SOCLE or _corners.size() < 4:
		return
	var top := _corners[0]
	var right := _corners[1]
	var bottom := _corners[2]
	var left := _corners[3]
	var down := Vector2(0, SOCLE_DEPTH)
	var start := Vector2(0, SOCLE_START)
	left += start
	bottom += start
	right += start
	var centre := (left + right) * 0.5

	# Ombre portée diffuse : losanges de plus en plus grands, très transparents.
	for i in 7:
		var grow := 1.0 + 0.025 * (i + 1)
		var pts := PackedVector2Array()
		for corner in _corners:
			pts.append(centre + (corner - centre) * grow + down * 1.6 + Vector2(0, i * 1.5))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.09))

	# Tranche : deux faces sous les bords avant du plateau.
	var side := _tint.lightened(0.05)
	draw_colored_polygon(PackedVector2Array([left, bottom, bottom + down, left + down]), side.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([bottom, right, right + down, bottom + down]), side.darkened(0.5))
	# Liseré clair sur l'arête et trait sombre en bas.
	draw_polyline(PackedVector2Array([left, bottom, right]), side.lightened(0.5), 1.5)
	draw_polyline(PackedVector2Array([left + down, bottom + down, right + down]), Color(0, 0, 0, 0.55), 1.5)
	draw_line(bottom, bottom + down, Color(0, 0, 0, 0.35), 1.0)


# --- Particules --------------------------------------------------------------------------

func _build_particles(kind: String, centre: Vector2) -> void:
	if kind == "aucune":
		return
	var img := Image.create(7 if kind == "sable" else 2, 1 if kind == "sable" else 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE) # le sable est tracé en petits traits horizontaux (effet de vent)
	var p := CPUParticles2D.new()
	p.texture = ImageTexture.create_from_image(img)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.position = centre
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1100, 650)
	p.gravity = Vector2.ZERO
	p.local_coords = true

	var ramp := Gradient.new()
	match kind:
		"sable": # grains poussés par le vent, de gauche à droite
			p.amount = 150
			p.lifetime = 11.0
			p.direction = Vector2(1, 0.12)
			p.spread = 10.0
			p.initial_velocity_min = 35.0
			p.initial_velocity_max = 85.0
			p.scale_amount_min = 0.8
			p.scale_amount_max = 1.6
			ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
			ramp.colors = PackedColorArray([Color(0.95, 0.82, 0.6, 0), Color(0.98, 0.86, 0.62, 0.55),
					Color(0.98, 0.86, 0.62, 0.55), Color(0.95, 0.82, 0.6, 0)])
		"pollen": # petites graines qui montent doucement
			p.amount = 70
			p.lifetime = 14.0
			p.direction = Vector2(0.4, -1)
			p.spread = 35.0
			p.initial_velocity_min = 5.0
			p.initial_velocity_max = 16.0
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.2
			ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
			ramp.colors = PackedColorArray([Color(0.95, 0.95, 0.6, 0), Color(0.95, 0.95, 0.6, 0.65),
					Color(0.95, 0.95, 0.6, 0.65), Color(0.95, 0.95, 0.6, 0)])
		_: # lucioles : lentes, qui s'allument et s'éteignent
			p.amount = 45
			p.lifetime = 12.0
			p.direction = Vector2(0, -1)
			p.spread = 180.0
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 10.0
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.0
			var glow := Color(0.7, 1.0, 0.65)
			ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.3, 0.5, 0.7, 0.85, 1.0])
			ramp.colors = PackedColorArray([Color(glow, 0), Color(glow, 0.8), Color(glow, 0.1),
					Color(glow, 0.9), Color(glow, 0.15), Color(glow, 0.7), Color(glow, 0)])
	p.color_ramp = ramp
	p.preprocess = p.lifetime # le décor est déjà « rempli » dès la première image
	p.emitting = true
	add_child(p)
