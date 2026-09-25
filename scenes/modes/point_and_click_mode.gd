class_name PointAndClickMode
extends GameMode
## Poking at the painting. The elements react through their own scripts (see
## [PickableAnimatedSprite3D]); this mode only switches the picker on and decides
## when to move on to the rhythm game.


## Optional element whose click starts the rhythm game, such as the thumb once it
## is a PickableAnimatedSprite3D. The hit action starts it regardless.
@export var start_element: Node
## Mode to enter when the game starts.
@export var next_mode: StringName = &"RhythmMode"

@onready var _picker: SpritePicker = %PickerHelper


func _ready() -> void:
	if start_element != null and start_element.has_signal(&"clicked"):
		start_element.connect(&"clicked", _start)


func enter() -> void:
	_picker.enabled = true


func exit() -> void:
	_picker.enabled = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("hit") and not event.is_echo():
		_start()


func _start() -> void:
	# The start element's signal can arrive whenever it is clicked; only act
	# while this mode is the current one.
	if can_process():
		finished.emit(next_mode)
