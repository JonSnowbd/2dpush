@tool
@icon("res://addons/2dpush/icon/push_icon.svg")
extends CharacterBody2D
class_name PushBody2D

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

class MovementQueryResults extends RefCounted:
	var can_move: bool = false
	var entities_in_the_way: Array[Node2D] = []
	var will_stack_into: Array[PushBody2D] = []
class BodyQueryResults extends RefCounted:
	var bodies: Array[PushBody2D] = []

static var buckets: Dictionary = {}

@export_subgroup("Tile Behaviour")
## Optional, will insert this body into the chosen tilemap on _ready if
## this is set.
@export var initial_tilemap: TileMap
## If true, this body will set the tile position to the nearest
## cell of the tilemap on _ready. If you're using an initial map, and
## are placing these bodies in editor, this is recommended, they will go to their
## nearest tile.
@export var auto_insert_to_nearest_tile: bool = true
## If true, bodies querying for pushable bodies will push this body when moving.
@export var pushable: bool = false
## If true, collisions, even if they overlap, will only report for body and tilemap
## collisions if they share a tilemap, or are children of the same tilemap.
@export var only_interact_with_own_tilemap: bool = true

@export_subgroup("Agent Behaviour", "agent_")
## This node will have its global_position set to the agent
## position every frame using physics frame interp.
## Preferably this agent should be a child of this push body.
@export var agent_reference: Node2D
## The simulated agent that follows the tile position will move at this speed per second
## to keep up with the true tile position.
@export var agent_speed: float = 100.0
## The simulated agent will never be farther than the provided offset from the true tile
## position.
@export var agent_max_offset: float = 400.0
## If limitation has a size of atleast 1x1, the body considers the limitation when
## attempting to move, and querying movement.
@export var agent_limitation: Rect2i = Rect2i(0,0,0,0)
## If stack limit is higher than one, pushbodies can share tiles with other pushbodies.
## To limit what can stack with what, implement `body_can_stack_with(other: PushBody2D) -> bool`
@export var agent_stack_limit: int = 1

@export_subgroup("Bar Design", "bar_")
## When you request a bar to draw on this entity, this is used as the texture
## of the filled in part of the bar
@export var bar_fill_texture: StyleBoxTexture : 
	set(val):
		bar_fill_texture = val
		if Engine.is_editor_hint():
			show_bar("Test", 0.5)
## When you request a bar to draw on this entity, this is used as the texture
## of the background part of the bar
@export var bar_background_texture: StyleBoxTexture : 
	set(val):
		bar_background_texture = val
		if Engine.is_editor_hint():
			show_bar("Nice background", 0.5)
@export var bar_size: Vector2 :
	set(val):
		bar_size = val
		if Engine.is_editor_hint():
			show_bar("How big?", 0.5)
@export var bar_offset: Vector2 :
	set(val):
		bar_offset = val
		if Engine.is_editor_hint():
			show_bar("Offset", 0.5)
@export var bar_font: Font : 
	set(val):
		bar_font = val
		if Engine.is_editor_hint():
			show_bar("Shiny font", 0.5)
@export var bar_font_size : float :
	set(val):
		bar_font_size = val
		if Engine.is_editor_hint():
			show_bar("Big or small?", 0.5)
@export var bar_font_color : Color :
	set(val):
		bar_font_color = val
		if Engine.is_editor_hint():
			show_bar("Nice Color", 0.5)
## If true, the bar will be drawn overtop the agents position if applicable, rather
## than the tile body.
@export var bar_based_on_agent: bool = true
@export var bar_text_above: bool = true :
	set(val):
		bar_text_above = val
		if Engine.is_editor_hint():
			show_bar("Text here?", 0.5)

@export_subgroup("Speech", "bubble_")
@export var bubble_background: StyleBoxTexture : 
	set(val):
		bubble_background = val
		if Engine.is_editor_hint():
			speak("Hello there! A test bubble!")
@export var bubble_font: Font : 
	set(val):
		bubble_font = val
		if Engine.is_editor_hint():
			speak("Hello there! A test bubble!")
@export var bubble_font_color: Color = Color.BLACK :
	set(val):
		bubble_font_color = val
		if Engine.is_editor_hint():
			speak("Hello there! A test bubble!")
@export var bubble_font_size: float = 8.0 :
	set(val):
		bubble_font_size = val
		if Engine.is_editor_hint():
			speak("Hello there! A test bubble!")
@export var bubble_offset: Vector2 = Vector2.ZERO :
	set(val):
		bubble_offset = val
		if Engine.is_editor_hint():
			speak("Hello there! A test bubble!")
