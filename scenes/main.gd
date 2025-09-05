class_name Main
extends Node2D


## Tile constants

enum TileProperties {
	BLOCKS_MOVEMENT, PICKABLE, ATTACKABLE, DIGABLE, TALKABLE,
	CAVE_ENTRANCE, CAVE_EXIT, SETTLEMENT_ENTRANCE,
}
const PROPERTIES : Dictionary[TileProperties, StringName] = {
	TileProperties.BLOCKS_MOVEMENT : "blocks_movement",
	TileProperties.PICKABLE : "pickable",
	TileProperties.ATTACKABLE : "attackable",
	TileProperties.DIGABLE : "digable",
	TileProperties.CAVE_ENTRANCE : "cave_entrance",
	TileProperties.CAVE_EXIT : "cave_exit",
	TileProperties.SETTLEMENT_ENTRANCE: "settlement_entrance",
	TileProperties.TALKABLE : "talkable",
}


## Zone

enum Zone {
	OVERWORLD, DUNGEON, SETTLEMENT
}
var current_zone := Zone.OVERWORLD


### Scene nodes

@onready var overworld: Overworld = $Overworld
@onready var dungeon: Dungeon = $Dungeon
@onready var settlement: Settlement = $Settlement
@onready var player: Player = $Player


## Base gameloop

func _ready() -> void:
	player.player_moved.connect(_on_player_player_moved)
	initialize_world()

func initialize_world():
	match current_zone:
		Zone.OVERWORLD:
			enter_overworld()
		Zone.DUNGEON:
			enter_dungeon()
		Zone.SETTLEMENT:
			enter_settlement()

func has_property(tile: Vector2, property: TileProperties) -> bool:
	match current_zone:
		Zone.OVERWORLD:
			return overworld.get_tile_data(tile, PROPERTIES[property])
		Zone.DUNGEON:
			return dungeon.get_tile_data(tile, PROPERTIES[property])
		Zone.SETTLEMENT:
			return settlement.get_tile_data(tile, PROPERTIES[property])
	return false

func _on_player_player_moved(direction: Vector2) -> void:
	match current_zone:
		Zone.OVERWORLD:
			move_in_overworld(direction)
		Zone.DUNGEON:
			move_in_dungeon(direction)
		Zone.SETTLEMENT:
			move_in_settlement(direction)


## Overworld

#region Overworld
func enter_overworld():
	current_zone = Zone.OVERWORLD
	overworld.update_multithreaded(player.overworld_tile)
	player.overworld_tile = player.overworld_tile
	overworld.show()

func move_in_overworld(direction: Vector2):
	# Get data about the destination tile
	var next_position := player.overworld_tile + direction
	# Check if the tile blocks movement
	if has_property(next_position, TileProperties.BLOCKS_MOVEMENT):
		player.wait_turn()
		return
	# Check if the tile is interactable
	if has_property(next_position, TileProperties.PICKABLE):
		overworld.pickup(next_position)
	if has_property(next_position, TileProperties.ATTACKABLE):
		overworld.attack(next_position)
	# Perform move
	player.overworld_tile = next_position
	# Check for entrances in different zones
	if has_property(next_position, TileProperties.CAVE_ENTRANCE):
		exit_overworld()
		enter_dungeon()
		return
	if has_property(next_position, TileProperties.SETTLEMENT_ENTRANCE):
		exit_overworld()
		enter_settlement(direction)
		return
	# Update overworld
	overworld.update_multithreaded(player.overworld_tile)

func exit_overworld():
	overworld.hide()
#endregion


## Dungeon

#region Dungeon
func enter_dungeon():
	current_zone = Zone.DUNGEON
	player.height -= 1
	dungeon.setup(player.overworld_tile, player.height)
	player.dungeon_tile = dungeon.get_exit(player.overworld_tile, player.height)
	dungeon.show()

func move_in_dungeon(direction: Vector2):
	var next_position := player.dungeon_tile + direction
	# Check if the tile blocks movement
	if has_property(next_position, TileProperties.BLOCKS_MOVEMENT):
		if has_property(next_position, TileProperties.DIGABLE):
			dungeon.dig(next_position, player.overworld_tile, player.height)
		player.wait_turn()
		return
	# Check if the tile is interactable
	if has_property(next_position, TileProperties.PICKABLE):
		dungeon.pickup(next_position)
	if has_property(next_position, TileProperties.ATTACKABLE):
		dungeon.attack(next_position)
	# Perform move
	player.dungeon_tile = next_position
	# Check for entrances in different zones
	if has_property(next_position, TileProperties.CAVE_EXIT):
		player.height += 1
		if player.height == 0:
			exit_dungeon()
			enter_overworld()
			return
		dungeon.setup(player.overworld_tile, player.height)
		player.dungeon_tile = dungeon.get_exit(player.overworld_tile, player.height - 1)
		return
	if has_property(next_position, TileProperties.CAVE_ENTRANCE):
		player.height -= 1
		dungeon.setup(player.overworld_tile, player.height)
		player.dungeon_tile = dungeon.get_exit(player.overworld_tile, player.height)
		return

func exit_dungeon():
	dungeon.hide()
#endregion


## Settlement

#region Settlement
func enter_settlement(direction := Vector2(0, 0)):
	current_zone = Zone.SETTLEMENT
	settlement.setup(player.overworld_tile)
	player.settlement_tile = settlement.get_start_position(direction)
	settlement.show()

func move_in_settlement(direction: Vector2):
	var next_position := player.settlement_tile + direction
	if settlement.has_exited(next_position):
		exit_settlement()
		enter_overworld()
		return
	if has_property(next_position, TileProperties.BLOCKS_MOVEMENT):
		player.wait_turn()
		return
	if has_property(next_position, TileProperties.TALKABLE):
		player.wait_turn()
		return
	player.settlement_tile = next_position

func exit_settlement():
	settlement.hide()
#endregion
