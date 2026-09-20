extends Node3D
## Placeholder dancer: hops when told to. The node's origin is its feet.

## Height of a hop from a standstill.
@export var hop_height: float = 0.7
## Seconds a hop from a standstill spends in the air. Keep it under a beat.
@export var hop_time: float = 0.3
## How much the body stretches along its travel at takeoff speed.
@export var stretch: float = 0.1

## Looping animation played whenever nothing else is. Names come from the
## SpriteFrames panel.
@export var idle_animation: StringName = &"Stand"
## Played once per hit, then back to idle. Must have Loop turned off in the
## SpriteFrames panel, or it never finishes.
@export var hit_animation: StringName = &"CLAW"

@onready var _sprite: AnimatedSprite3D = %DancerSprite

var _height: float = 0.0
var _velocity: float = 0.0

@onready var _floor_y: float = position.y

func _ready() -> void:
	_sprite.animation_finished.connect(start_idle)

func start_idle() -> void:
	_sprite.play(idle_animation)

func play() -> void:
	_sprite.play()
	
func pause() -> void:
	_sprite.pause()

func hit() -> void:
	# play() on the animation that's already playing is a no-op, so stop()
	# first to make a hit during a hit restart from frame 0.
	_sprite.stop()
	_sprite.play(hit_animation)

	_velocity = 4.0 * hop_height / hop_time


func _process(delta: float) -> void:
	pass
	
	# Bounce processing, out for now
	if _height <= 0.0 and _velocity <= 0.0:
		return
	var gravity := 8.0 * hop_height / (hop_time * hop_time)
	_velocity -= gravity * delta
	_height += _velocity * delta
	if _height <= 0.0:
		_height = 0.0
		_velocity = 0.0
	position.y = _floor_y + _height

	var takeoff_speed := 4.0 * hop_height / hop_time
	var tall := 1.0 + stretch * absf(_velocity) / takeoff_speed
	var wide := 1.0 / sqrt(tall)
	scale = Vector3(wide, tall, wide)
