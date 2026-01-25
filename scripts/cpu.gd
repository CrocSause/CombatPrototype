# This script controls an enemy AI character
# It extends CharacterBody3D for physics-based movement and collision
extends CharacterBody3D

# === NODE REFERENCES ===
# Gets the AnimationPlayer node that contains all the enemy's animations
@onready var animation_player = $RootNode/AnimationPlayer

# NavigationAgent3D is Godot's pathfinding node - it calculates routes to the player
# It works with NavigationRegion3D to find paths around obstacles
@onready var nav_agent = $NavigationAgent3D

# AnimationTree manages state transitions between animations (running, attacking, hit, death)
@onready var anim_tree = $AnimationTree

# === CONSTANTS ===
const SPEED = 3.5          # How fast the enemy moves toward the player
const ATTACK_RANGE = 1     # Distance at which enemy can attack (in meters/units)

# === STATE VARIABLES ===
var player = null          # Reference to the player node (target to chase and attack)
var state_machine          # Reference to the AnimationTree's StateMachinePlayback
var health = 30            # Enemy's current health points
var is_taking_damage = false  # Prevents enemy from acting while playing hit animation

# === CONFIGURATION ===
# @export makes this editable in the inspector
# This is the node path to find the player in the scene tree
@export var player_path := "/root/world/map/NavigationRegion3D/Player"

# === INITIALIZATION ===
# Called once when the node enters the scene tree
func _ready():
	# Get the player node using the specified path
	# This creates a reference so the enemy knows what to chase
	player = get_node(player_path)
	
	# Get the StateMachinePlayback from the AnimationTree
	# This allows us to control which animation state is active and transition between states
	state_machine = anim_tree.get("parameters/playback")
	
	# Debug
	#print("=== ENEMY SPAWNED ===")
	#print("Spawn position: ", global_position)
	#print("Player position: ", player.global_position)
	
	# Wait for Navigation to be ready
	await get_tree().physics_frame
	await get_tree().physics_frame

# === MAIN LOOP ===
# Called every frame (typically 60 times per second)
# Delta is the time elapsed since last frame
func _physics_process(delta):
	if player.is_dead:
		return
	# Reset velocity to zero at the start of each frame
	# This prevents velocity from accumulating over time
	velocity = Vector3.ZERO
	
	# DAMAGE STATE RECOVERY
	# If currently playing the hit animation and taking damage
	if state_machine.get_current_node() == "head_hit_mixamo_com" and is_taking_damage:
		# Transition back to running state after hit animation
		# This ensures the enemy doesn't get stuck in the hit state
		state_machine.travel("running_mixamo_com")
	
	# If taking damage, skip all other logic (enemy is stunned during hit animation)
	if is_taking_damage:
		return
	
	# STATE-BASED BEHAVIOR
	# Check which animation state is currently active and act accordingly
	match state_machine.get_current_node():
		"running_mixamo_com":  # CHASE STATE
			# Tell the NavigationAgent where to go (player's position)
			# global_transform.origin is the player's world position
			nav_agent.set_target_position(player.global_transform.origin)
			
			# Get the next point along the calculated path
			# NavigationAgent calculates a path around obstacles
			var next_nav_point = nav_agent.get_next_path_position()
			
			# Debug: Print navigation data
			#print("--- Navigation Frame ---")
			#print("Current position: ", global_transform.origin)
			#print("Target (player): ", player.global_transform.origin)
			#print("Next nav point: ", next_nav_point)
			
			# Calculate velocity toward the next waypoint
			# (next_nav_point - global_transform.origin) creates a vector pointing to the waypoint
			# .normalized() makes it length 1, then multiply by SPEED
			velocity = (next_nav_point - global_transform.origin).normalized() * SPEED
			
			# Debug: Print calculated velocity
			#print("Calculated velocity: ", velocity)
			#print("Velocity magnitude: ", velocity.length())
			
			# Check for crazy values
			#if velocity.y > 1.0 or velocity.y < -1.0:
				#print("WARNING: ABNORMAL Y VELOCITY DETECTED!")
				#print("Direction vector: ", (next_nav_point - global_transform.origin))
			
			# Smoothly rotate enemy to face movement direction
			# atan2(-velocity.x, -velocity.z) calculates the angle from velocity
			# lerp_angle smoothly interpolates between current and target rotation
			# delta * 10.0 controls rotation speed (higher = faster turn)
			rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), delta * 10.0)
			
		"cpu_attack_mixamo_com":  # ATTACK STATE
			# Make enemy face the player during attack animation
			# look_at rotates the node to face a target position
			# We use player's X and Z, but keep enemy's Y to prevent tilting
			# Vector3.UP is the up direction for the rotation
			look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
	
	# ANIMATION STATE CONDITIONS
	# Only update animation conditions if not taking damage
	if not is_taking_damage:
		# Set the "attack" condition based on whether player is in range
		# The AnimationTree uses these conditions to transition between states
		anim_tree.set("parameters/conditions/attack", _target_in_range())
		
		# Set the "run" condition to the opposite of attack
		# If player is NOT in range, enemy should run toward them
		anim_tree.set("parameters/conditions/run", !_target_in_range())
		
	# Debug: Print final position after move
	#var pos_before = global_position
	move_and_slide()
	#var pos_after = global_position
	
	#if abs(pos_after.y - pos_before.y) > 0.5:
		#print("LARGE Y MOVEMENT: ", pos_before, " -> ", pos_after)


