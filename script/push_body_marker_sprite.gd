@icon("res://addons/2dpush/icon/marker_icon.svg")
extends Sprite2D
class_name PushBodyMarkerSprite

@export_group("Marker Settings", "marker_")
## Should be lower than duration, starting at this amount of time remaining, it will
## begin to fade away
@export var marker_fade_time: float = 0.2
@export var marker_duration: float = 0.3
## The body must move more than once in this amount of time to trigger
## the marker. If this is negative, then the marker will always trigger on move.
@export var marker_rapid_trigger: float = 0.2
@export var marker_normal_color: Color = Color(1.0, 1.0, 1.0, 1.0)

@export var marker_highlight_failures: bool = true
@export var marker_highlight_failure_color: Color = Color(0.9, 0.1, 0.15, 1.0)

@export var marker_highlight_pushes: bool = true
@export var marker_highlight_push_color: Color = Color(0.15, 0.1, 0.8)

var parent: PushBody2D
var active: float = 0.0
var time_since_move: float = 99.0
# Called when the node enters the scene tree for the first time.
func _ready():
	parent = get_parent() as PushBody2D
	if parent == null:
		push_error("Parent of a Push Body Marker Sprite should be or inherit from a PushBody2D.")
	top_level = true
	parent.Moved.connect(_move)
	parent.PushedSomething.connect(_pushed)
	parent.FailedMovement.connect(_fail)
	

func _process(delta):
	visible = active > 0.0
	if active > 0.0:
		active -= delta
	if visible:
		modulate.a = clamp(active/marker_fade_time, 0.0, 1.0)
	time_since_move += delta

func _move(old_tile: Vector2i, new_tile: Vector2i):
	if (time_since_move <= marker_rapid_trigger) or marker_rapid_trigger < 0.0:
		global_position = parent.get_center_of_tile(new_tile)
		self_modulate = marker_normal_color
		active = marker_duration
	time_since_move = 0.0

func _fail(offset: Vector2i):
	if marker_highlight_failures:
		time_since_move = 0.0
		self_modulate = marker_highlight_failure_color
		global_position = parent.get_center_of_tile(parent.tile_position + offset)
		active = marker_duration
func _pushed(other: PushBody2D):
	if marker_highlight_pushes:
		time_since_move = 0.0
		self_modulate = marker_highlight_push_color
		global_position = parent.get_center_of_tile(other.tile_position)
		active = marker_duration
