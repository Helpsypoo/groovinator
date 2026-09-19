extends Node3D
## Test stage proving the core timing loop: play a song, press "hit" on the beat.

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
const HINT_STOPPED := "Press Play"
const HINT_PLAYING := "Tap or press Space on the beat"

## Every SongData resource in this folder is offered in the song dropdown.
const SONGS_DIR := "res://songs"

var song: SongData

# Seconds visuals are held back so they are seen when the matching audio is heard.
# Negative draws them ahead instead. Covers (unreported audio latency - display lag).
var av_offset: float = 10.0
# Display lag + input lag, in seconds. Added to av_offset when judging a press, so the
# total is (audio latency + input lag). Shown to the player as just "input lag": it is
# tuned by ear against the music, and naming the display would invite tuning it by eye.
var input_offset: float = 100.0

var _songs: Array[SongData] = []
var _errors: Array[float] = []
var _text_before_pause: String = ""

@onready var _clock: SongClock = %SongClock
@onready var _song_select: OptionButton = %SongSelect
@onready var _lane: Path3D = %NoteLane
@onready var _dancer: Node3D = %Dancer
@onready var _judgment_label: Label = %JudgmentLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _clock_label: Label = %ClockLabel
@onready var _av_slider: HSlider = %AvSlider
@onready var _av_value: Label = %AvValue
@onready var _input_slider: HSlider = %InputSlider
@onready var _input_value: Label = %InputValue
@onready var _play_pause_button: Button = %PlayPauseButton
@onready var _restart_button: Button = %RestartButton


func _ready() -> void:
	_load_songs()
	_on_song_selected(0)
	_on_av_slider_changed(_av_slider.value)
	_on_input_slider_changed(_input_slider.value)
	_update_stats()

	_song_select.item_selected.connect(_on_song_selected)
	_av_slider.value_changed.connect(_on_av_slider_changed)
	_input_slider.value_changed.connect(_on_input_slider_changed)
	_play_pause_button.pressed.connect(_on_play_pause_pressed)
	_restart_button.pressed.connect(_restart)
	%ResetStatsButton.pressed.connect(_reset_stats)
	_clock.finished.connect(_update_transport)


func _load_songs() -> void:
	# ResourceLoader rather than DirAccess: it still sees the original file names
	# in exported builds, where resources are converted and remapped.
	var files := ResourceLoader.list_directory(SONGS_DIR)
	files.sort()
	for file in files:
		if file.get_extension() != "tres":
			continue
		var loaded := load(SONGS_DIR.path_join(file)) as SongData
		if loaded != null:
			_songs.append(loaded)
			_song_select.add_item(loaded.title)
	assert(not _songs.is_empty(), "No SongData resources found in %s" % SONGS_DIR)


func _on_song_selected(index: int) -> void:
	_clock.stop()
	song = _songs[index]
	_clock.prepare(song)
	_judgment_label.text = HINT_STOPPED
	_reset_stats()
	_update_transport()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("hit") and not event.is_echo():
		_hit()


func _unhandled_input(event: InputEvent) -> void:
	# Taps are taken here rather than in _input so that the GUI gets first refusal:
	# a tap on a button or the tray is not also a hit.
	if _is_tap(event):
		_hit()
	elif event.is_action_pressed("ui_cancel") and _clock.is_playing:
		_set_paused(not _clock.is_paused)


func _is_tap(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		# Every finger counts, so two thumbs can alternate.
		return event.pressed
	# Clicks count too, for desktop. A touch also arrives as an emulated click,
	# which must not be counted a second time.
	return event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION


func _hit() -> void:
	if _clock.is_paused:
		return
	# Sample the clock here rather than in _process: this is as close to the
	# physical press as the engine lets us get.
	var time := _clock.get_song_time() - av_offset - input_offset
	_dancer.hit()
	if _clock.is_playing:
		_judge(time)


func _process(_delta: float) -> void:
	_lane.song = song
	_lane.loop_length = _clock.get_loop_length()
	if not _clock.is_playing:
		_lane.time = 0.0
		_lane.marker_color = Color.DIM_GRAY
		return

	var visual_time := _clock.get_song_time() - av_offset
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


func _on_play_pause_pressed() -> void:
	if _clock.is_playing:
		_set_paused(not _clock.is_paused)
	else:
		_restart()


func _restart() -> void:
	_clock.start(song)
	_judgment_label.text = HINT_PLAYING
	_reset_stats()
	_update_transport()
	_dancer.start_idle()


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
	_update_transport()


func _update_transport() -> void:
	var running := _clock.is_playing and not _clock.is_paused
	_play_pause_button.text = "Pause" if running else "Play"
	_restart_button.disabled = not _clock.is_playing


func _on_av_slider_changed(value: float) -> void:
	av_offset = value / 1000.0
	_av_value.text = "%+d ms" % int(value)
	_reset_stats()


func _on_input_slider_changed(value: float) -> void:
	input_offset = value / 1000.0
	_input_value.text = "%d ms" % int(value)
	_reset_stats()
