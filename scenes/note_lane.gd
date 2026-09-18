extends Control
## Notes scroll right to left and cross a stationary bar exactly on their beat.
##
## The owner feeds in the time to draw for (already shifted by the A/V offset) and
## the bar colour each frame; this node only draws.

## Seconds a note takes to travel from the right edge to the bar.
@export var lead_time: float = 2.0
## Distance of the bar from the left edge, in pixels. Notes keep going past it.
@export var bar_x: float = 100.0
@export var bar_width: float = 8.0
@export var note_radius: float = 22.0
@export var note_color: Color = Color.WHITE
@export var lane_color: Color = Color(0.12, 0.12, 0.14)

var song: SongData
var time: float = 0.0
var bar_color: Color = Color.DIM_GRAY


func _ready() -> void:
	clip_contents = true


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), lane_color)
	if song != null:
		_draw_notes()
	draw_rect(Rect2(bar_x - bar_width / 2.0, 0.0, bar_width, size.y), bar_color)


func _draw_notes() -> void:
	var pixels_per_second := (size.x - bar_x) / lead_time
	# Time span currently on screen, padded so notes slide fully off both edges.
	var margin := note_radius / pixels_per_second
	var earliest := time - bar_x / pixels_per_second - margin
	var latest := minf(time + lead_time + margin, song.stream.get_length())

	var first_beat := maxi(0, ceili(song.time_to_beat(earliest)))
	var last_beat := floori(song.time_to_beat(latest))
	for beat in range(first_beat, last_beat + 1):
		var x := bar_x + (song.beat_to_time(beat) - time) * pixels_per_second
		var color := note_color
		if x < bar_x:
			# Fade out once past the bar.
			color.a = clampf(x / bar_x, 0.0, 1.0)
		draw_circle(Vector2(x, size.y / 2.0), note_radius, color, true, -1.0, true)
