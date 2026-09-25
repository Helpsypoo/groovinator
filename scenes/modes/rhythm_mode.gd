class_name RhythmMode
extends GameMode
## The rhythm game: the stage pans to the dancer, the song plays, and the player
## taps on the beat. Owns everything rhythm-only: the note lane and judgment
## label under this node, hit judging, the timing stats in the calibration
## drawer, and pausing.
##
## Entering runs the transition out of the painting (camera, dancer, the lobster
## man leaving his stool) and starts the song when it lands. Exiting stops the
## song and hides the lane and label.


## Judgment tiers, best first: name and the largest absolute error (seconds) that earns it.
## Anything beyond the last tier is "Bad".
const TIERS: Array[Dictionary] = [
	{"name": "Perfect", "window": 0.020},
	{"name": "Great", "window": 0.045},
	{"name": "Good", "window": 0.080},
	{"name": "Okay", "window": 0.120},
]
# The hit marker is green inside this tier's window, red outside.
const GREEN_TIER := 0
const HINT_PLAYING := "Tap or press Space on the beat"

@export_group("Entrance")
## Where the camera ends up for the rhythm game.
@export var camera_position: Vector3 = Vector3(0.2, 3.736, 10)
## Orthographic size the camera ends up at.
@export var camera_size: float = 7.3
## Where the dancer ends up, in world space.
@export var dancer_position: Vector3 = Vector3(-0.777, 1.215, 0)
## The dancer's final rotation, in degrees.
@export var dancer_rotation_degrees: Vector3 = Vector3.ZERO
## How far the lobster man, his stool and the thumb slide out of the painting.
@export var stage_exit_offset: Vector3 = Vector3.LEFT * 20
## Seconds the transition takes. The song starts when it finishes.
@export var transition_time: float = 1.0

@onready var _clock: SongClock = %SongClock
@onready var _lane: Path3D = %NoteLane
@onready var _ui: CanvasLayer = $UI
@onready var _judgment_label: Label = %JudgmentLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _clock_label: Label = %ClockLabel
@onready var _dancer: Node3D = %Dancer
@onready var _camera: Camera3D = %Camera
@onready var _lobster_man: Node3D = %"Lobster Man"
@onready var _stool: Node3D = %Stool
@onready var _thumb: Node3D = %Thumb

var _errors: Array[float] = []
var _text_before_pause: String = ""
var _entrance: Tween


func _ready() -> void:
	_lane.visible = false
	_ui.visible = false
	_update_stats()
	%ResetStatsButton.pressed.connect(_reset_stats)
	main.song_changed.connect(_on_song_changed)
	main.calibration_changed.connect(_reset_stats)


func enter() -> void:
	_lane.visible = true
	_ui.visible = true
	_judgment_label.text = ""
	_run_entrance()


func exit() -> void:
	if _entrance != null and _entrance.is_valid():
		_entrance.kill()
	_entrance = null
	_clock.stop()
	_lane.visible = false
	_ui.visible = false


# Pan to the dancer and clear the lobster man off his stool, then start the song.
func _run_entrance() -> void:
	_entrance = create_tween().set_parallel().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_entrance.tween_property(_camera, "position", camera_position, transition_time)
	_entrance.tween_property(_camera, "size", camera_size, transition_time)
	_entrance.tween_property(_dancer, "position", dancer_position, transition_time)
	var dancer_rotation := Quaternion.from_euler(dancer_rotation_degrees * (PI / 180.0))
	_entrance.tween_property(_dancer, "quaternion", dancer_rotation, transition_time)
	for node: Node3D in [_lobster_man, _stool, _thumb]:
		_entrance.tween_property(node, "position", node.position + stage_exit_offset, transition_time)
	_entrance.finished.connect(_start_song)


func _start_song() -> void:
	_entrance = null
	_clock.start(main.song)
	_judgment_label.text = HINT_PLAYING
	_reset_stats()
	_dancer.start_idle()


