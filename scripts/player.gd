# This script controls a 3D player character
# It extends CharacterBody3D, which is Godot's node type for characters that need physics collision
extends CharacterBody3D

# === NODE REFERENCES ===
# @onready means these variables are assigned when the node enters the scene tree (when _ready() is called)
# Gets the AnimationTree node that blends between different animations smoothly
@onready var animation_tree = $visuals/Untitled/AnimationTree
# Gets the visuals node - used to rotate the character model separately from the camera
@onready var visuals = $visuals
# Gets the camera_mount node - this is what the camera is attached to for vertical rotation
@onready var camera_mount = $camera_mount

# === MOVEMENT CONSTANTS ===
const SPRINT_SPEED = 8.0    # How fast the player moves when sprinting
const SPEED = 2.8            # Normal walking speed
const JUMP_VELOCITY = 3.0    # Upward velocity applied when jumping
const HIT_STAGGER = 16.0      # How much the player gets knocked back when hit

# === STATE VARIABLES ===
var is_attacking = false     # Tracks if player is currently in attack animation (prevents movement during attacks)
var is_dead = false
var is_jumping = false

# Enum creates named constants for animation states (makes code more readable than using numbers)
enum {IDLE, WALK, RUN, ATTACK, DIE, JUMP}
var curAnim = IDLE           # Stores the current animation state

# Signal that other nodes can listen to (e.g., UI to update health bar)
signal player_hit
signal player_died

# Player health
var health = 200

# === ANIMATION BLENDING ===
@export var blend_speed = 15 # How quickly animations transition between each other (higher = faster)
var walk_val = 0             # Blend value for walk animation (0 = not walking, 1 = fully walking)
var run_val = 0              # Blend value for run animation (0 = not running, 1 = fully running)

# === CAMERA SETTINGS ===
@export var sens_horizontal = 0.5  # Mouse sensitivity for left/right looking
@export var sens_vertical = 0.5    # Mouse sensitivity for up/down looking

# Gets gravity value from project settings (this ensures it matches physics settings for RigidBody nodes)
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# === INITIALIZATION ===
# Called once when the node enters the scene tree
func _ready():
	# Captures the mouse cursor so it doesn't leave the game window
	# This is standard for first-person and third-person games
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# === INPUT HANDLING ===
# Called whenever there's an input event (mouse move, key press, etc.)
func _input(event):
	if is_dead:
		return
	# Check if the event is mouse movement
	if event is InputEventMouseMotion:
		# HORIZONTAL ROTATION (left/right looking)
		# rotate_y rotates the CharacterBody3D node around the Y axis (yaw)
		# deg_to_rad converts degrees to radians (Godot uses radians for rotation)
		# event.relative.x is how far the mouse moved horizontally
		# Negative because moving mouse right should rotate right (coordinate system)
		rotate_y(deg_to_rad(-event.relative.x * sens_horizontal))
		
		# Counter-rotate the visuals so the character model stays facing the right direction
		# Without this, the model would spin with the camera
		visuals.rotate_y(deg_to_rad(event.relative.x * sens_horizontal))
		
		# VERTICAL ROTATION (up/down looking)
		# rotate_x rotates the camera mount around the X axis (pitch)
		# This lets you look up and down without tilting the character
		camera_mount.rotate_x(deg_to_rad(-event.relative.y * sens_vertical))

