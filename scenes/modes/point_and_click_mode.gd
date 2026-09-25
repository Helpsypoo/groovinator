class_name PointAndClickMode
extends GameMode
## Poking at the painting. The elements react through their own scripts (see
## [PickableAnimatedSprite3D]); this mode only switches the picker on and runs
## the way into the rhythm game: each click on [member start_element] reveals
## the next word of the title, and once the whole title is up the game starts.
## The hit action starts it straight away, which is handy while testing.


## Element whose clicks reveal the title, such as the lobster dancer. It needs a
## clicked signal, which every PickableAnimatedSprite3D has.
@export var start_element: Node
## Title words in reading order. Hidden on entry and shown one per click. Leave
## empty to start the game on the first click.
@export var title_words: Array[Node3D] = []
## Seconds between the last word appearing and the game starting.
@export var start_delay: float = 1.0
## Mode to enter when the game starts.
@export var next_mode: StringName = &"RhythmMode"

@onready var _picker: SpritePicker = %PickerHelper

var _revealed: int = 0
var _start_timer: Tween


func _ready() -> void:
	if start_element != null and start_element.has_signal(&"clicked"):
		start_element.connect(&"clicked", _on_start_element_clicked)


func enter() -> void:
	_revealed = 0
	_start_timer = null
	for word in title_words:
		if word != null:
			word.visible = false
	_picker.enabled = true


func exit() -> void:
	_picker.enabled = false
	if _start_timer != null and _start_timer.is_valid():
		_start_timer.kill()
	_start_timer = null


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("hit") and not event.is_echo():
		_start()


func _on_start_element_clicked() -> void:
	# The element can be clicked whenever the picker is on; only act while this
	# mode is the current one.
	if not can_process():
		return
	if _revealed < title_words.size():
		if title_words[_revealed] != null:
			title_words[_revealed].visible = true
		_revealed += 1
	if _revealed < title_words.size():
		return
	if _start_timer != null:
		return # The whole title is already up and the countdown is running.
	_start_timer = create_tween()
	_start_timer.tween_interval(start_delay)
	_start_timer.tween_callback(_start)


func _start() -> void:
	if can_process():
		finished.emit(next_mode)
