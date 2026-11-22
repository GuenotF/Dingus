class_name HudWidgets
extends RefCounted
## Éléments dessinés de l'interface de combat : orbe de PV, compteurs PA / PM,
## cases de sorts, vignettes de l'ordre de jeu. Couleurs communes dans les constantes.

const PANEL_BG := Color(0.07, 0.08, 0.10, 0.92)
const PANEL_BORDER := Color("3a3f4b")
const GOLD := Color("d9a441")
const TEXT := Color("efe6d2")
const TEXT_DIM := Color("a99f8a")
const HP := Color("b8423e")
const HP_BG := Color("2a1414")
const PA := Color("4f9be8")
const PA_TEXT := Color("cfe4fb")
const PM := Color("5bc47a")
const PM_TEXT := Color("d2f2db")
const COST_BADGE := Color("2b5d94")
const COST_BADGE_BAD := Color("8c3a36")
const DAMAGE := Color("f08a6a")
const TEAM_COLORS: Array[Color] = [Color("e35d5b"), Color("4f9be8")]


static func panel_style(border: Color = PANEL_BORDER, radius: int = 14, padding: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(padding)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	return sb


static func font() -> Font:
	return ThemeDB.fallback_font


## Texte centré sur `center` (verticalement approximatif : la ligne de base est ajustée).
static func draw_text_centered(ci: CanvasItem, center: Vector2, text: String, size: int, color: Color, outline: int = 0) -> void:
	var f := font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := center + Vector2(-w * 0.5, size * 0.35)
	if outline > 0:
		ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0, 0, 0, 0.8))
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func star_points(center: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var r := outer if i % 2 == 0 else inner
		var a := -PI * 0.5 + i * PI / 5.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


## Icône PA (étoile) ou PM (deux pas), pour que la ressource se lise aussi sans la couleur.
static func draw_resource_icon(ci: CanvasItem, center: Vector2, is_pa: bool, size: float = 20.0) -> void:
	if is_pa:
		ci.draw_colored_polygon(star_points(center, size * 0.5, size * 0.22), PA)
	else:
		for offset in [Vector2(-size * 0.15, -size * 0.15), Vector2(size * 0.15, size * 0.15)]:
			ci.draw_set_transform(center + offset, 0.0, Vector2(0.62, 1.0))
			ci.draw_circle(Vector2.ZERO, size * 0.21, PM)
		ci.draw_set_transform(Vector2.ZERO)


## Style de bouton des menus (pause, paramètres, icônes rondes).
static func button_box(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(8)
	return sb


## Bouton de menu. `accent` : plein doré (action principale), sinon sombre à liseré.
static func menu_button(text: String, accent: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 46)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 19)
	var normal := GOLD if accent else Color("1b1f27")
	var hover := GOLD.lightened(0.15) if accent else Color("2a303c")
	var pressed := GOLD.darkened(0.15) if accent else Color("14171d")
	var border := GOLD if accent else PANEL_BORDER
	b.add_theme_stylebox_override("normal", button_box(normal, border, 10))
	b.add_theme_stylebox_override("hover", button_box(hover, GOLD, 10))
	b.add_theme_stylebox_override("pressed", button_box(pressed, GOLD, 10))
	var text_color := Color("1b1408") if accent else TEXT
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, text_color)
	return b


## Bouton rond avec une icône blanche (SVG), pour les coins de l'écran.
static func icon_button(icon: Texture2D, tip: String, size: int = 44) -> Button:
	var b := Button.new()
	b.icon = icon
	b.expand_icon = true
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(size, size)
	b.add_theme_constant_override("icon_max_width", int(size * 0.5))
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var radius := size / 2
	b.add_theme_stylebox_override("normal", button_box(PANEL_BG, PANEL_BORDER, radius))
	b.add_theme_stylebox_override("hover", button_box(Color("2a303c"), GOLD, radius))
	b.add_theme_stylebox_override("pressed", button_box(Color("14171d"), GOLD, radius))
	return b


