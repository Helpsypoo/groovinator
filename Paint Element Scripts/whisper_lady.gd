extends PickableAnimatedSprite3D

func on_click() -> void:
	var tween = create_tween()
	tween.tween_property(self, "position", position + Vector3.DOWN/4, 0.4)
	play(&"default")
	tween.tween_property(self, "position", position, 0.1)



	
