extends Path3D
## Notes ride the path from its start and pass the hit marker exactly on their beat.
##
## The owner feeds in the time to show (already shifted by the A/V offset) and the
## marker colour each frame; this node only positions things. The curve can be any
## shape: notes move along it at constant speed, and the marker and rail follow it.
## The hit point is wherever the HitMarker child sits on the path.

## Seconds a note takes to travel from the start of the path to the hit marker.
@export var lead_time: float = 2.0
## What rides the path for each note. Any Node3D; the lane supplies the PathFollow3D.
@export var note_scene: PackedScene
## Fraction of the path over which a note grows in, so that it never pops into view.
@export_range(0.0, 0.5) var grow_in_ratio: float = 0.05

var song: SongData
var time: float = 0.0
## Length of one pass of the song when it loops, otherwise 0.
var loop_length: float = 0.0
var marker_color: Color = Color.DIM_GRAY:
	set(value):
		marker_color = value
		if _marker_material != null:
			_marker_material.albedo_color = value

# Pool of notes, reused every frame. The first _used are on the path.
var _notes: Array[PathFollow3D] = []
var _used: int = 0
var _hit_ratio: float = 1.0

@onready var _marker: PathFollow3D = $HitMarker
@onready var _marker_material: StandardMaterial3D = $HitMarker/Ring.get_surface_override_material(0)


func _ready() -> void:
	marker_color = marker_color


func _process(_delta: float) -> void:
	_used = 0
	_hit_ratio = _marker.progress_ratio
	if song != null and _hit_ratio > 0.0:
		_place_pass(0.0)
		if loop_length > 0.0:
			# Around the seam, the previous and next passes are on the path too.
			_place_pass(-loop_length)
			_place_pass(loop_length)
	for i in range(_used, _notes.size()):
		_notes[i].visible = false


# Places one pass of the song, which starts at [param pass_start] in lane time.
func _place_pass(pass_start: float) -> void:
	# Time span currently on the path: from the far end, past the marker, to the start.
	var time_past_marker := lead_time * (1.0 - _hit_ratio) / _hit_ratio
	var earliest := time - pass_start - time_past_marker
	var latest := minf(time - pass_start + lead_time, song.stream.get_length())

	var first_beat := maxi(0, ceili(song.time_to_beat(earliest)))
	var last_beat := floori(song.time_to_beat(latest))
	for beat in range(first_beat, last_beat + 1):
		var until_hit := pass_start + song.beat_to_time(beat) - time
		_place_note(_hit_ratio * (1.0 - until_hit / lead_time))


func _place_note(ratio: float) -> void:
	if _used == _notes.size():
		_notes.append(_make_note())
	var note := _notes[_used]
	_used += 1

	note.visible = true
	note.progress_ratio = clampf(ratio, 0.0, 1.0)
	var note_scale := 1.0
	if ratio < grow_in_ratio:
		note_scale = ratio / grow_in_ratio
	elif ratio > _hit_ratio:
		# Shrink away once past the marker.
		note_scale = (1.0 - ratio) / (1.0 - _hit_ratio)
	# Scale the visual, not the follower: the follower's transform belongs to the path.
	(note.get_child(0) as Node3D).scale = Vector3.ONE * clampf(note_scale, 0.001, 1.0)


func _make_note() -> PathFollow3D:
	var note := PathFollow3D.new()
	note.loop = false
	note.add_child(note_scene.instantiate())
	add_child(note)
	return note