# --- Orbe de PV --------------------------------------------------------------------

class HpOrb extends Control:
	var hp := 0
	var max_hp := 1

	func _init() -> void:
		custom_minimum_size = Vector2(92, 92)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_values(p_hp: int, p_max: int) -> void:
		hp = p_hp
		max_hp = maxi(1, p_max)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 3.0
		draw_circle(c, r + 3.0, Color("5a5040"))
		draw_circle(c, r, HudWidgets.HP_BG)
		var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
		if ratio >= 1.0:
			draw_circle(c, r, HudWidgets.HP)
		elif ratio > 0.0:
			# Segment de disque sous le niveau : de l'angle t0 à PI - t0 en passant par le bas.
			var h := r * (1.0 - 2.0 * ratio)
			var t0 := asin(clampf(h / r, -1.0, 1.0))
			var pts := PackedVector2Array()
			var steps := 32
			for i in steps + 1:
				var t := lerpf(t0, PI - t0, float(i) / steps)
				pts.append(c + Vector2(cos(t), sin(t)) * r)
			draw_colored_polygon(pts, HudWidgets.HP)
		HudWidgets.draw_text_centered(self, c + Vector2(0, -6), str(hp), 24, Color.WHITE, 4)
		HudWidgets.draw_text_centered(self, c + Vector2(0, 16), "/ %d PV" % max_hp, 11, Color("f3d6d2"), 3)


# --- Compteur PA / PM --------------------------------------------------------------

