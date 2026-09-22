extends PickableAnimatedSprite3D

@onready var audio_player = AudioStreamPlayer3D.new()

func _ready() -> void:
	add_child(audio_player)
	audio_player.stream = preload("res://sounds/inhale.mp3")

func on_click() -> void:
	play(&"default")
	audio_player.play()
	var tween = create_tween()
	tween.tween_property(self, "position", position + Vector3.RIGHT/15, 2)
	tween.tween_property(self, "position", position, 0.3)




#func on_click() -> void:
	#var tween = create_tween()
	#tween.tween_property(self, "position", position + Vector3.UP, 0.1)
	#tween.tween_property(self, "position", position, 0.1)
	#tween.tween_property(self, "rotation", Vector3(0,0,PI/2), 1)
#
#func on_hover_enter() -> void:
	#modulate = Color(1.0, 1.0, 0.7)
#
#func on_hover_exit() -> void:
	#modulate = Color.WHITE
