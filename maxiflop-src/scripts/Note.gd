extends Area2D


@export var color: int = 0 # 0=bleu, 1=jaune, 2=rouge
@export var fall_speed: float = 400.0
@export var spawn_time: float = 0.0

@onready var circle := get_node_or_null("Circle")
@onready var glow := get_node_or_null("Glow")

var has_been_hit: bool = false
var is_missed: bool = false

const COLORS := {
    0: Color("#5FCDE4"), # bleu
    1: Color("#F0E040"), # jaune
    2: Color("#FF7081"), # rouge
}

const GLOW_COLORS := {
    0: Color(0.373, 0.804, 0.894, 0.4),
    1: Color(0.941, 0.878, 0.251, 0.4),
    2: Color(1.0, 0.439, 0.506, 0.4),
}

func _ready() -> void:
	_apply_color()
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self , "modulate:a", 1.0, 0.15)

func _apply_color() -> void:
	if circle:
		circle.modulate = COLORS[color]
	if glow:
		glow.modulate = GLOW_COLORS[color]
	modulate = COLORS[color]

func _process(delta: float) -> void:
	if has_been_hit or is_missed:
		return
	position.y += fall_speed * delta

func get_note_color() -> int:
	return color

func hit_animation(result: String) -> void:
	has_been_hit = true
	var tween := create_tween()
	
	match result:
		"PERFECT":
			tween.tween_property(self , "scale", Vector2(1.5, 1.5), 0.1)
			tween.tween_property(self , "modulate:a", 0.0, 0.15)
		"GOOD":
			tween.tween_property(self , "scale", Vector2(1.2, 1.2), 0.1)
			tween.tween_property(self , "modulate:a", 0.0, 0.2)
		_:
			tween.tween_property(self , "modulate:a", 0.0, 0.15)
	
	tween.tween_callback(queue_free)

func miss_animation() -> void:
	is_missed = true
	var tween := create_tween()
	tween.tween_property(self , "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
