extends Node

class_name Animations

static func choose_animation_direction(v: Vector2, sprite: AnimatedSprite2D, anim_type: String):
	var direction_suffix = "_down"
	
	if v.length_squared() < 0.0001:
		return

	if abs(v.x) > abs(v.y):
		direction_suffix = "_right" if v.x > 0 else "_left"
	elif v.y != 0 or v.x != 0:
		direction_suffix = "_down" if v.y > 0 else "_up"
		
	var target_anim = anim_type + direction_suffix
	var fallback_anim = "idle" + direction_suffix

	if sprite.sprite_frames.has_animation(target_anim):
		_play_animation(sprite, target_anim)
	elif sprite.sprite_frames.has_animation(fallback_anim):
		_play_animation(sprite, fallback_anim)

static func _play_animation(sprite: AnimatedSprite2D, anim: String):
	if sprite.animation != anim:
		sprite.animation = anim
		sprite.play()
