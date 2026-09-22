class_name PickableAnimatedSprite3D
extends AnimatedSprite3D
## An AnimatedSprite3D the player can click and hover. Only its opaque pixels
## count, so a click on the transparent part of one element reaches whatever is
## painted behind it. The scene's [SpritePicker] does the finding.
##
## To give an element behaviour, attach a script that extends this one and
## override [method on_click], [method on_hover_enter] and [method on_hover_exit].
## Nothing else is needed: the sprite joins the picker's group by itself.
##
## [codeblock]
## extends PickableAnimatedSprite3D
##
## func on_click() -> void:
##     play(&"wave")
##
## func on_hover_enter() -> void:
##     modulate = Color(1.0, 1.0, 0.7)
##
## func on_hover_exit() -> void:
##     modulate = Color.WHITE
## [/codeblock]
##
## [signal clicked], [signal hover_entered] and [signal hover_exited] fire after
## the matching method, for other nodes that want to react too.


## Emitted after [method on_click].
signal clicked
## Emitted after [method on_hover_enter].
signal hover_entered
## Emitted after [method on_hover_exit].
signal hover_exited

## True while the cursor is over an opaque pixel of this sprite.
var hovered: bool = false


func _init() -> void:
	add_to_group(SpritePicker.GROUP)


## Override this to react to a click. The base version does nothing.
func on_click() -> void:
	pass


## Override this to react to the cursor arriving over the sprite.
func on_hover_enter() -> void:
	pass


## Override this to react to the cursor leaving the sprite.
func on_hover_exit() -> void:
	pass


## Runs [method on_click] and emits [signal clicked]. The SpritePicker calls
## this; call it yourself to fake a click.
func click() -> void:
	on_click()
	clicked.emit()


## Marks the sprite hovered, then runs [method on_hover_enter] and emits
## [signal hover_entered]. Does nothing if already hovered.
func hover_enter() -> void:
	if hovered:
		return
	hovered = true
	on_hover_enter()
	hover_entered.emit()


## Marks the sprite not hovered, then runs [method on_hover_exit] and emits
## [signal hover_exited]. Does nothing if not hovered.
func hover_exit() -> void:
	if not hovered:
		return
	hovered = false
	on_hover_exit()
	hover_exited.emit()
