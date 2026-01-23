extends CharacterBody3D

@onready var animation_player = $RootNode/AnimationPlayer
@onready var nav_agent = $NavigationAgent3D
@onready var anim_tree = $AnimationTree

const SPEED = 4.0
const ATTACK_RANGE = 1

var player = null
var state_machine
var health = 30
var is_taking_damage = false
@export var player_path := "/root/world/map/NavigationRegion3D/Player"

func _ready():
	player = get_node(player_path)
	state_machine = anim_tree.get("parameters/playback")

func _process(delta):
	velocity = Vector3.ZERO
	
	if state_machine.get_current_node() == "head_hit_mixamo_com" and is_taking_damage:
		state_machine.travel("running_mixamo_com")
	
	if is_taking_damage:
		return
	
	match state_machine.get_current_node():
		"running_mixamo_com":
			nav_agent.set_target_position(player.global_transform.origin)
			var next_nav_point = nav_agent.get_next_path_position()
			velocity = (next_nav_point - global_transform.origin).normalized() * SPEED
			rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), delta * 10.0)
		"cpu_attack_mixamo_com":
			look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
	
	
	if not is_taking_damage:
		anim_tree.set("parameters/conditions/attack", _target_in_range())
		anim_tree.set("parameters/conditions/run", !_target_in_range())
	
	move_and_slide()

func _target_in_range():
	return global_position.distance_to(player.global_position) < ATTACK_RANGE

func _hit_finished():
	if global_position.distance_to(player.global_position) < ATTACK_RANGE + 1.0:
		var dir = global_position.direction_to(player.global_position)
		player.hit(dir)
	
func take_damage(amount: int):
	print("Damage: ", amount)
	health -= amount
	is_taking_damage = true
	
	state_machine.travel("head_hit_mixamo_com")
	
	var hit_anim_duration = 1.4
	await get_tree().create_timer(hit_anim_duration).timeout
	is_taking_damage = false
	if health <= 0:
		anim_tree.set("parameters/conditions/die", true)
		await get_tree().create_timer(8.0).timeout
		queue_free()



