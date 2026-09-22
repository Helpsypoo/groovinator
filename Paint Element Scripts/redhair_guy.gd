extends PickableAnimatedSprite3D

func on_click() -> void:
	play(&"default")
	

func on_hover_enter() -> void:
	#modulate = Color(1.0, 1.0, 0.7)
	pass
func on_hover_exit() -> void:
	#modulate = Color.WHITE
	pass
