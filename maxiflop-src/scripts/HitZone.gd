extends Node2D

@export var hit_y: float = 560.0
@export var note_spawner: NodePath

@onready var spawner: Node2D = get_node_or_null(note_spawner)

@onready var btn_blue := get_node_or_null("../HitCircleBlue")
@onready var btn_yellow := get_node_or_null("../HitCircleYellow")
@onready var btn_red := get_node_or_null("../HitCircleRed")

const KEY_BLUE := KEY_A
const KEY_YELLOW := KEY_S
const KEY_RED := KEY_D

func _ready() -> void:
	GameManager.game_started.connect(_on_game_started)
	GameManager.game_over.connect(_on_game_over)

func _on_game_started() -> void:
	pass

func _on_game_over() -> void:
	pass

func _unhandled_key_input(event: InputEvent) -> void:
	if not GameManager.is_playing:
		return
	if not event.pressed:
		return

	match event.keycode:
		KEY_BLUE:
			_try_hit(0, btn_blue)
		KEY_YELLOW:
			_try_hit(1, btn_yellow)
		KEY_RED:
			_try_hit(2, btn_red)

func press_button(col: int) -> void:
	match col:
		0: _try_hit(0, btn_blue)
		1: _try_hit(1, btn_yellow)
		2: _try_hit(2, btn_red)

func _try_hit(col: int, btn: Node) -> void:
	_flash_button(btn, col)

	if spawner == null:
		spawner = get_node_or_null(note_spawner)
	if spawner == null:
		return

	var notes_nearby = spawner.get_notes_near_hit(col, hit_y)
	if notes_nearby.is_empty():
		GameManager.register_miss()
		return

	var closest_note = notes_nearby[0]
	var timing_error: float = abs(closest_note.position.y - hit_y) / 560.0
	var result := GameManager.register_hit(timing_error, true)
	closest_note.hit_animation(result)

func _flash_button(btn: Node, col: int) -> void:
	if btn == null:
		return
	col = col
	var original_scale = btn.scale
	var tween := create_tween()
	tween.tween_property(btn, "scale", original_scale * 1.15, 0.05)
	tween.tween_property(btn, "scale", original_scale, 0.1)