# === PHYSICS AND MOVEMENT ===
# Called every physics frame (usually 60 times per second)
# Delta is the time elapsed since the last frame
func _physics_process(delta):
	# GRAVITY APPLICATION
	# If not on the floor, apply gravity to pull the character down
	# is_on_floor() is a CharacterBody3D method that checks ground collision
	if not is_on_floor():
		velocity.y -= gravity * delta  # velocity is built into CharacterBody3D
	
	# Update animation blending
	handle_animations(delta)
	
	if is_dead:
		return
	
	# JUMPING
	# is_action_just_pressed checks if key was pressed THIS frame (not held)
	# Only allow jumping when on the ground and not attacking
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_attacking:
		is_jumping = true
		
		curAnim = JUMP
		animation_tree.set("parameters/TimeScale/scale", 0.25)
		animation_tree["parameters/Jump/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE 

		var anim_player = $visuals/Untitled/AnimationPlayer
		var jump_length = anim_player.get_animation("jump/jump").length
		
		get_tree().create_timer(jump_length).timeout.connect(func():
			is_jumping = false
			curAnim = IDLE
		)
		await get_tree().create_timer(0.55).timeout
		
		velocity.y = JUMP_VELOCITY  # Apply upward velocity  
	
	# ATTACKING
	if Input.is_action_just_pressed("attack") and not is_attacking:
		is_attacking = true  # Prevent movement and multiple attacks
		curAnim = ATTACK
		
		# Fire the attack animation using the AnimationTree's OneShot node
		# ONE_SHOT_REQUEST_FIRE plays the animation once then returns to the blend tree
		animation_tree["parameters/Attack/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
		
		# Get the AnimationPlayer to check animation length
		var anim_player = $visuals/Untitled/AnimationPlayer
		var attack_length = anim_player.get_animation("attack/attack").length
		
		# Create a timer that fires when the attack animation finishes
		# This prevents the attack from being interrupted
		get_tree().create_timer(attack_length).timeout.connect(func():
			is_attacking = false  # Allow movement again
			curAnim = IDLE        # Return to idle state
		)
	
	# MOVEMENT INPUT
	# get_vector reads 4 directional inputs and combines them into a 2D vector
	# Returns values from -1 to 1 for each axis
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	
	# Transform input from camera space to world space
	# transform.basis is the character's rotation matrix
	# This ensures "forward" moves in the direction the character is facing
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# SPRINT DETECTION
	# Only sprint if sprint key is held AND player is moving
	var is_sprinting = Input.is_action_pressed("sprint") and direction != Vector3.ZERO
	# Choose speed based on sprint state
	var current_speed = SPRINT_SPEED if is_sprinting else SPEED
	
	# APPLY MOVEMENT
	if direction and not is_attacking:  # If there's input and not attacking
		# Make the character model face the movement direction
		# position + direction creates a point in front of the character
		visuals.look_at(position + direction)
		
		# Set velocity based on direction and speed
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		
		# Update animation state based on sprint
		if is_sprinting:
			if curAnim != RUN:
				curAnim = RUN
		else:
			if curAnim != WALK:
				curAnim = WALK
	else:
		# No input or attacking - return to idle and decelerate
		if not is_attacking and curAnim != IDLE:
			curAnim = IDLE
		
		# move_toward smoothly reduces velocity to 0
		# This creates smooth deceleration instead of instant stopping
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	
	# move_and_slide() is a CharacterBody3D method that:
	# 1. Moves the character based on velocity
	# 2. Handles collisions and sliding along surfaces
	# 3. Must be called every physics frame
	move_and_slide()

# === ANIMATION CALLBACKS ===
# Connected to the AnimationPlayer's animation_finished signal
# Called when any animation completes
func _on_animation_player_animation_finished(anim_name):
	if anim_name == "attack/attack":
		is_attacking = false  # Allow movement again after attack

# === ANIMATION BLENDING ===
# Smoothly transitions between animation states
func handle_animations(delta):
	# match is like a switch statement - checks curAnim against each case
	match curAnim:
		IDLE:
			# lerpf = linear interpolation (smooth transition between values)
			# Smoothly reduces walk_val and run_val to 0
			# blend_speed * delta makes it framerate-independent
			walk_val = lerpf(walk_val, 0, blend_speed * delta)
			run_val = lerpf(run_val, 0, blend_speed * delta)
		WALK:
			# Increase walk blend to 1, decrease run to 0
			walk_val = lerpf(walk_val, 1, blend_speed * delta)
			run_val = lerpf(run_val, 0, blend_speed * delta)
		RUN:
			# Decrease walk to 0, increase run blend to 1
			walk_val = lerpf(walk_val, 0, blend_speed * delta)
			run_val = lerpf(run_val, 1, blend_speed * delta)
		ATTACK:
			walk_val = lerpf(walk_val, 0, blend_speed * delta)
			run_val = lerpf(run_val, 0, blend_speed * delta)
		DIE:
			walk_val = lerpf(walk_val, 0, blend_speed * delta)
			run_val = lerpf(run_val, 0, blend_speed * delta)
		JUMP:
			walk_val = lerpf(walk_val, 0, blend_speed * delta)
			run_val = lerpf(run_val, 0, blend_speed * delta)
	
	# Apply the calculated blend values to the AnimationTree
	update_tree()

# Updates the AnimationTree parameters with current blend values
# The AnimationTree uses these to smoothly blend between idle/walk/run animations
func update_tree():
	# Set blend amounts for Walk and Run blend nodes in the AnimationTree
	# Values go from 0 (not active) to 1 (fully active)
	animation_tree["parameters/Walk/blend_amount"] = walk_val
	animation_tree["parameters/Run/blend_amount"] = run_val

# === DAMAGE SYSTEM ===
# Called when the player takes damage (called from external scripts like enemies)
# dir is a Vector3 indicating the direction of the knockback
func hit(dir):
	# Emit signal so other nodes (like UI) know the player was hit
	emit_signal("player_hit")
	
	# Apply knockback by adding to velocity
	# HIT_STAGGER controls how strong the knockback is
	velocity += dir * HIT_STAGGER
	health -= 20
	print("Hit! Player health: ", health)
	if health <= 0:
		is_dead = true
		curAnim = DIE
		animation_tree["parameters/Die/blend_amount"] = 1.0
		emit_signal("player_died")