## If true the bubble will be drawn based on agent position rather than tile position.
@export var bubble_based_on_agent: bool = true

var current_tilemap: TileMap = null
var tile_position: Vector2i = Vector2i.ZERO : 
	set(value):
		var old_position = tile_position
		tile_position = value
		global_position = get_center_of_tile(tile_position)
		if old_position != tile_position:
			Moved.emit(old_position, tile_position)
var agent_position: Vector2
var agent_destination: Vector2
var stacked_with: Array[PushBody2D] = []
var body_locked: bool = false

func _register_into(tilemap: TileMap) -> void:
	var uid = tilemap.get_instance_id()
	if buckets.has(uid):
		buckets[uid].append(self)
	else:
		buckets[uid] = [self]
func _unregister_from(tilemap: TileMap) -> void:
	var uid = tilemap.get_instance_id()
	assert(buckets.has(uid))
	buckets[uid].erase(self)

## Takes an index, and returns the global position center of the tile
## of the tilemap this body is in.
func get_center_of_tile(index: Vector2i) -> Vector2:
	assert(current_tilemap != null)
	var siz: Vector2i = current_tilemap.tile_set.tile_size
	return current_tilemap.to_global(current_tilemap.map_to_local(index))
## Takes a global position and returns the tile index of the tilemap it currently inhabits.
func get_tile_under_global_position(global_pos: Vector2) -> Vector2i:
	assert(current_tilemap != null)
	return current_tilemap.local_to_map(current_tilemap.to_local(global_pos))

## A simple query, checks what the results of the offset would be.
## For an advanced query that 
func query_movement(offset: Vector2i) -> MovementQueryResults:
	var query: MovementQueryResults = MovementQueryResults.new()
	var target_tile: Vector2i = tile_position+offset
	
	# Construct a physics server direct query
	var shape = PhysicsServer2D.body_get_shape(self, 0)
	var state = get_world_2d().direct_space_state
	var global_test_position = get_center_of_tile(target_tile)
	var world_query = PhysicsShapeQueryParameters2D.new()
	world_query.shape_rid = shape
	world_query.transform = Transform2D.IDENTITY.translated(global_test_position)
	world_query.collision_mask = collision_mask
	
	var intersections = state.intersect_shape(world_query)
	
	for item in intersections:
		if item["collider"] is Node2D:
			query.entities_in_the_way.append(item["collider"] as Node2D)
	
	# For now default to this check for move_validity
	query.can_move = len(intersections) <= 0
	
	if agent_limitation.size.x > 0 and agent_limitation.size.y > 0:
		if !agent_limitation.has_point(target_tile):
			query.can_move = false
	
	return query

## Takes a rect search area and returns push bodies in the same tilemap in that area
func query_bodies_rect(search_area: Rect2i) -> BodyQueryResults:
	var query: BodyQueryResults = BodyQueryResults.new()
	return query

## Moves the agent towards a position, and returns true when it reaches the position.
## If you're taking manual control and locking the body, this is perfect for moving the
## agent.
func move_agent_towards(global_pos: Vector2, delta: float, move_speed_mult: float = 1.0) -> bool:
	if global_pos == agent_position:
		return false
	if agent_reference != null and global_pos.distance_to(agent_position) > agent_max_offset:
		skip_smoothing()
		return true
	agent_position = agent_position.move_toward(global_pos, (agent_speed*delta) * move_speed_mult)
	var reached = agent_position.distance_to(global_pos) < 0.015
	if reached:
		agent_position = global_pos
	if agent_reference != null:
		agent_reference.global_position = agent_position
	return reached

## Moves the pushbody instantly. If check_validity is true, a query will be
## performed to see if the move is possible. Additional parameters control
## if pushes are sent (the obstructing nodes will receive a push) or received
## (this node will receive a list of obstructing nodes to push)
func move_tile(offset: Vector2i, check_validity: bool = true, send_pushes: bool = false, receive_pushes: bool = false) -> void:
	if body_locked:
		return
	if check_validity:
		var query: MovementQueryResults = query_movement(offset)
		if query.can_move:
			tile_position = tile_position+offset
		else:
			var failed: bool = true
			var relevant_nodes: Array[PushBody2D] = []
			for node in query.entities_in_the_way:
				if node is PushBody2D:
					if !node.pushable:
						continue
					if send_pushes:
						node.receiving_push(self)
						failed = false
					if receive_pushes:
						relevant_nodes.append(node as PushBody2D)
						failed = false
			if receive_pushes and len(relevant_nodes) > 0:
				SentPushes.emit(relevant_nodes, tile_position+offset)
				sending_pushes(relevant_nodes)
			if failed:
				FailedMovement.emit(offset)
	else:
		tile_position = tile_position + offset

