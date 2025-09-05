class_name Settlement
extends Node2D


## Tile and chunk constants

enum TileTypes {
	DIRT, GROUND, GRASS, WALL, FLOOR
}
# Tiles for terrain
const TILES : Dictionary[TileTypes, Vector2] = {
	TileTypes.DIRT : Vector2(-1, -1),
	TileTypes.GROUND : Vector2(1, 0),
	TileTypes.GRASS : Vector2(5, 0),
	TileTypes.WALL : Vector2(6, 13),
	TileTypes.FLOOR : Vector2(16, 0),
}
# Tiles for NPCs
const NPC_LIST : Array[Vector2] = [
	Vector2(25, 1), Vector2(26, 1), Vector2(27, 1), Vector2(28, 1),
	Vector2(29, 1), Vector2(24, 2), Vector2(31, 2), Vector2(28, 3),
	Vector2(29, 3), Vector2(30, 3), Vector2(31, 3), Vector2(24, 4),
	Vector2(25, 4), Vector2(26, 4), Vector2(27, 4), Vector2(28, 4),
	Vector2(30, 4), Vector2(31, 4), Vector2(25, 9), Vector2(26, 9),
	Vector2(30, 9)
]
const SETTLEMENT_SIZE := Vector2(64, 32)
const BOUNDARY_SIZE : = Vector2(16, 8)


## Procgen constants

const SETTLEMENT_NOISE = preload("res://scenes/settlement/settlement_noise.tres")
const HOUSES := 8
const MIN_ITERATIONS := 4
const MAX_ITERATIONS := 5

## Scene nodes

@onready var terrain: TileMapLayer = $Terrain
@onready var interactable: TileMapLayer = $Interactable


## Tile info and modification

#region Tile info and modification
func get_tile_data(tile: Vector2, property: StringName) -> bool:
	var terrain_data := terrain.get_cell_tile_data(tile)
	var interactable_data := interactable.get_cell_tile_data(tile)
	var values := []
	if terrain_data != null and terrain_data.has_custom_data(property):
		values.append(terrain_data.get_custom_data(property))
	if interactable_data != null and interactable_data.has_custom_data(property):
		values.append(interactable_data.get_custom_data(property))
	return values.any(func(value: bool): return value)

func get_start_position(direction: Vector2) -> Vector2:
	var tile : Vector2
	var direction_sign :=  direction.sign()
	match direction_sign.x:
		1.0:
			tile.x = 0
		-1.0:
			tile.x = SETTLEMENT_SIZE.x - 1
		_:
			tile.x = floor(SETTLEMENT_SIZE.x / 2)
	match direction_sign.y:
		1.0:
			tile.y = 0
		-1.0:
			tile.y = SETTLEMENT_SIZE.y - 1
		_:
			tile.y = floor(SETTLEMENT_SIZE.y / 2)
	return tile

func has_exited(location: Vector2) -> bool:
	return not Globals.is_in_bounds(location, Vector2.ZERO, SETTLEMENT_SIZE - Vector2.ONE)
#endregion


## Procedural generation

#region Procedural generation
func get_initial_cells(chunk_index: Vector2) -> Array[Array]:
	var cells : Array[Array] = []
	cells.resize(int(SETTLEMENT_SIZE.x))
	for x in range(SETTLEMENT_SIZE.x):
		cells[x].resize(int(SETTLEMENT_SIZE.y))
		for y in range(SETTLEMENT_SIZE.y):
			var tile := Vector2(x, y)
			var noise := SETTLEMENT_NOISE.get_noise_2dv(chunk_index * SETTLEMENT_SIZE + tile)
			if noise > 0.25:
				cells[x][y] = TileTypes.GRASS
			elif noise > -0.25:
				cells[x][y] = TileTypes.GROUND
			else:
				cells[x][y] = TileTypes.DIRT
	return cells

func space_occupied(house_position : Vector2, house_size : Vector2,
		house_positions : Array[Vector2], house_sizes : Array[Vector2]) -> bool:
	for i in range(house_positions.size()):
		var current_house_position := house_positions[i]
		var current_house_size := house_sizes[i]
		if house_position.x <= current_house_position.x + current_house_size.x - 1 \
				and house_position.x + house_size.x - 1 >= current_house_position.x \
				and house_position.y <= current_house_position.y + current_house_size.y - 1 \
				and house_position.y + house_size.y - 1 >= current_house_position.y:
			return true
	return false

