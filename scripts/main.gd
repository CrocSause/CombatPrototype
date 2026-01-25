extends Node3D

@onready var hit_rect = $Control/HitRect
@onready var spawns = $map/Spawns
@onready var navigation_region = $map/NavigationRegion3D

var enemy = load("res://scenes/cpu.tscn")
var instance

# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_player_player_hit():
	hit_rect.visible = true
	await get_tree().create_timer(0.2).timeout
	hit_rect.visible = false

func _get_random_child(parent_node):
	var random_id = randi() % parent_node.get_child_count()
	return parent_node.get_child(random_id)

func _on_enemy_spawn_timer_timeout():
	var spawn_point = _get_random_child(spawns).global_position
	instance = enemy.instantiate()
	
	# Add the enemy first, THEN set its global position
	navigation_region.add_child(instance)
	instance.global_position = spawn_point 