func set_limitation(limits: Rect2i):
	agent_limitation = limits
	Limited.emit(limits)
func clear_limitation():
	agent_limitation = Rect2i(0,0,0,0)
	Unlimited.emit()

func is_locked() -> bool:
	return body_locked

## Prevents the agent logic from running every frame, so you are free to move
## the agent in code as you want. Useful for cinematics,
## see the source code for move_along_path for an example.
## Returns true if you are clear to use the lock, returns false if something
## else already locked it.
func lock() -> bool:
	if body_locked:
		return false
	body_locked = true
	return true
## Resumes normal _process. if reset_position is true, the tile_position is
## assigned based on the current agent position.
func unlock(reset_position: bool = false) -> void:
	if reset_position:
		tile_position = get_tile_under_global_position(global_position)
	body_locked = false

## Leaves the current tilemap if applicable, and then enters the new tilemap.
func enter_tilemap(tilemap: TileMap) -> void:
	if current_tilemap != null:
		leave_tilemap()
	current_tilemap = tilemap
	_register_into(tilemap)
	TilemapChanged.emit(tilemap)
## Unregisters from the tilemap. Using tile-related methods will fail,
## and _process related functions and signals will no longer call.
func leave_tilemap() -> void:
	assert(current_tilemap != null)
	_unregister_from(current_tilemap)
	current_tilemap = null
	TilemapChanged.emit(null)

## When called, the agent will be set to their final
## destination.
func skip_smoothing() -> void:
	if agent_reference != null:
		agent_position = global_position
		agent_reference.global_position = agent_position

var _speech_duration: float = -1.0
var _speech_fade: float = 0.0
var _speech_active: bool = false
var _speech_percent: float = 0.0
var _speech_string: String = ""
## Activates a speech bubble containing this string.
## The total time it is visible will be the sum of the write in duration
## and total duration. If total_duration is less than 0, the speech bubble
## will stay until you call this function again with no parameters.
func speak(string: String = "", write_in_duration: float = 0.33, total_duration: float = 2.0) -> void:
	if string == "":
		_speech_active = false
		return
	_speech_duration = total_duration
	_speech_active = true
	_speech_percent = 0.0
	_speech_fade = write_in_duration
	_speech_string = string
	queue_redraw()
func is_speaking() -> bool:
	return _speech_active

var _bar_duration: float = -1.0
var _bar_text: String = ""
var _bar_completion: float = 0.0
var _bar_color: Color = Color.WHITE
var _bar_fade: float = 0.0
## Don't worry about cancelling the bar,
## It will go away after not being called for about 2 seconds.
## If you do not want text with the bar, simply pass "" as the name,
## There will be no waste on font rendering.
func show_bar(name: String, completion: float, linger_duration: float = 2.0, color: Color = Color.WHITE, fade_duration: float = 0.15) -> void:
	_bar_duration = linger_duration
	_bar_text = name
	_bar_completion = completion
	_bar_color = color
	_bar_fade = fade_duration
	queue_redraw()
func is_bar_showing() -> bool:
	return _bar_duration > 0.0

func _ready():
	if Engine.is_editor_hint():
		return
	if initial_tilemap == null:
		if get_parent() is TileMap:
			enter_tilemap(current_tilemap)
		else:
			push_error("PushBody "+name+" entered tree, but did not enter a Tilemap, and was not passed an initial tilemap.")
	else:
		enter_tilemap(initial_tilemap)
	if auto_insert_to_nearest_tile:
		tile_position = get_tile_under_global_position(global_position)
		skip_smoothing()
	if agent_limitation.size.x > 0 and agent_limitation.size.y > 0:
		Limited.emit(agent_limitation)
func _exit_tree():
	if current_tilemap != null:
		_unregister_from(current_tilemap)

func _sort_stack(left: PushBody2D, right: PushBody2D):
	return left.get_instance_id() < right.get_instance_id()

func _process(delta):
	if Engine.is_editor_hint() == false and !body_locked:
		var agent_target: Vector2 = get_center_of_tile(tile_position)
		if len(stacked_with) > 0:
			var stack: Array[PushBody2D] = [self]
			stack.append_array(stacked_with)
			stack.sort_custom(_sort_stack)
			var index = stack.find(self)
			# TODO offset the agent target to fit in the stack.
		if move_agent_towards(agent_target, delta):
			AgentCaughtUp.emit()
	var redraw: bool = false
	if _bar_duration >= 0.0:
		_bar_duration -= delta
		redraw = true
	if _speech_active:
		if _speech_percent < 1.0:
			_speech_percent = clamp(_speech_percent+(delta/_speech_fade), 0.0, 1.0)
			SpeechUpdate.emit()
			redraw = true
		if _speech_duration > 0.0:
			_speech_duration -= delta
			redraw = true
			if _speech_duration <= 0.0:
				_speech_active = false
	
	if redraw:
		queue_redraw()

