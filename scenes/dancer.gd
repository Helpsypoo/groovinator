#extends Node3D
### Placeholder dancer: hops when told to. The node's origin is its feet.
#
### Height of a hop from a standstill.
#@export var hop_height: float = 0.7
### Seconds a hop from a standstill spends in the air. Keep it under a beat.
#@export var hop_time: float = 0.3
### How much the body stretches along its travel at takeoff speed.
#@export var stretch: float = 0.1
#
### Looping animation played whenever nothing else is. Names come from the
### SpriteFrames panel.
#@export var idle_animation: StringName = &"Stand"
### Played once per hit, then back to idle. Must have Loop turned off in the
### SpriteFrames panel, or it never finishes.
#@export var hit_animation: StringName = &"DANCE1"
#
#@onready var _sprite: AnimatedSprite3D = %DancerSprite
#
#var _height: float = 0.0
#var _velocity: float = 0.0
#
#var _floor_height: float = 1.215 # Copied from dancer rhythm position
#
##@onready var _floor_height: float = position.y
#
#func _ready() -> void:
	#_sprite.animation_finished.connect(start_idle)
#
#func start_idle() -> void:
	#_sprite.play(idle_animation)
#
#func play() -> void:
	#_sprite.play()
	#
#func pause() -> void:
	#_sprite.pause()
#
#func hit() -> void:
	## play() on the animation that's already playing is a no-op, so stop()
	## first to make a hit during a hit restart from frame 0.
	#_sprite.stop()
	#_sprite.play(hit_animation)
#
	#_velocity = 4.0 * hop_height / hop_time
#
#
#func _process(delta: float) -> void:
	#pass
	#
	#if _height <= 0.0 and _velocity <= 0.0:
		#return
	#var gravity := 8.0 * hop_height / (hop_time * hop_time)
	#_velocity -= gravity * delta
	#_height += _velocity * delta
	#if _height <= 0.0:
		#_height = 0.0
		#_velocity = 0.0
	#position.y = _floor_height + _height
#
	#var takeoff_speed := 4.0 * hop_height / hop_time
	#var tall := 1.0 + stretch * absf(_velocity) / takeoff_speed
	#var wide := 1.0 / sqrt(tall)
	#scale = Vector3(wide, tall, wide)


extends Node3D
## Placeholder dancer: hops when told to. The node's origin is its feet.

## Height of a hop from a standstill.
@export var hop_height: float = 0.3
## Seconds a hop from a standstill spends in the air. Keep it under a beat.
@export var hop_time: float = 0.3
## How much the body stretches along its travel at takeoff speed.
@export var stretch: float = 0.05

## Looping animation played whenever nothing else is. Names come from the
## SpriteFrames panel.
@export var idle_animation: StringName = &"Stand"

## All dance animations, cycled through in order on each hit.
@export var dance_animations: Array[StringName] = [
	&"DANCE1",
	&"DANCE2",
	&"DANCE3",
	&"DANCE4",
	&"DANCE5",
	&"DANCE6",
	&"DANCE7",
]

@onready var _sprite: AnimatedSprite3D = %DancerSprite

var _height: float = 0.0
var _velocity: float = 0.0
var _current_dance_index: int = -1  # -1 so the first hit starts at index 0

var _floor_height: float = 1.215 # Copied from dancer rhythm position


func _ready() -> void:
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.animation = idle_animation
	_sprite.frame = 0
	_sprite.stop()



func _on_animation_finished() -> void:
	if not dance_animations.has(_sprite.animation):
		start_idle()


func start_idle() -> void:
	_sprite.play(idle_animation)


func play() -> void:
	_sprite.play()

func pause() -> void:
	_sprite.pause()

#use this for dance moves in order
func hit() -> void:
	# Advance to the next dance animation, wrapping back to 0 after the last.
	_current_dance_index = (_current_dance_index + 1) % dance_animations.size()

	# play() on the animation that's already playing is a no-op, so stop()
	# first to make a hit during a hit restart from frame 0.
	_sprite.stop()
	_sprite.play(dance_animations[_current_dance_index])

	_velocity = 4.0 * hop_height / hop_time



#Use this for randomized dance moves
#func hit() -> void:
	## Pick a random dance animation, but never the same one twice in a row.
	#var new_index := randi_range(0, dance_animations.size() - 1)
	#while new_index == _current_dance_index and dance_animations.size() > 1:
		#new_index = randi_range(0, dance_animations.size() - 1)
	#_current_dance_index = new_index
#
	## play() on the animation that's already playing is a no-op, so stop()
	## first to make a hit during a hit restart from frame 0.
	#_sprite.stop()
	#_sprite.play(dance_animations[_current_dance_index])
#
	#_velocity = 4.0 * hop_height / hop_time


func _process(delta: float) -> void:
	pass
	if _height <= 0.0 and _velocity <= 0.0:
		return
	var gravity := 8.0 * hop_height / (hop_time * hop_time)
	_velocity -= gravity * delta
	_height += _velocity * delta
	if _height <= 0.0:
		_height = 0.0
		_velocity = 0.0
	position.y = _floor_height + _height

	var takeoff_speed := 4.0 * hop_height / hop_time
	var tall := 1.0 + stretch * absf(_velocity) / takeoff_speed
	var wide := 1.0 / sqrt(tall)
	scale = Vector3(wide, tall, wide)
