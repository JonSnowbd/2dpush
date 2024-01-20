## 2DPush

A simple drop-in physics character that is based around tilemap movement. Rewritten and extracted logic
from a personal project to tidy up and reuse code.

### How

Add a `PushBody2D` to your scene, and place it as a child node of a tilemap, or assign `initial_tilemap` in the editor.
If you're creating it in code, simply assign `initial_tilemap` before adding it as a child.

`PushBody2D` comes with speech bubbles and annotated progress bars for free. Not using these features means nothing is done
and will not incur any performance cost. Not that using them would impact anything either.

### General Idea

`PushBody2D` handles everything position wise. You extend it by adding bits that `get_parent() as PushBody2D` and control it
and listen to it from there. See the [source code](https://github.com/JonSnowbd/2dpush/blob/main/script/push_body_marker_sprite.gd) for an example.

### Signals

```gdscript
## Called when this entity enters or leaves a tilemap.
## Since this includes leaving, `new_tilemap` can be null.
signal TilemapChanged(new_tilemap: TileMap)
## Called when the tile_position changes.
signal Moved(old_tile: Vector2i, new_tile: Vector2i)
## Called when tile movement is requested, but it cannot move.
signal FailedMovement(attempted_offset: Vector2i)
## Called when the simulated agent position reaches the tile center.
signal AgentCaughtUp
## Called when a push body attempted to push into this one.
signal ReceivedPush(from: PushBody2D)
## Called and gives a list of bodies when attempting to push into a new space.
signal SentPushes(to: Array[PushBody2D], on: Vector2i)
## Called when a limitation is applied to the push body
signal Limited(new_limitations: Rect2i)
## Called when the limitation is released.
signal Unlimited()
## Called when the speech text updates, as its writing in. Useful
## to use this for Undertale style voice effects.
signal SpeechUpdate()
```

### Common Functions

```gdscript
## Moves the pushbody instantly. If check_validity is true, a query will be
## performed to see if the move is possible. Additional parameters control
## if pushes are sent (the obstructing nodes will receive a push) or received
## (this node will receive a list of obstructing nodes to push)
func move_tile(offset: Vector2i, check_validity: bool = true, send_pushes: bool = false, receive_pushes: bool = false) -> void

## A simple query, checks what the results of the offset would be.
## For an advanced query that 
func query_movement(offset: Vector2i) -> MovementQueryResults

## Takes an index, and returns the global position center of the tile
## of the tilemap this body is in.
func get_center_of_tile(index: Vector2i) -> Vector2

## Takes a global position and returns the tile index of the tilemap it currently inhabits.
func get_tile_under_global_position(global_pos: Vector2) -> Vector2i

## Moves the agent towards a position, and returns true when it reaches the position.
## If you're taking manual control and locking the body, this is perfect for moving the
## agent.
func move_agent_towards(global_pos: Vector2, delta: float, move_speed_mult: float = 1.0) -> bool

## Prevents the agent logic from running every frame, so you are free to move
## the agent in code as you want. Useful for cinematics,
## see the source code for move_along_path for an example.
## Returns true if you are clear to use the lock, returns false if something
## else already locked it.
func lock() -> bool

## Resumes normal _process. if reset_position is true, the tile_position is
## assigned based on the current agent position. 
func unlock(reset_position: bool = false) -> void

## Resumes normal _process. if reset_position is true, the tile_position is
## assigned based on the current agent position.
func unlock(reset_position: bool = false) -> void:
	if reset_position:
		tile_position = get_tile_under_global_position(global_position)
	body_locked = false

## Leaves the current tilemap if applicable, and then enters the new tilemap.
func enter_tilemap(tilemap: TileMap) -> void

## Unregisters from the tilemap. Using tile-related methods will fail,
## and _process related functions and signals will no longer call.
func leave_tilemap() -> void

## When called, the agent will be set to their final
## destination.
func skip_smoothing() -> void

## Activates a speech bubble containing this string.
## The total time it is visible will be the sum of the write in duration
## and total duration. If total_duration is less than 0, the speech bubble
## will stay until you call this function again with no parameters.
func speak(string: String = "", write_in_duration: float = 0.33, total_duration: float = 2.0) -> void

func is_speaking() -> bool

## Don't worry about cancelling the bar,
## It will go away after not being called for about 2 seconds.
## If you do not want text with the bar, simply pass "" as the name,
## There will be no waste on font rendering.
func show_bar(name: String, completion: float, linger_duration: float = 2.0, color: Color = Color.WHITE, fade_duration: float = 0.15) -> void

func is_bar_showing() -> bool
```

### Cheatsheet

- `PushBodyMarker` is a sprite2d that can be added as a child to a pushbody2d to show visuals for a pushbody's actions.
it will pop up and fade away to show new locations, failed movements, and pushes.
- `PushBody2D.speak("hi")` pushbodies come with an extremely simple, optional, and easily stylable overhead chat option.
You can preview your styling in editor.
- `PushBody2D.show_bar("HP", current_hp/max_hp)` takes in 0-1 as progress for the bar, it will show up and stay for a set amount
of time before fading away. Perfect for notifying a cast time, or showing hp for a bit.
- `PushBody2D.move_tile`