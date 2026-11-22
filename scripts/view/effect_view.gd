class_name EffectView
extends Node2D
## Affiche un EffectAnimation : un impact joué sur place, ou un projectile qui vole
## d'un point à un autre. Le nœud se détruit tout seul à la fin.

signal arrived

var _sprite := AnimatedSprite2D.new()


func _setup(anim: EffectAnimation) -> void:
	_sprite.sprite_frames = anim.sprite_frames()
	_sprite.centered = false
	_sprite.offset = -anim.origin
	_sprite.scale = anim.scale
	if anim.additive:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_sprite.material = mat
	add_child(_sprite)
	_sprite.play("default")


## Couche d'affichage : la carte est en 0, les effets au sol en 1, les personnages en 2.
const Z_GROUND := 1
const Z_AIR := 40


## Joue un impact centré sur `world_pos`.
static func impact(parent: Node, anim: EffectAnimation, world_pos: Vector2) -> EffectView:
	var fx := EffectView.new()
	fx.position = world_pos
	fx.z_index = Z_GROUND if anim.on_ground else Z_AIR
	parent.add_child(fx)
	fx._setup(anim)
	fx._sprite.animation_finished.connect(fx.queue_free)
	return fx


## Lance un projectile de `from` vers `to`, orienté dans le sens du vol.
## Le signal `arrived` est émis à l'arrivée.
static func projectile(parent: Node, anim: EffectAnimation, from: Vector2, to: Vector2) -> EffectView:
	var fx := EffectView.new()
	fx.position = from
	fx.rotation = (to - from).angle()
	fx.z_index = 50
	parent.add_child(fx)
	fx._setup(anim)
	var duration := maxf(0.12, from.distance_to(to) / maxf(anim.speed, 1.0))
	var tween := fx.create_tween()
	tween.tween_property(fx, "position", to, duration)
	tween.tween_callback(func() -> void:
		fx.arrived.emit()
		fx.queue_free())
	return fx