# === HELPER FUNCTIONS ===
# Checks if the player is within attack range
# Returns true if player is close enough to attack, false otherwise
func _target_in_range():
	# distance_to calculates the straight-line distance between two points
	# Compare it to ATTACK_RANGE to determine if player is in range
	return global_position.distance_to(player.global_position) < ATTACK_RANGE

# Called by an animation event when the attack animation hits its "damage frame"
# This is typically set up in the AnimationPlayer as a function call track
func _hit_finished():
	# Check if player is still in range (they might have moved during attack animation)
	# Add 1.0 units of leeway to make attacks feel more forgiving
	if global_position.distance_to(player.global_position) < ATTACK_RANGE + 1.0:
		# Calculate direction vector from enemy to player
		# This determines which way the knockback should push the player
		var dir = global_position.direction_to(player.global_position)
		
		# Call the player's hit() function, passing the knockback direction
		# This damages the player and applies knockback
		player.hit(dir)

# === DAMAGE SYSTEM ===
# Called by external scripts (like the player's weapon) when enemy is hit
# amount: how much damage to deal
func take_damage(amount: int):
	# Immediately transition to the hit/stagger animation
	# This interrupts whatever the enemy was doing
	state_machine.travel("head_hit_mixamo_com")
	
	# Debug print to see damage in console
	print("Damage: ", amount)
	
	# Reduce health by the damage amount
	health -= amount
	
	# Set flag to prevent enemy from moving/attacking during hit reaction
	is_taking_damage = true
	
	# ASYNC TIMING FOR HIT RECOVERY
	# Wait for the hit animation to finish before allowing enemy to act again
	var hit_anim_duration = 1.4  # Length of the hit animation in seconds
	# await pauses execution here until the timer finishes
	# This is an async function that doesn't block other code
	await get_tree().create_timer(hit_anim_duration).timeout
	
	# Hit animation is done, enemy can act normally again
	is_taking_damage = false
	
	# DEATH CHECK
	if health <= 0:
		# Set the death condition to trigger death animation
		# The AnimationTree will transition to the death state
		anim_tree.set("parameters/conditions/die", true)
		
		# Wait 8 seconds for death animation to play
		await get_tree().create_timer(8.0).timeout
		
		# Remove this enemy from the scene
		# queue_free() safely deletes the node at the end of the frame
		queue_free()
