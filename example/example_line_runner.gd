extends Node

@export var move_speed_multiplier: float = 1.0
@export var path: Path2D = null
@export var new_tilemap: TileMap = null

var controller: PushBody2D

var moving: PushBody2D = null

var percentage: float = 0.0

func move_along_path(delta: float) -> bool:
	var point = path.curve.get_closest_offset(moving.agent_position)
	var next_point = path.curve.sample_baked(point + (moving.agent_speed * delta * move_speed_multiplier), true)
	moving.move_agent_towards(path.to_global(next_point), delta, move_speed_multiplier)
	return moving.agent_position.distance_to(path.to_global(path.curve.get_baked_points()[-1])) < 0.1

func _ready():
	controller = get_parent() as PushBody2D
	if controller == null:
		push_error("Line Runner did not have a PushBody2D parent.")
	controller.ReceivedPush.connect(_activated)

func _activated(other: PushBody2D) -> void:
	if other.lock():
		moving = other
		percentage = 0.0

func _process(delta):
	if moving != null:
		if move_along_path(delta):
			if new_tilemap != null:
				moving.enter_tilemap(new_tilemap)
			moving.global_position = moving.agent_position
			moving.unlock(true)
			moving.skip_smoothing()
			moving = null