func _draw_speech():
	const default_speech_bubble: StyleBox = preload("res://addons/2dpush/resource/default_speech_bubble.tres")
	const default_speech_font: Font = preload("res://addons/2dpush/resource/default_font.tres")
	if !_speech_active:
		return
	var sp_bg = bubble_background if bubble_background != null else default_speech_bubble
	var sp_fnt = bubble_font if bubble_font != null else default_speech_font
	var proposition: String = _speech_string
	if _speech_percent < 1.0:
		var string_count = max(int(float(len(_speech_string)) * _speech_percent), 1)
		proposition = _speech_string.substr(0, string_count)
		
	var stamp = Rect2(Vector2.ZERO, Vector2.ZERO)
	stamp.size = sp_fnt.get_string_size(proposition, 0, -1, bubble_font_size)
	
	if bubble_based_on_agent and !Engine.is_editor_hint() and agent_reference != null:
		stamp.position = to_local(agent_reference.global_position) - (stamp.size * 0.5)
	else:
		stamp.position = to_local(global_position) - (stamp.size * 0.5)
	stamp.position -= bubble_offset
	
	var alpha = clamp(_speech_duration*8.0, 0.0, 1.0)
	
	var pre = sp_bg.modulate_color
	if _speech_duration >= 0.0:
		sp_bg.modulate_color.a = alpha
	draw_style_box(sp_bg, stamp)
	sp_bg.modulate_color = pre

	
	var string_position = stamp.position + Vector2(0, stamp.size.y)
	var font_col = bubble_font_color
	font_col.a = alpha
	
	draw_string(sp_fnt, string_position, proposition, 0, -1, bubble_font_size, font_col)

func _draw_bar():
	const default_bar_fill: StyleBox = preload("res://addons/2dpush/resource/default_bar_fill.tres")
	const default_bar_background: StyleBox = preload("res://addons/2dpush/resource/default_bar_background.tres")
	const default_bar_font: Font = preload("res://addons/2dpush/resource/default_font.tres")
	
	var bar_fill: StyleBox = bar_fill_texture if bar_fill_texture != null else default_bar_fill
	var bar_bg: StyleBox = default_bar_background if default_bar_background != null else default_bar_background
	var bar_font: Font = bar_font if bar_font != null else default_bar_font
	if _bar_duration > 0.0:
		var rect = Rect2(Vector2.ZERO, bar_size)
		var alpha = clamp(_bar_duration / _bar_fade, 0.0, 1.0)
		if bar_based_on_agent and !Engine.is_editor_hint() and agent_reference != null:
			rect.position = to_local(agent_reference.global_position) - (bar_size * 0.5)
		else:
			rect.position = to_local(global_position) - (bar_size * 0.5)
		rect.position += bar_offset
		
		var bg_pre_color = bar_bg.modulate_color
		bar_bg.modulate_color.a = alpha
		draw_style_box(bar_bg, rect)
		bar_bg.modulate_color = bg_pre_color
		
		rect.size.x *= _bar_completion
		
		# Fill
		var pre_color = bar_fill.modulate_color
		bar_fill.modulate_color = _bar_color
		bar_fill.modulate_color.a = alpha
		draw_style_box(bar_fill, rect)
		bar_fill.modulate_color = pre_color

		if _bar_text != "":
			var col = bar_font_color
			col.a = alpha
			if !bar_text_above:
				var measure = bar_font.get_string_size(_bar_text, HORIZONTAL_ALIGNMENT_LEFT, -1, bar_font_size)
				rect.position.y += bar_size.y+measure.y
			else:
				rect.position.y -= 1
			draw_string(bar_font, rect.position, _bar_text, HORIZONTAL_ALIGNMENT_LEFT, -1, bar_font_size, col)
		
func _draw():
	_draw_bar()
	_draw_speech()

func receiving_push(from: PushBody2D) -> void:
	ReceivedPush.emit(from)
func sending_pushes(to: Array[PushBody2D]) -> void:
	pass

## Override this in your subclass to be picky, default implementation is to stack
## with any other pushbody.
func body_can_stack_with(other: PushBody2D) -> bool:
	return true