func _on_song_changed() -> void:
	# Main has already stopped the clock and prepared the new song. Only restart
	# if the rhythm game is actually running.
	if can_process():
		_start_song()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("hit") and not event.is_echo():
		_hit()


func _unhandled_input(event: InputEvent) -> void:
	# Taps are taken here rather than in _input so that the GUI gets first refusal:
	# a tap on the drawer is not also a hit.
	if is_tap(event):
		_hit()
	elif event.is_action_pressed("ui_cancel") and _clock.is_playing:
		_set_paused(not _clock.is_paused)


func _hit() -> void:
	if _clock.is_paused:
		return
	# Sample the clock here rather than in _process: this is as close to the
	# physical press as the engine lets us get.
	var time := _clock.get_song_time() - main.av_offset - main.input_offset
	_dancer.hit()
	if _clock.is_playing:
		_judge(time)


func _process(_delta: float) -> void:
	_lane.song = main.song
	_lane.loop_length = _clock.get_loop_length()
	if not _clock.is_playing:
		_lane.time = 0.0
		_lane.marker_color = Color.DIM_GRAY
		return

	var visual_time := _clock.get_song_time() - main.av_offset
	_lane.time = visual_time
	if absf(_error_to_nearest_beat(visual_time)) <= TIERS[GREEN_TIER].window:
		_lane.marker_color = Color.GREEN
	else:
		_lane.marker_color = Color.DIM_GRAY

	_clock_label.text = "beat %.2f
clock vs audio: %+.1f ms (smoothed %+.1f)
snaps: %d   reported latency: %.0f ms%s" % [
		_clock.get_beat_position(),
		_clock.raw_error * 1000.0,
		_clock.smoothed_error * 1000.0,
		_clock.snap_count,
		_clock.output_latency * 1000.0,
		"" if _clock.audio_position_reliable else "
AUDIO POSITION STALLED - correction off",
	]


# Signed distance, in seconds, from the nearest beat. Negative is early.
func _error_to_nearest_beat(time: float) -> float:
	var song := main.song
	var last_beat := floorf(song.time_to_beat(song.stream.get_length()))
	var times := [time]
	var loop_length := _clock.get_loop_length()
	if loop_length > 0.0:
		# Near the seam the nearest beat can belong to the previous or next pass.
		times.append_array([time - loop_length, time + loop_length])

	var best := INF
	for t: float in times:
		var beat := clampf(roundf(song.time_to_beat(t)), 0.0, last_beat)
		var error := t - song.beat_to_time(beat)
		if absf(error) < absf(best):
			best = error
	return best


func _judge(time: float) -> void:
	var error := _error_to_nearest_beat(time)
	var tier_name := "Bad"
	for tier in TIERS:
		if absf(error) <= tier.window:
			tier_name = tier.name
			break

	if tier_name == TIERS[0].name:
		_judgment_label.text = tier_name
		_lane.burst()
	else:
		_judgment_label.text = "%s - %s" % [tier_name, "early" if error < 0.0 else "late"]

	_errors.append(error)
	_update_stats(error)


func _update_stats(last_error: float = NAN) -> void:
	if _errors.is_empty():
		_stats_label.text = "no presses yet"
		return
	var mean := 0.0
	for e in _errors:
		mean += e
	mean /= _errors.size()
	var variance := 0.0
	for e in _errors:
		variance += (e - mean) ** 2
	variance /= _errors.size()
	_stats_label.text = "last %+.0f ms   n = %d
mean %+.1f ms   std dev %.1f ms" % [
		last_error * 1000.0, _errors.size(), mean * 1000.0, sqrt(variance) * 1000.0]


func _reset_stats() -> void:
	_errors.clear()
	_update_stats()


func _set_paused(paused: bool) -> void:
	if paused:
		_clock.pause()
		_text_before_pause = _judgment_label.text
		_judgment_label.text = "Paused"
		_dancer.pause()
	else:
		_clock.resume()
		_judgment_label.text = _text_before_pause
		_dancer.play()