func add_house(rng : RandomNumberGenerator,
		house_positions : Array[Vector2], house_sizes : Array[Vector2]):
	# Get house partition
	var house_position := Vector2(0, 0)
	var house_size := SETTLEMENT_SIZE
	var iterations : int
	if rng.randi() % 100 < 75:
		iterations = MAX_ITERATIONS
	else:
		iterations = MIN_ITERATIONS
	for _j in range(iterations):
		var chance : int
		# Make sure house are not too small
		if house_size.x / 2. < 6.0:
			chance = 2 * (rng.randi() % 2)
		elif house_size.y / 2. < 6.0:
			chance = 1 + 2 * (rng.randi() % 2)
		else:
			chance = rng.randi() % 4
		# Offset and shrink the house
		match chance:
			0:
				house_position = Vector2(
					house_position.x, house_position.y)
				house_size.y /= 2
			1:
				house_position = Vector2(
					house_position.x + house_size.x / 2, house_position.y)
				house_size.x /= 2
			2:
				house_position = Vector2(
					house_position.x, house_position.y + house_size.y / 2)
				house_size.y /= 2
			3:
				house_position = Vector2(
					house_position.x, house_position.y)
				house_size.x /= 2
	if not space_occupied(house_position, house_size, house_positions, house_sizes):
		house_positions.append(house_position)
		house_sizes.append(house_size)

func get_door(rng : RandomNumberGenerator,
		house_position : Vector2, house_size : Vector2) -> Vector2:
	var door_x : float
	var door_y : float
	match rng.randi() % 4:
		0:
			door_x = rng.randi_range(
				int(house_position.x) + 3,
				int(house_position.x + house_size.x) - 4)
			door_y = house_position.y + 1
		1:
			door_x = house_position.x + 1
			door_y = rng.randi_range(
				int(house_position.y) + 3, 
				int(house_position.y + house_size.y) - 4)
		3:
			door_x = rng.randi_range(
				int(house_position.x + 3),
				int(house_position.x + house_size.x) - 4)
			door_y = house_position.y + house_size.y - 2
		2:
			door_x = house_position.x + house_size.x - 2
			door_y = rng.randi_range(
				int(house_position.y) + 3,
				int(house_position.y + house_size.y) - 4)
	var door := Vector2(door_x, door_y)
	return door

func place_house(cells : Array[Array], door: Vector2,
		house_position : Vector2, house_size : Vector2) -> void:
	# Add walls
	for x in range(house_position.x + 1, house_position.x + house_size.x - 1):
		cells[x][house_position.y + 1] = TileTypes.WALL
		cells[x][house_position.y + house_size.y - 2] = TileTypes.WALL
	for y in range(house_position.y + 1, house_position.y + house_size.y - 1):
		cells[house_position.x + 1][y] = TileTypes.WALL
		cells[house_position.x + house_size.x - 2][y] = TileTypes.WALL
	# Add floor
	for x in range(house_position.x + 2, house_position.x + house_size.x - 2):
		for y in range(house_position.y + 2, house_position.y + house_size.y - 2):
			cells[x][y] = TileTypes.FLOOR
	# Add door
	cells[door.x][door.y] = TileTypes.FLOOR

func setup(chunk_index: Vector2) -> void:
	interactable.clear()
	var cells : Array[Array] = get_initial_cells(chunk_index)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(chunk_index)
	var house_positions : Array[Vector2] = []
	var house_sizes : Array[Vector2] = []
	# Create houses
	for _i in range(HOUSES):
		add_house(rng, house_positions, house_sizes)
	# Prepare NPCs
	seed(hash(chunk_index))
	var settlement_npcs : Array[Vector2] = NPC_LIST.duplicate()
	settlement_npcs.shuffle()
	# Place NPCs
	for i in range(house_positions.size()):
		# Get door position
		var door = get_door(rng, house_positions[i], house_sizes[i])
		# Place the house in the settlement
		place_house(cells, door, house_positions[i], house_sizes[i])
		# Check if house is used by npc
		var chance := rng.randi() % 100
		if chance < 55 + 5 * (HOUSES - house_positions.size()):
			continue
		# Place npc in the house
		var npc_tile := settlement_npcs[i]
		var npc_x := rng.randi_range(int(house_positions[i].x) + 3, int(house_positions[i].x + house_sizes[i].x) - 4)
		var npc_y := rng.randi_range(int(house_positions[i].y) + 3, int(house_positions[i].y + house_sizes[i].y) - 4)
		interactable.set_cell(Vector2(npc_x, npc_y), Globals.SOURCE_ID, npc_tile)
	for x in range(SETTLEMENT_SIZE.x):
		for y in range(SETTLEMENT_SIZE.y):
			var tile := Vector2(x, y)
			terrain.set_cell(tile, Globals.SOURCE_ID, TILES[cells[x][y]])
#endregion
