extends Area2D

@export var color: int = 0 # 0=bleu, 1=jaune, 2=rouge
@export var fall_speed: float = 400.0
@export var spawn_time: float = 0.0
@export var hit_y: float = 560.0

@onready var circle: Polygon2D = $Circle
@onready var glow: Polygon2D = $Glow
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var burst: CPUParticles2D = $BurstParticles

var has_been_hit: bool = false
var is_missed: bool = false

const RADIUS := 28.0
const GLOW_RADIUS := 38.0
const SEGMENTS := 32

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

func _make_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var angle := (TAU / segments) * i
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	return pts

func _ready() -> void:
	# Générer les polygones circulaires
	var circle_pts := _make_circle_polygon(RADIUS, SEGMENTS)
	var glow_pts := _make_circle_polygon(GLOW_RADIUS, SEGMENTS)
	circle.polygon = circle_pts
	glow.polygon = glow_pts

	# Collision shape circulaire
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	collision.shape = shape

	_apply_color()
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self , "modulate:a", 1.0, 0.15)

func _apply_color() -> void:
	circle.color = COLORS[color]
	glow.color = GLOW_COLORS[color]
	burst.color = COLORS[color]

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
	circle.hide()
	glow.hide()
	
	var tween := create_tween()
	# The lifetime of particles is 0.4s
	tween.tween_interval(0.4)
	tween.tween_callback(queue_free)

func miss_animation() -> void:
	is_missed = true
	burst.emitting = true
	circle.hide()
	glow.hide()
	
	var tween := create_tween()
	tween.tween_interval(0.4)
	tween.tween_callback(queue_free)
