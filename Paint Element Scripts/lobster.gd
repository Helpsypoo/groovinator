extends PickableAnimatedSprite3D
## The lobster dancer in the painting: dances when poked. The point-and-click
## mode listens to the clicks to reveal the title and start the game.


func on_click() -> void:
	# play() on the animation that is already playing is a no-op, so stop()
	# first to restart the dance on every click.
	stop()
	play(&"DANCE1")
