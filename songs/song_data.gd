class_name SongData
extends Resource
## A playable song plus the timing info needed to line a beat grid up with it.

## Name shown in-game.
@export var title: String = ""
@export var stream: AudioStream
@export var bpm: float = 120.0
## Position in the audio file, in seconds, of the first beat.
@export var first_beat_offset: float = 0.0


func get_beat_length() -> float:
	return 60.0 / bpm


func time_to_beat(time: float) -> float:
	return (time - first_beat_offset) / get_beat_length()


func beat_to_time(beat: float) -> float:
	return first_beat_offset + beat * get_beat_length()
