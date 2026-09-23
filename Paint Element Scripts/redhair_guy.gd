extends PickableAnimatedSprite3D

func on_click() -> void:
	play(&"default")
	var tween = create_tween()
	tween.tween_property(self, "position", position + Vector3.DOWN/2.5, 1)
	tween.tween_property(self, "position", position, 0.3)

func on_hover_enter() -> void:
	#modulate = Color(1.0, 1.0, 0.7)
	pass
func on_hover_exit() -> void:
	#modulate = Color.WHITE
	pass
