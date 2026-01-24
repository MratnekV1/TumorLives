extends Node

class_name Animations

static func choose_animation_direction(v: Vector2, sprite: AnimatedSprite2D, anim_type: String):
	if v.length_squared() < 0.0001:
		return

	var anim: String = ""

	if abs(v.x) > abs(v.y):
		if v.x > 0:
			anim = anim_type + "_right"
		else:
			anim = anim_type + "_left"
	else:
		if v.y > 0:
			anim = anim_type + "_down"
		else:
			anim = anim_type + "_up"

	_play_animation(sprite, anim)

static func _play_animation(sprite: AnimatedSprite2D, anim: String):
	if sprite.animation != anim:
		sprite.animation = anim
		sprite.play()
