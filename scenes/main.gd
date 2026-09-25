class_name Main
extends Node3D
## The main scene: the shared stage (camera, painting, dancer, song clock, picker
## and the song & calibration drawer) plus a small state machine over the
## [GameMode] nodes under %Modes.
##
## One mode runs at a time. The rest sit at PROCESS_MODE_DISABLED, so their
## _process and input callbacks are silent. A mode hands over by emitting its
## finished signal with the next mode's node name. Data that outlives a mode,
## the chosen song and the calibration offsets, lives here; everything
## mode-specific lives in scenes/modes.


## Emitted after [member song] changes. The clock is already stopped and prepared.
signal song_changed
## Emitted after [member av_offset] or [member input_offset] changes.
signal calibration_changed

## Every SongData resource in this folder is offered in the song dropdown.
const SONGS_DIR := "res://songs"

## Name of the mode node under %Modes to enter at startup. Handy for jumping
## straight into a mode while working on it.
@export var initial_mode: StringName = &"CurtainMode"

var song: SongData

# Seconds visuals are held back so they are seen when the matching audio is heard.
# Negative draws them ahead instead. Covers (unreported audio latency - display lag).
var av_offset: float = 0.0
# Display lag + input lag, in seconds. Added to av_offset when judging a press, so the
# total is (audio latency + input lag). Shown to the player as just "input lag": it is
# tuned by ear against the music, and naming the display would invite tuning it by eye.
var input_offset: float = 0.0

## The mode currently running.
var current_mode: GameMode

var _songs: Array[SongData] = []

@onready var _clock: SongClock = %SongClock
@onready var _modes: Node = %Modes
@onready var _song_select: OptionButton = %SongSelect
@onready var _av_slider: HSlider = %AvSlider
@onready var _av_value: Label = %AvValue
@onready var _input_slider: HSlider = %InputSlider
@onready var _input_value: Label = %InputValue


func _ready() -> void:
	# Silence every mode before anything below can emit a signal they listen to.
	for child in _modes.get_children():
		var mode := child as GameMode
		if mode == null:
			continue
		mode.main = self
		mode.process_mode = Node.PROCESS_MODE_DISABLED
		mode.finished.connect(switch_to)

	_load_songs()
	_song_select.item_selected.connect(_on_song_selected)
	_av_slider.value_changed.connect(_on_av_slider_changed)
	_input_slider.value_changed.connect(_on_input_slider_changed)
	_on_song_selected(0)
	_on_av_slider_changed(_av_slider.value)
	_on_input_slider_changed(_input_slider.value)

	switch_to(initial_mode)


## Leave the current mode, if any, and enter the mode node called [param mode_name].
func switch_to(mode_name: StringName) -> void:
	var next := _modes.get_node_or_null(NodePath(mode_name)) as GameMode
	assert(next != null, "No GameMode named '%s' under %%Modes" % mode_name)
	if next == null or next == current_mode:
		return
	if current_mode != null:
		current_mode.exit()
		current_mode.process_mode = Node.PROCESS_MODE_DISABLED
	current_mode = next
	current_mode.process_mode = Node.PROCESS_MODE_INHERIT
	current_mode.enter()


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
	song_changed.emit()


func _on_av_slider_changed(value: float) -> void:
	av_offset = value / 1000.0
	_av_value.text = "%+d ms" % int(value)
	calibration_changed.emit()


func _on_input_slider_changed(value: float) -> void:
	input_offset = value / 1000.0
	_input_value.text = "%d ms" % int(value)
	calibration_changed.emit()
