class_name UiFit
## Mode mobile : réduit un écran (ou une fenêtre) quand son contenu ne tient pas dans l'écran,
## par exemple l'écran de préparation avec une interface agrandie sur un téléphone.
## Sur PC, ne fait rien (la fenêtre fait toujours au moins 1280 × 720 unités).


## `holder` : conteneur plein écran (souvent un CenterContainer) ; `content` : ce qu'il doit afficher en entier.
static func attach(holder: Control, content: Control, margin: float = 12.0) -> void:
	if not Settings.mobile:
		return
	holder.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var update := func() -> void:
		if not is_instance_valid(holder) or not holder.is_inside_tree():
			return
		var view := holder.get_viewport_rect().size
		var need := content.get_combined_minimum_size() + Vector2(margin, margin) * 2.0
		var s := minf(1.0, minf(view.x / maxf(need.x, 1.0), view.y / maxf(need.y, 1.0)))
		holder.scale = Vector2(s, s)
		holder.position = Vector2.ZERO
		holder.size = view / s
	holder.get_viewport().size_changed.connect(update)
	content.minimum_size_changed.connect(update)
	holder.visibility_changed.connect(update)
	update.call_deferred()
