class_name GameMode
extends Node
## One mode of the game: the curtain, poking at the painting, or the rhythm game.
##
## [Main] keeps exactly one mode running. The others sit at
## [constant Node.PROCESS_MODE_DISABLED], so a mode's _process, _input and
## _unhandled_input only run while it is the current mode. Signals still arrive
## while disabled, so a handler that should only act when current checks
## [method Node.can_process].
##
## A mode ends itself by emitting [signal finished] with the name of the mode
## node to enter next. Modes never reference each other. Shared nodes are reached
## by unique name (%SongClock, %Camera and so on), which works from any node in
## the scene.


## Emitted when this mode is done. [param next_mode] names a node under %Modes.
signal finished(next_mode: StringName)

## The scene root: the shared stage and the data that outlives a mode, such as
## the chosen song and the calibration offsets. Main sets it before the first
## mode is entered; until then it falls back to the scene owner, so it is usable
## from _ready.
var main: Main:
	get:
		if main != null:
			return main
		return owner as Main


## Called when this mode becomes current, after it has been enabled.
func enter() -> void:
	pass


## Called when another mode takes over, before this one is disabled.
func exit() -> void:
	pass


## True for a press that counts as a tap: any touch, or a left click that is not
## the emulated click a touch also produces.
static func is_tap(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		return button.pressed and button.button_index == MOUSE_BUTTON_LEFT \
				and button.device != InputEvent.DEVICE_ID_EMULATION
	return false
