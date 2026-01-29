extends Node3D

@onready var hit_rect = $UI/HitRect
@onready var spawns = $map/Spawns
@onready var navigation_region = $map/NavigationRegion3D
@onready var enemy_spawn_timer = $EnemySpawnTimer
@onready var death_screen = $UI/DeathScreen
@onready var health_bar = $UI/HealthBar
@onready var kill_count = $UI/KillCount

var enemy = load("res://scenes/cpu.tscn")
var instance
var enemy_death = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_player_player_hit():
	hit_rect.visible = true
	health_bar.value -= 20
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
	instance.enemy_died.connect(_on_enemy_died)

func _on_player_player_died():
	enemy_spawn_timer.stop()
	print("YOU DIED")
	await get_tree().create_timer(7.0).timeout
	death_screen.visible = true
	health_bar.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_button_pressed():
	get_tree().reload_current_scene()
	
func _on_enemy_died():
	enemy_death += 1
	kill_count.text = str(enemy_death)