class ResourceBadge extends Control:
	var is_pa := true
	var value := 0

	func _init(p_is_pa: bool) -> void:
		is_pa = p_is_pa
		custom_minimum_size = Vector2(82, 34)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: int) -> void:
		value = v
		queue_redraw()

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("1b2634") if is_pa else Color("19291f")
		sb.border_color = Color("2f4a68") if is_pa else Color("2f5a3c")
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(8)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		HudWidgets.draw_resource_icon(self, Vector2(17, size.y * 0.5), is_pa, 20.0)
		var f := HudWidgets.font()
		var col := HudWidgets.PA_TEXT if is_pa else HudWidgets.PM_TEXT
		draw_string_outline(f, Vector2(32, size.y * 0.5 + 7), str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 2, Color(0, 0, 0, 0.6))
		draw_string(f, Vector2(32, size.y * 0.5 + 7), str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
		draw_string(f, Vector2(56, size.y * 0.5 + 5), "PA" if is_pa else "PM", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HudWidgets.TEXT_DIM)


# --- Case de sort ------------------------------------------------------------------

class SpellSlot extends Button:
	enum Look { READY, SELECTED, NO_PA, COOLDOWN, NO_CASTS, LOCKED }

	var spell: SpellData
	var index := 0
	var look := Look.READY
	var cooldown_left := 0
	var casts_left := 0

	func _init(p_index: int) -> void:
		index = p_index
		custom_minimum_size = Vector2(64, 64)
		focus_mode = Control.FOCUS_NONE
		for style in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			add_theme_stylebox_override(style, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func configure(p_spell: SpellData, p_look: Look, p_cooldown: int, p_casts_left: int) -> void:
		spell = p_spell
		look = p_look
		cooldown_left = p_cooldown
		casts_left = p_casts_left
		tooltip_text = "" # l'infobulle est gérée par le HUD
		queue_redraw()

	func usable() -> bool:
		return look == Look.READY or look == Look.SELECTED

	func _draw() -> void:
		if spell == null:
			return
		var rect := Rect2(Vector2.ZERO, size)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(2)
		match look:
			Look.SELECTED:
				sb.bg_color = Color("3b2f1c")
				sb.border_color = HudWidgets.GOLD
				sb.shadow_color = Color(HudWidgets.GOLD, 0.3)
				sb.shadow_size = 4
			Look.READY:
				sb.bg_color = Color("33302a") if is_hovered() else Color("2a2a2a")
				sb.border_color = Color("8a7650") if is_hovered() else Color("5a5040")
			_:
				sb.bg_color = Color("22262f")
				sb.border_color = HudWidgets.PANEL_BORDER
		draw_style_box(sb, rect)

		# Icône (ou initiales si le sort n'en a pas)
		var tint := Color("f1e3c2") if usable() else Color("6d695f")
		if spell.icon:
			var icon_size := Vector2(40, 40)
			var icon_tint := Color.WHITE if usable() else Color(0.38, 0.38, 0.4)
			draw_texture_rect(spell.icon, Rect2((size - icon_size) * 0.5, icon_size), false, icon_tint)
		else:
			var initials := spell.spell_name.substr(0, 2)
			HudWidgets.draw_text_centered(self, size * 0.5, initials, 20, tint)

		var f := HudWidgets.font()
		draw_string(f, Vector2(6, 14), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HudWidgets.TEXT_DIM)

		# Lancers restants ce tour (points), seulement si le sort se lance plusieurs fois
		if spell.casts_per_turn > 1 and look != Look.COOLDOWN:
			for i in spell.casts_per_turn:
				var on := i < casts_left
				draw_circle(Vector2(9 + i * 9, size.y - 8), 3.0, Color("f1e3c2") if on else Color("4a4f5a"))

		# Recharge : voile sombre et tours restants
		if look == Look.COOLDOWN:
			var veil := StyleBoxFlat.new()
			veil.bg_color = Color(0.03, 0.04, 0.06, 0.62)
			veil.set_corner_radius_all(8)
			draw_style_box(veil, rect.grow(-2))
			HudWidgets.draw_text_centered(self, size * 0.5, str(cooldown_left), 24, Color("f1e3c2"), 3)

		# Coût en PA, pastille en bas à droite (rouge si pas assez de PA)
		var badge_center := size - Vector2(4, 4)
		draw_circle(badge_center, 12.0, Color("12141a"))
		draw_circle(badge_center, 10.0, HudWidgets.COST_BADGE_BAD if look == Look.NO_PA else HudWidgets.COST_BADGE)
		HudWidgets.draw_text_centered(self, badge_center, str(spell.pa_cost), 12, Color.WHITE)


# --- Vignette de l'ordre de jeu ------------------------------------------------------

class FighterChip extends Control:
	var fighter: Fighter
	var active := false

	func _init(p_fighter: Fighter) -> void:
		fighter = p_fighter
		custom_minimum_size = Vector2(64, 84)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if fighter == null:
			return
		var alive := fighter.is_alive()
		var sb := StyleBoxFlat.new()
		sb.bg_color = HudWidgets.PANEL_BG
		sb.border_color = HudWidgets.GOLD if active else HudWidgets.PANEL_BORDER
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var c := Vector2(size.x * 0.5, 28)
		var team: Color = HudWidgets.TEAM_COLORS[fighter.team % HudWidgets.TEAM_COLORS.size()]
		var class_color := fighter.class_data.color if fighter.class_data else Color.WHITE
		draw_circle(c, 22, team)
		draw_circle(c, 19.5, Color("2a2620"))
		var letter := fighter.class_data.class_label.substr(0, 1) if fighter.class_data else "?"
		HudWidgets.draw_text_centered(self, c, letter, 20, class_color)
		# Barre de PV
		var bar := Rect2(8, 56, size.x - 16, 5)
		draw_rect(bar, Color("2a2e37"))
		var ratio := clampf(float(fighter.hp) / float(fighter.max_hp), 0.0, 1.0)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), HudWidgets.TEAM_COLORS[0].lerp(HudWidgets.HP, 0.3))
		HudWidgets.draw_text_centered(self, Vector2(size.x * 0.5, 72), str(fighter.hp) if alive else "K.O.", 11, HudWidgets.TEXT_DIM)
		if not alive:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
