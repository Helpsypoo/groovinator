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
## Repeat the song forever. Song time wraps back to zero at the end of each pass.
@export var loop: bool = true

var song: SongData
## True from start() until the song stops or finishes, including while paused.
var is_playing: bool = false
var is_paused: bool = false

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
# True from start() until the audio position is first seen moving.
var _awaiting_audio: bool = false
# Length of one pass of the song in seconds, or 0 when not looping.
var _loop_length: float = 0.0
# Song time held while paused.
var _paused_song_time: float = 0.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.volume_db = -30
	_player.finished.connect(_on_player_finished)


## Does the slow one-off setup for a song so that start() doesn't hitch. start() calls
## it anyway; call it earlier (song select, loading screen) to move the hitch there.
func prepare(new_song: SongData) -> void:
	# MP3 and Ogg streams loop via a flag on the stream resource itself. This has to be
	# set before the stream is registered as a sample, which bakes the loop mode in.
	if "loop" in new_song.stream:
		new_song.stream.loop = loop
	# Web plays audio as "samples": the whole file is decoded up front the first time a
	# stream is used, which blocks for around a second.
	var playback_type: int = ProjectSettings.get_setting_with_override("audio/general/default_playback_type")
	if playback_type == AudioServer.PLAYBACK_TYPE_SAMPLE \
			and not AudioServer.is_stream_registered_as_sample(new_song.stream):
		AudioServer.register_stream_as_sample(new_song.stream)


func start(new_song: SongData) -> void:
	song = new_song
	prepare(song)
	_loop_length = song.stream.get_length() if loop and "loop" in song.stream else 0.0
	_player.stream = song.stream
	_player.stream_paused = false
	is_paused = false
	_player.play()
	output_latency = AudioServer.get_output_latency()
	# play() returning doesn't mean audio is running, so the clock isn't started here.
	# _process starts it from the audio position once that is seen moving.
	_awaiting_audio = true
	raw_error = 0.0
	smoothed_error = 0.0
	snap_count = 0
	audio_position_reliable = true
	_last_playback_position = 0.0
	_stalled_time = 0.0
	is_playing = true


func stop() -> void:
	_player.stop()
	_player.stream_paused = false
	is_playing = false
	is_paused = false
	_awaiting_audio = false
	_loop_length = 0.0


## Freezes the audio and song time until resume().
func pause() -> void:
	if not is_playing or is_paused:
		return
	_paused_song_time = get_song_time()
	is_paused = true
	_player.stream_paused = true


func resume() -> void:
	if not is_paused:
		return
	is_paused = false
	_player.stream_paused = false
	if _awaiting_audio:
		# Paused before the audio got going: wait to see it move all over again.
		_last_playback_position = 0.0
	else:
		# pause() froze song time at once, but the audio ran on until the next mix.
		# Pick up from where the audio really stopped, not from the frozen value.
		var audio_time := _player.get_playback_position() + AudioServer.get_time_since_last_mix() - output_latency
		_anchor_usec = Time.get_ticks_usec() - int(audio_time * 1000000.0)
	smoothed_error = 0.0
	_stalled_time = 0.0


## Song position being heard right now, in seconds. Negative just after start().
func get_song_time() -> float:
	if is_paused:
		return _paused_song_time
	if _awaiting_audio:
		return -output_latency
	var elapsed := (Time.get_ticks_usec() - _anchor_usec) / 1000000.0
	if _loop_length > 0.0 and elapsed > 0.0:
		return fmod(elapsed, _loop_length)
	return elapsed


## Length of one pass of the song while looping, otherwise 0.
func get_loop_length() -> float:
	return _loop_length


func get_beat_position() -> float:
	return song.time_to_beat(get_song_time())


func _process(delta: float) -> void:
	if not is_playing or is_paused or not _player.playing:
		return

	var playback_position := _player.get_playback_position()
	var audio_time := playback_position + AudioServer.get_time_since_last_mix() - output_latency

	if _awaiting_audio:
		# The position can sit at zero, or on web at a small nonzero value, for a while
		# after play(). Only a change from one nonzero value to another means it's running.
		var is_moving := _last_playback_position > 0.0 and playback_position > _last_playback_position
		_last_playback_position = playback_position
		if is_moving:
			_awaiting_audio = false
			_anchor_usec = Time.get_ticks_usec() - int(audio_time * 1000000.0)
		return

	_update_reliability(playback_position, delta)
	if not drift_correction_enabled or not audio_position_reliable:
		return

	raw_error = audio_time - get_song_time()
	if _loop_length > 0.0:
		# The clock and the audio don't wrap on the same frame; compare the short way round.
		raw_error = wrapf(raw_error, -_loop_length / 2.0, _loop_length / 2.0)

	if absf(raw_error) > snap_threshold:
		_anchor_usec = Time.get_ticks_usec() - int(audio_time * 1000000.0)
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
