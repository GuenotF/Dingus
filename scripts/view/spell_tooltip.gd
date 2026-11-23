class_name SpellTooltip
extends PanelContainer
## Infobulle d'un sort (nom, coût, portée, effets, état), partagée par le HUD de combat et le menu.

const WIDTH := 270

var _name: Label
var _cost: Label
var _range: Label
var _effects: Label
var _status: Label
var _hint: Label


func _init() -> void:
	var sb := HudWidgets.panel_style(Color("5a5040"), 8, 12)
	sb.bg_color = Color(0.055, 0.063, 0.082, 0.96)
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true # positionnée en coordonnées écran, au-dessus du reste
	z_index = 100
	hide()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_name = _label(16, Color("f1e3c2"))
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_name)
	_cost = _label(14, Color("6fb0f0"))
	head.add_child(_cost)
	_range = _wrapped(_label(12, HudWidgets.TEXT_DIM))
	v.add_child(_range)
	var line := ColorRect.new()
	line.color = HudWidgets.PANEL_BORDER
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)
	_effects = _wrapped(_label(14, HudWidgets.TEXT))
	v.add_child(_effects)
	_status = _wrapped(_label(12, Color("8fd3a0")))
	v.add_child(_status)
	_hint = _wrapped(_label(12, HudWidgets.TEXT_DIM))
	_hint.text = "Clic : lancer   ·   Clic droit / Échap : annuler"
	v.add_child(_hint)


## Affiche le sort au-dessus de `anchor` (rectangle en coordonnées écran), sans sortir de l'écran.
## `status` vide = ligne masquée ; `show_hint` = rappel des contrôles de lancer.
func show_spell(spell: SpellData, anchor: Rect2, status: String = "", status_color: Color = Color("8fd3a0"), show_hint: bool = false) -> void:
	_name.text = spell.spell_name
	_cost.text = "%d PA" % spell.pa_cost
	_range.text = range_text(spell)
	var effects: Array[String] = []
	for e in spell.effects:
		effects.append(e.describe())
	_effects.text = "  ·  ".join(effects)
	_status.text = status
	_status.visible = status != ""
	_status.add_theme_color_override("font_color", status_color)
	_hint.visible = show_hint
	reset_size()
	show()
	var view := get_viewport_rect().size
	var pos := anchor.position + Vector2(anchor.size.x * 0.5 - size.x * 0.5, -size.y - 16)
	if pos.y < 8:
		pos.y = anchor.end.y + 16 # pas la place au-dessus : en dessous
	pos.x = clampf(pos.x, 8, view.x - size.x - 8)
	position = pos


## Limites du sort hors combat : lancers par tour et recharge.
static func limits_text(spell: SpellData) -> String:
	var parts: Array[String] = []
	parts.append("%d lancer%s par tour" % [spell.casts_per_turn, "s" if spell.casts_per_turn > 1 else ""])
	if spell.cooldown > 0:
		parts.append("recharge %d tour%s" % [spell.cooldown, "s" if spell.cooldown > 1 else ""])
	return "  ·  ".join(parts)


static func range_text(spell: SpellData) -> String:
	var parts: Array[String] = []
	if spell.range_max == 0:
		parts.append("Sur soi")
	elif spell.range_min == spell.range_max:
		parts.append("Portée %d" % spell.range_max)
	else:
		parts.append("Portée %d–%d" % [spell.range_min, spell.range_max])
	if spell.range_max > 0:
		parts.append("ligne de vue" if spell.needs_line_of_sight else "sans ligne de vue")
	if spell.line_only:
		parts.append("en ligne")
	if spell.area == SpellData.AreaShape.CROSS:
		parts.append("zone en croix" if spell.range_max > 0 else "autour de soi")
	elif spell.area == SpellData.AreaShape.SQUARE:
		parts.append("zone carrée %d×%d" % [spell.area_size * 2 + 1, spell.area_size * 2 + 1])
	if spell.target_rule == SpellData.TargetRule.EMPTY:
		parts.append("case libre")
	elif spell.target_rule == SpellData.TargetRule.FIGHTER:
		parts.append("sur un personnage")
	return "  ·  ".join(parts)


static func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


## Retour à la ligne dans une largeur fixe (sinon le label se réduit à une colonne).
static func _wrapped(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WIDTH - 24, 0)
	return l
