class_name CurtainMode
extends GameMode
## Curtain down: the game's front door. There is nothing to press. A tap, or the
## hit action, raises the curtain and hands over to the next mode.
##
## The curtain is a stack of copies of one sprite, [member curtain], laid out
## downwards with each section a little further from the camera than the one
## above it, so the upper sections overlap the lower ones. Raising gathers it
## from the bottom: the lowest section rises until it is hidden behind the next
## one, then the two rise together, and so on until only the top section shows.
## The top section stays visible afterwards, as part of the painting. While the
## curtain is down the sections sway sideways, each at its own pace.


## The top section, kept in the scene at its resting place. The other sections
## are copies made at load and live next to it.
@export var curtain: Node3D
## Sections in the stack, counting the top one.
@export_range(1, 32) var section_count: int = 8
## Vertical distance between neighbouring sections, in the curtain's parent's
## units. Keep it under the sprite's height (4.03 for CURTAIN.png at the default
## pixel size) so the sections overlap.
@export var section_spacing: float = 2.8
## How much further from the camera each section sits than the one above it.
@export var depth_step: float = 0.05
## Seconds each section takes to rise behind the one above it.
@export var step_time: float = 0.25
## Sideways sway of a hanging section, in the curtain's parent's units.
@export var sway_amplitude: float = 0.04
## Sway speed in cycles per second. Each section varies from this a little.
@export var sway_speed: float = 0.2
## Mode to enter once the curtain is up.
@export var next_mode: StringName = &"PointAndClickMode"

# Top section first.
var _sections: Array[Node3D] = []
var _rest_position: Vector3
var _sway_phases: PackedFloat32Array = PackedFloat32Array()
var _sway_speeds: PackedFloat32Array = PackedFloat32Array()
# 1 while hanging, eased to 0 as the raise starts so the sections line up.
var _sway_strength: float = 1
var _time: float = 0.0
var _raising: bool = false


func _ready() -> void:
	if curtain == null:
		return
	_rest_position = curtain.position
	_sections.append(curtain)
	for i in range(1, section_count):
		var section := curtain.duplicate() as Node3D
		section.name = "CurtainSection%d" % i
		curtain.add_sibling(section)
		_sections.append(section)
	for i in _sections.size():
		_sway_phases.append(randf() * TAU)
		_sway_speeds.append(sway_speed * randf_range(0.7, 1.3))
	# The top section is part of the painting whatever the mode.
	curtain.visible = true
	_set_lower_sections_visible(false)


func enter() -> void:
	_raising = false
	_sway_strength = 1.0
	for i in _sections.size():
		_sections[i].position = _hanging_position(i)
	_set_lower_sections_visible(true)


func exit() -> void:
	# Whatever state the raise was in, park the stack behind the top section.
	for i in _sections.size():
		_sections[i].position = _gathered_position(i)
	_set_lower_sections_visible(false)


func _process(delta: float) -> void:
	_time += delta
	for i in _sections.size():
		var sway := sin(_time * TAU * _sway_speeds[i] + _sway_phases[i])
		_sections[i].position.x = _rest_position.x + _sway_strength * sway_amplitude * sway


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
	var count := _sections.size()
	if count <= 1:
		_finish.call_deferred()
		return
	var tween := create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	# Let the sway settle during the first step so the sections line up.
	tween.tween_property(self, "_sway_strength", 0.0, step_time)
	for step in range(1, count):
		if step > 1:
			tween.chain()
		# The bottom `step` sections rise together, one slot up.
		for i in range(count - step, count):
			tween.tween_property(_sections[i], "position:y", section_spacing, step_time).as_relative()
	tween.finished.connect(_finish)


func _finish() -> void:
	finished.emit(next_mode)


# Where section i hangs when the curtain is down.
func _hanging_position(i: int) -> Vector3:
	return _rest_position + Vector3(0.0, -i * section_spacing, -i * depth_step)


# Where section i sits once gathered behind the top section.
func _gathered_position(i: int) -> Vector3:
	return _rest_position + Vector3(0.0, 0.0, -i * depth_step)


func _set_lower_sections_visible(shown: bool) -> void:
	for i in range(1, _sections.size()):
		_sections[i].visible = shown
