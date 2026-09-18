extends Node3D
## Placeholder dancer: hops when told to. The node's origin is its feet.

## Height of a hop from a standstill.
@export var hop_height: float = 0.7
## Seconds a hop from a standstill spends in the air. Keep it under a beat.
@export var hop_time: float = 0.3
## How much the body stretches along its travel at takeoff speed.
@export var stretch: float = 0.25

var _height: float = 0.0
var _velocity: float = 0.0

@onready var _floor_y: float = position.y


func bounce() -> void:
	_velocity = 4.0 * hop_height / hop_time


func _process(delta: float) -> void:
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
