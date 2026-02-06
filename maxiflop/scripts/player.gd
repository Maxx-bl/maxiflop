extends CharacterBody2D

@export var speed = 200.0
@export var jump_velocity = -540.0
@export var acceleration = 800.0
@export var friction = 1000.0

@onready var sprite = $AnimatedSprite2D	

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var direction = Input.get_axis("left", "right")

	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)

	move_and_slide()
	animate(direction)

func animate(direction): 
	handle_direction(direction)
	if not is_on_floor(): 
		sprite.play("jump")
	elif velocity.x != 0:
		sprite.play("walk")
	else:
		sprite.play("idle")

func handle_direction(direction): 
	if direction != 0:
		sprite.flip_h = direction == -1