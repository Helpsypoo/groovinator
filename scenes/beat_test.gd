extends Control
## Debug scene proving the core timing loop: play a song, press "hit" on the beat.

## Judgment tiers, best first: name and the largest absolute error (seconds) that earns it.
## Anything beyond the last tier is "Bad".
const TIERS: Array[Dictionary] = [
	{"name": "Perfect", "window": 0.020},
	{"name": "Great", "window": 0.045},
	{"name": "Good", "window": 0.080},
	{"name": "Okay", "window": 0.120},
]
# The bar is green inside this tier's window, red outside.
const GREEN_TIER := 0

## Every SongData resource in this folder is offered in the song dropdown.
const SONGS_DIR := "res://songs"

var song: SongData

# Seconds visuals are held back so they are seen when the matching audio is heard.
# Negative draws them ahead instead. Covers (unreported audio latency - display lag).
var av_offset: float = 0.0
# Display lag + input lag, in seconds. Added to av_offset when judging a press, so the
# total is (audio latency + input lag). Shown to the player as just "input lag": it is
# tuned by ear against the music, and naming the display would invite tuning it by eye.
var input_offset: float = 0.0

var _songs: Array[SongData] = []
var _errors: Array[float] = []

@onready var _clock: SongClock = %SongClock
@onready var _song_select: OptionButton = %SongSelect
@onready var _lane: Control = %NoteLane
@onready var _judgment_label: Label = %JudgmentLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _clock_label: Label = %ClockLabel
@onready var _av_slider: HSlider = %AvSlider
@onready var _av_value: Label = %AvValue
@onready var _input_slider: HSlider = %InputSlider
@onready var _input_value: Label = %InputValue
@onready var _bpm_spin: SpinBox = %BpmSpin
@onready var _first_beat_spin: SpinBox = %FirstBeatSpin
@onready var _start_button: Button = %StartButton


func _ready() -> void:
	_load_songs()
	_on_song_selected(0)
	_on_av_slider_changed(_av_slider.value)
	_on_input_slider_changed(_input_slider.value)
	_update_stats()

	_song_select.item_selected.connect(_on_song_selected)
	_av_slider.value_changed.connect(_on_av_slider_changed)
	_input_slider.value_changed.connect(_on_input_slider_changed)
	# Live tweaks for authoring by ear. Not saved: copy the values into the song's .tres.
	_bpm_spin.value_changed.connect(func(value: float) -> void: song.bpm = value)
	_first_beat_spin.value_changed.connect(func(value: float) -> void: song.first_beat_offset = value)
	_start_button.pressed.connect(_on_start_pressed)
	%ResetStatsButton.pressed.connect(_reset_stats)
	_clock.finished.connect(func() -> void: _start_button.text = "Start")


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
	_bpm_spin.set_value_no_signal(song.bpm)
	_first_beat_spin.set_value_no_signal(song.first_beat_offset)
	_start_button.text = "Start"
	_judgment_label.text = "Press Space on the beat"
	_reset_stats()


func _input(event: InputEvent) -> void:
	if not _clock.is_playing:
		return
	if event.is_action_pressed("hit") and not event.is_echo():
		# Sample the clock here rather than in _process: this is as close to the
		# physical press as the engine lets us get.
		_judge(_clock.get_song_time() - av_offset - input_offset)


func _process(_delta: float) -> void:
	_lane.song = song
	if not _clock.is_playing:
		_lane.time = 0.0
		_lane.bar_color = Color.DIM_GRAY
		return

	var visual_time := _clock.get_song_time() - av_offset
	_lane.time = visual_time
	if absf(_error_to_nearest_beat(visual_time)) <= TIERS[GREEN_TIER].window:
		_lane.bar_color = Color.GREEN
	else:
		_lane.bar_color = Color.RED

	_clock_label.text = "beat %.2f   clock vs audio: %+.1f ms (smoothed %+.1f)   snaps: %d   reported latency: %.0f ms%s" % [
		_clock.get_beat_position(),
		_clock.raw_error * 1000.0,
		_clock.smoothed_error * 1000.0,
		_clock.snap_count,
		_clock.output_latency * 1000.0,
		"" if _clock.audio_position_reliable else "   AUDIO POSITION STALLED - correction off",
	]


# Signed distance, in seconds, from the nearest beat. Negative is early.
func _error_to_nearest_beat(time: float) -> float:
	var nearest_beat := roundf(song.time_to_beat(time))
	return time - song.beat_to_time(nearest_beat)


func _judge(time: float) -> void:
	var error := _error_to_nearest_beat(time)
	var tier_name := "Bad"
	for tier in TIERS:
		if absf(error) <= tier.window:
			tier_name = tier.name
			break

	if tier_name == TIERS[0].name:
		_judgment_label.text = tier_name
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
	_stats_label.text = "last %+.0f ms   mean %+.1f ms   std dev %.1f ms   n = %d" % [
		last_error * 1000.0, mean * 1000.0, sqrt(variance) * 1000.0, _errors.size()]


func _reset_stats() -> void:
	_errors.clear()
	_update_stats()


func _on_start_pressed() -> void:
	_clock.start(song)
	_start_button.text = "Restart"
	_reset_stats()


func _on_av_slider_changed(value: float) -> void:
	av_offset = value / 1000.0
	_av_value.text = "%+d ms" % int(value)


func _on_input_slider_changed(value: float) -> void:
	input_offset = value / 1000.0
	_input_value.text = "%d ms" % int(value)
