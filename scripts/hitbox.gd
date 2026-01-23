class_name Hitbox
extends Area3D

@export var damage := 10

func _init() -> void:
	collision_layer = 2
	collision_mask = 0

func _ready() -> void:
	monitoring = false
	monitorable = false

func enable_hitbox() -> void:
	monitoring = true
	monitorable = true

func disable_hitbox() -> void:
	monitoring = false
	monitorable = false
