class_name CurtainMode
extends GameMode
## Curtain down: the game's front door. There is nothing to press. A tap, or the
## hit action, raises the curtain and hands over to the next mode.


## The curtain sprite. It sits at its closed position in the scene and is shown
## only while this mode runs.
@export var curtain: Node3D
## How far the curtain rises, in its parent's units. The picture frame is about
## 22.4 tall, so the default clears it.
@export var raise_distance: float = 23.0
## Seconds the raise takes.
@export var raise_time: float = 1.5
## Mode to enter once the curtain is up.
@export var next_mode: StringName = &"PointAndClickMode"

var _closed_position: Vector3
var _raising: bool = false


func _ready() -> void:
	if curtain != null:
		_closed_position = curtain.position
		curtain.visible = false


func enter() -> void:
	_raising = false
	if curtain != null:
		curtain.position = _closed_position
		curtain.visible = true


func exit() -> void:
	if curtain != null:
		curtain.visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("hit") and not event.is_echo():
		_raise()


func _unhandled_input(event: InputEvent) -> void:
	# Taps are taken here so the GUI gets first refusal: opening the drawer is
	# not also a raise.
	if is_tap(event):
		_raise()


func _raise() -> void:
	if _raising:
		return
	_raising = true
	if curtain == null:
		finished.emit(next_mode)
		return
	var tween := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(curtain, "position:y", _closed_position.y + raise_distance, raise_time)
	tween.finished.connect(func() -> void: finished.emit(next_mode))
