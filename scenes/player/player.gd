class_name Player
extends Node2D


## Signals

signal player_moved(direction: Vector2)


## Movement variables

var can_move := true
var overworld_tile := position:
	set(new_value):
		wait_turn()
		overworld_tile = new_value
		position = new_value * Globals.TILE_SIZE
var dungeon_tile := position:
	set(new_value):
		wait_turn()
		dungeon_tile = new_value
		position = new_value * Globals.TILE_SIZE
var height := 0
var settlement_tile := position:
	set(new_value):
		wait_turn()
		settlement_tile = new_value
		position = new_value * Globals.TILE_SIZE


## Scene nodes

@onready var turn_cooldown := $TurnCooldown


## Movement implementation

func get_movement_direction() -> Vector2:
	var direction := Vector2(0, 0)
	if Input.is_action_pressed("move_up"):
		direction.y -= 1
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	return direction

func wait_turn() -> void:
	turn_cooldown.start()

func _ready() -> void:
	turn_cooldown.timeout.connect(func(): can_move = true)

func _process(_delta: float) -> void:
	if can_move:
		var direction := get_movement_direction()
		if direction.x != 0 or direction.y != 0:
			can_move = false
			player_moved.emit(direction)
