class_name SongClock
extends Node
## Plays a song and reports the position the player is currently *hearing*.
##
## Song time is a linear function of the system clock, so it is smooth and can be
## sampled at any instant (e.g. inside _input), not just once per frame. Each frame
## it is compared against the audio player's own position, which is the ground truth
## but only advances in mix-sized chunks. Small disagreements are slewed out slowly;
## large ones (hitch, window drag, tab suspend) snap.

signal finished

## Disagreement with the audio position, in seconds, beyond which the clock snaps.
@export var snap_threshold: float = 0.05
## Time constant, in seconds, of the low-pass filter on the measured error.
@export var error_smoothing: float = 0.5
## Fraction of the smoothed error removed per second.
@export var correction_rate: float = 1.0
## Cap on how far correction may speed up or slow down song time, as a fraction of
## real time. Keeps song time strictly increasing while slewing.
@export var max_slew: float = 0.05
@export var drift_correction_enabled: bool = true

var song: SongData
var is_playing: bool = false

# Debug readouts.
var raw_error: float = 0.0
var smoothed_error: float = 0.0
var snap_count: int = 0
var output_latency: float = 0.0
## False if the audio player's position isn't advancing (seen with some web playback
## modes). Drift correction is skipped while this is false.
var audio_position_reliable: bool = true

var _player: AudioStreamPlayer
# System clock reading, in usec, at which song time is zero.
var _anchor_usec: int = 0
var _last_playback_position: float = 0.0
var _stalled_time: float = 0.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.finished.connect(_on_player_finished)


func start(new_song: SongData) -> void:
	song = new_song
	_player.stream = song.stream
	_player.play()
	# The first sample isn't audible until the next mix has gone through the output buffer.
	output_latency = AudioServer.get_output_latency()
	var start_delay := AudioServer.get_time_to_next_mix() + output_latency
	_anchor_usec = Time.get_ticks_usec() + int(start_delay * 1000000.0)
	raw_error = 0.0
	smoothed_error = 0.0
	snap_count = 0
	audio_position_reliable = true
	_last_playback_position = 0.0
	_stalled_time = 0.0
	is_playing = true


func stop() -> void:
	_player.stop()
	is_playing = false


## Song position being heard right now, in seconds. Negative just after start().
func get_song_time() -> float:
	return (Time.get_ticks_usec() - _anchor_usec) / 1000000.0


func get_beat_position() -> float:
	return song.time_to_beat(get_song_time())


func _process(delta: float) -> void:
	if not is_playing or not _player.playing:
		return

	var playback_position := _player.get_playback_position()
	if playback_position <= 0.0:
		# Not mixed yet, so there is nothing to compare against.
		return
	_update_reliability(playback_position, delta)
	if not drift_correction_enabled or not audio_position_reliable:
		return

	var audio_time := playback_position + AudioServer.get_time_since_last_mix() - output_latency
	raw_error = audio_time - get_song_time()

	if absf(raw_error) > snap_threshold:
		_shift(raw_error)
		smoothed_error = 0.0
		snap_count += 1
		return

	smoothed_error = lerpf(smoothed_error, raw_error, 1.0 - exp(-delta / error_smoothing))
	var limit := max_slew * delta
	var correction := clampf(smoothed_error * correction_rate * delta, -limit, limit)
	_shift(correction)
	smoothed_error -= correction


# Moves song time forward by [param seconds].
func _shift(seconds: float) -> void:
	_anchor_usec -= int(seconds * 1000000.0)


func _update_reliability(playback_position: float, delta: float) -> void:
	if playback_position != _last_playback_position:
		_last_playback_position = playback_position
		_stalled_time = 0.0
		audio_position_reliable = true
		return
	_stalled_time += delta
	if _stalled_time > 0.5:
		audio_position_reliable = false


func _on_player_finished() -> void:
	is_playing = false
	finished.emit()
