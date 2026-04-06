extends Area2D

@export var color: int = 0 # 0=bleu, 1=jaune, 2=rouge
@export var fall_speed: float = 400.0
@export var spawn_time: float = 0.0
@export var hit_y: float = 560.0

@onready var tile_panel: Panel = $TilePanel
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var burst: CPUParticles2D = $BurstParticles

var has_been_hit: bool = false
var is_missed: bool = false

const COLORS := {
	0: Color("#5FCDE4"), # bleu
	1: Color("#F0E040"), # jaune
	2: Color("#FF7081"), # rouge
}

const GLOW_COLORS := {
	0: Color(0.373, 0.804, 0.894, 0.3),
	1: Color(0.941, 0.878, 0.251, 0.3),
	2: Color(1.0, 0.439, 0.506, 0.3),
}

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLORS[color]
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_left = 999
	style.corner_radius_bottom_right = 999
	style.shadow_color = GLOW_COLORS[color]
	style.shadow_size = 15
	tile_panel.add_theme_stylebox_override("panel", style)
	tile_panel.pivot_offset = tile_panel.size / 2.0

	var shape := RectangleShape2D.new()
	shape.size = tile_panel.size
	collision.shape = shape

	burst.color = COLORS[color]
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.15)

func _process(delta: float) -> void:
	if has_been_hit or is_missed:
		return
	if position.y >= hit_y:
		position.y = hit_y
	else:
		position.y += fall_speed * delta

func get_note_color() -> int:
	return color

func hit_animation(result: String) -> void:
	has_been_hit = true
	burst.emitting = true
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(tile_panel, "scale", Vector2(1.15, 1.15), 0.15)
	tween.tween_property(tile_panel, "modulate:a", 0.0, 0.15)
	tween.chain().tween_interval(0.25)
	tween.tween_callback(queue_free)

func miss_animation() -> void:
	is_missed = true
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(tile_panel, "scale", Vector2(0.8, 0.8), 0.2)
	tween.tween_property(tile_panel, "modulate", Color(1.0, 0.2, 0.2, 0.0), 0.2)
	tween.chain().tween_callback(queue_free)
