extends PickableAnimatedSprite3D

func on_click() -> void:
	var tween = create_tween()
	tween.tween_property(self, "position", position + Vector3.UP, 0.1)
	tween.tween_property(self, "position", position, 0.1)
	

func on_hover_enter() -> void:
	modulate = Color(1.0, 1.0, 0.7)

func on_hover_exit() -> void:
	modulate = Color.WHITE
