extends CharacterBody3D

@onready var animation_tree = $visuals/Untitled/AnimationTree
@onready var visuals = $visuals

const SPRINT_SPEED = 8.0
const SPEED = 2.8
const JUMP_VELOCITY = 4.5
const HIT_STAGGER = 8.0

var is_attacking = false

enum {IDLE, WALK, RUN, ATTACK}
var curAnim = IDLE

signal player_hit

@export var blend_speed = 15

var walk_val = 0
var run_val = 0

@onready var camera_mount = $camera_mount

@export var sens_horizontal = 0.5
@export var sens_vertical = 0.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x*sens_horizontal))
		visuals.rotate_y(deg_to_rad(event.relative.x*sens_horizontal))
		camera_mount.rotate_x(deg_to_rad(-event.relative.y*sens_vertical))

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# AnimTree Animations
	handle_animations(delta)

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Handle Slash
	if Input.is_action_just_pressed("attack") and not is_attacking:
		is_attacking = true
		walk_val = 0
		run_val = 0
		animation_tree["parameters/Attack/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
		var anim_player = $visuals/Untitled/AnimationPlayer
		var attack_length = anim_player.get_animation("attack/attack").length
		get_tree().create_timer(attack_length).timeout.connect(func():
			is_attacking = false
			curAnim = IDLE
			)

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	# Sprint
	var is_sprinting = Input.is_action_pressed("sprint") and direction != Vector3.ZERO
	var current_speed = SPRINT_SPEED if is_sprinting else SPEED
	if direction and not is_attacking:
		visuals.look_at(position + direction)
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		
		if is_sprinting:
			if curAnim != RUN:
				curAnim = RUN
		else:
			if curAnim != WALK:
				curAnim = WALK
	else:
		if not is_attacking and curAnim != IDLE:
			curAnim = IDLE
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "attack/attack":
		is_attacking = false

func handle_animations(delta):
	match curAnim:
		IDLE:
			walk_val = lerpf(walk_val,0,blend_speed*delta)
			run_val = lerpf(run_val,0,blend_speed*delta)
		WALK:
			walk_val = lerpf(walk_val,1,blend_speed*delta)
			run_val = lerpf(run_val,0,blend_speed*delta)
		RUN:
			walk_val = lerpf(walk_val,0,blend_speed*delta)
			run_val = lerpf(run_val,1,blend_speed*delta)

	update_tree()

func update_tree():
	animation_tree["parameters/Walk/blend_amount"] = walk_val
	animation_tree["parameters/Run/blend_amount"] = run_val

func hit(dir):
	emit_signal("player_hit")
	velocity += dir * HIT_STAGGER

