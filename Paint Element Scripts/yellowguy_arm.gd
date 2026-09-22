extends PickableAnimatedSprite3D

@onready var audio_player = AudioStreamPlayer3D.new()

func _ready() -> void:
	add_child(audio_player)
	audio_player.stream = preload("res://sounds/lobster.mp3")
	
func on_click() -> void:
	var tween = create_tween()
	tween.tween_property(self, "position", position + Vector3.DOWN/6, 1.5)
	audio_player.play()
	play(&"default")
	tween.tween_property(self, "position", position, 0.3)
