extends Node

@export var controlled: PushBody2D

func _unhandled_input(event):
	# We're hard coding the inputs for this demo, since
	# I don't want to clutter actions in userland.
	if event is InputEventKey:
		if event.is_pressed() and !event.is_echo():
			if event.keycode == KEY_W:
				controlled.move_tile(Vector2i.UP, true, true)
			if event.keycode == KEY_S:
				controlled.move_tile(Vector2i.DOWN, true, true)
			if event.keycode == KEY_A:
				controlled.move_tile(Vector2i.LEFT, true, true)
			if event.keycode == KEY_D:
				controlled.move_tile(Vector2i.RIGHT, true, true)
			if event.keycode == KEY_SPACE:
				if controlled.is_bar_showing():
					return # Busy already casting, cancel out.
				var t = get_tree().create_tween()
				t.tween_method(_cast.bind("Fireball"), 0.0, 1.0, 1.5)
			if event.keycode == KEY_Q:
				if controlled.is_speaking():
					return
				controlled.speak("Whats up!")
			if event.keycode == KEY_E:
				if controlled.is_speaking():
					return
				controlled.speak("Whaaaats uuuuuup!", 2.0, 3.5)

func _cast(time: float, spell: String):
	controlled.show_bar(spell, time, 0.2)
