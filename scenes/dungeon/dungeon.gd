class_name Dungeon
extends Node2D


## Tile and chunk constants

enum TileTypes {
	STAIRS_UP, STAIRS_DOWN, GROUND, WALL, STONE, BOUNDARY, ENEMY, GEM,
}
const TILES : Dictionary[TileTypes, Vector2] = {
	# Terrain
	TileTypes.STAIRS_DOWN : Vector2(3, 6),
	TileTypes.STAIRS_UP : Vector2(2, 6),
	TileTypes.GROUND : Vector2(4, 0),
	TileTypes.WALL : Vector2(0, 13),
	TileTypes.STONE : Vector2(5, 2),
	# Interactable
	TileTypes.ENEMY : Vector2(21, 7),
	TileTypes.GEM : Vector2(32, 10),
	TileTypes.BOUNDARY : Vector2(10, 17),
}
const DUNGEON_SIZE := Vector2(60, 34)
const BOUNDARY_SIZE : = Vector2(20, 12)


## Procgen constants

const DUNGEON_NOISE = preload("res://scenes/dungeon/dungeon_noise.tres")
const BUILD_ITERATIONS := 5
const SMOOTH_ITERATIONS := 3
const WALL_PERCENT := 45.0
const GEM_PERCENT := 10.0
const SPAWN_ROOM_SIZE := 4.0


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

func pickup(tile: Vector2) -> void:
	interactable.set_cell(tile)

func attack(tile: Vector2) -> void:
	interactable.set_cell(tile)

func dig(tile: Vector2, chunk_index: Vector2, height: float) -> void:
	var noise := 0.5 + DUNGEON_NOISE.get_noise_3d(
		chunk_index.x * DUNGEON_SIZE.x + tile.x,
		chunk_index.y * DUNGEON_SIZE.y + tile.y, height) / 2.0
	if noise < GEM_PERCENT / 100:
		terrain.set_cell(tile)
		interactable.set_cell(tile, Globals.SOURCE_ID, TILES[TileTypes.GEM])
	else:
		terrain.set_cell(tile, Globals.SOURCE_ID, TILES[TileTypes.STONE])
#endregion


## Procedural generation

#region Procedural generation
func get_exit(chunk_index: Vector2, height: float) -> Vector2:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(Vector3(chunk_index.x, chunk_index.y, height))
	var exit_x := rng.randi() % int(DUNGEON_SIZE.x)
	var exit_y := rng.randi() % int(DUNGEON_SIZE.y)
	return Vector2(exit_x, exit_y)

func get_initial_cells(chunk_index: Vector2, height: float) -> Array[Array]:
	var cells : Array[Array] = []
	cells.resize(int(DUNGEON_SIZE.x))
	for x in range(DUNGEON_SIZE.x):
		cells[x].resize(int(DUNGEON_SIZE.y))
		for y in range(DUNGEON_SIZE.y):
			var noise := 0.5 + DUNGEON_NOISE.get_noise_3d(
				chunk_index.x * DUNGEON_SIZE.x + x,
				chunk_index.y * DUNGEON_SIZE.y + y, height) / 2.0
			cells[x][y] = TileTypes.WALL if noise < WALL_PERCENT / 100 else TileTypes.GROUND
	return cells

func get_offset(value: float, is_upper_left_offseted: bool) -> float:
	return floor(value) if is_upper_left_offseted else ceil(value)

func get_room_corner(tile: Vector2, offset: float,
		horizontal_offset: bool, vertical_offset: bool) -> Vector2:
	return Vector2(
		tile.x + get_offset(offset, horizontal_offset),
		tile.y + get_offset(offset, vertical_offset)
	)

func make_path(cells: Array[Array], chunk_index: Vector2, height: float) -> Array[Array]:
	var exit := get_exit(chunk_index, height)
	var entrance := get_exit(chunk_index, height - 1)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(Vector3(chunk_index.x, chunk_index.y, height - 1))
	# Get the exit and entrance room boundaries
	var exit_horizontal_offset := rng.randi() % 2 == 0
	var exit_vertical_offset := rng.randi() % 2 == 0
	var entrance_horizontal_offset := rng.randi() % 2 == 0
	var entrance_vertical_offset := rng.randi() % 2 == 0
	var exit_room_upper_left := get_room_corner(exit, -(SPAWN_ROOM_SIZE - 1) / 2,
		exit_horizontal_offset, exit_vertical_offset)
	var exit_room_lower_right := get_room_corner(exit, (SPAWN_ROOM_SIZE - 1) / 2,
		exit_horizontal_offset, exit_vertical_offset)
	var entrance_room_upper_left := get_room_corner(entrance, -(SPAWN_ROOM_SIZE - 1) / 2,
		entrance_horizontal_offset, entrance_vertical_offset)
	var entrance_room_lower_right := get_room_corner(entrance, (SPAWN_ROOM_SIZE - 1) / 2,
		entrance_horizontal_offset, entrance_vertical_offset)
	# Create the path between rooms
	var chance := rng.randi() % 2 == 0
	for i in range(SPAWN_ROOM_SIZE):
		for offset : Vector2 in [Vector2(i, i), Vector2(i, SPAWN_ROOM_SIZE - 1 - i)]:
			# Set path from diagonals to other room diagonals
			var start := exit_room_upper_left + offset
			var end := entrance_room_upper_left + offset
			var horizontal_start : float = min(start.x, end.x)
			var horizontal_end : float = max(start.x, end.x)
			var vertical_start : float = min(start.y, end.y)
			var vertical_end : float = max(start.y, end.y)
			# Choose randomly order of movement
			var step := (end - start).sign()
			var is_twisted := int((step.x + 1) / 2 + (step.y + 1) / 2) % 2 == 1
			var vertical := vertical_start if chance else vertical_end
			var horizontal := horizontal_end if (chance and not is_twisted) \
				or (not chance and is_twisted) else horizontal_start
			# Restict values to be inside dungeon
			horizontal_start = clamp(horizontal_start, 0, DUNGEON_SIZE.x - 1)
			horizontal_end = clamp(horizontal_end, 0, DUNGEON_SIZE.x - 1)
			vertical_start = clamp(vertical_start, 0, DUNGEON_SIZE.y - 1)
			vertical_end = clamp(vertical_end, 0, DUNGEON_SIZE.y - 1)
			# Move horizontal
			if step.x != 0 and Globals.is_in_between(vertical, 0, DUNGEON_SIZE.y - 1):
				for x in range(horizontal_start, horizontal_end + 1):
					cells[x][vertical] = TileTypes.STONE
			# Move vertical
			if step.y != 0 and Globals.is_in_between(horizontal, 0, DUNGEON_SIZE.x - 1):
				for y in range(vertical_start, vertical_end + 1):
					cells[horizontal][y] = TileTypes.STONE
	# Make sure the rooms are inside dungeon
	exit_room_upper_left = exit_room_upper_left.clamp(Vector2.ZERO, DUNGEON_SIZE - Vector2.ONE)
	exit_room_lower_right = exit_room_lower_right.clamp(Vector2.ZERO, DUNGEON_SIZE - Vector2.ONE)
	entrance_room_upper_left = entrance_room_upper_left.clamp(Vector2.ZERO, DUNGEON_SIZE - Vector2.ONE)
	entrance_room_lower_right = entrance_room_lower_right.clamp(Vector2.ZERO, DUNGEON_SIZE - Vector2.ONE)
	# Fill the rooms with ground
	for x in range(exit_room_upper_left.x, exit_room_lower_right.x + 1):
		for y in range(exit_room_upper_left.y, exit_room_lower_right.y + 1):
			cells[x][y] = TileTypes.STONE
	for x in range(entrance_room_upper_left.x, entrance_room_lower_right.x + 1):
		for y in range(entrance_room_upper_left.y, entrance_room_lower_right.y + 1):
			cells[x][y] = TileTypes.STONE
	cells[entrance.x][entrance.y] = TileTypes.STAIRS_DOWN
	cells[exit.x][exit.y] = TileTypes.STAIRS_UP
	return cells

func get_neighboars(cells: Array[Array], x: int, y: int, distance: int) -> int:
	var neighbors := 0
	for i in range(-distance, distance + 1):
		for j in range(-distance, distance + 1):
			var cell := Vector2(x + i, y + j)
			if not Globals.is_in_bounds(cell, Vector2.ZERO, DUNGEON_SIZE - Vector2.ONE):
				neighbors += 1
				continue
			if cells[x + i][y + j] == TileTypes.WALL:
				neighbors += 1
	return neighbors

func cellular_automata(cells: Array[Array], rule: Callable) -> Array[Array]:
	var new_cells : Array[Array] = []
	new_cells.resize(int(DUNGEON_SIZE.x))
	for x in range(DUNGEON_SIZE.x):
		new_cells[x].resize(int(DUNGEON_SIZE.y))
		for y in range(DUNGEON_SIZE.y):
			new_cells[x][y] = TileTypes.WALL \
				if rule.call(cells, x, y) else TileTypes.GROUND
	return new_cells

func setup(chunk_index: Vector2, height: float) -> void:
	terrain.clear()
	interactable.clear()
	# Get entrance and exit locations
	var exit := get_exit(chunk_index, height)
	var entrance := get_exit(chunk_index, height - 1)
	# Set initial state of cells with random values
	var cells : Array[Array] = get_initial_cells(chunk_index, height)
	# Evolve cave stucture
	for _i in range(BUILD_ITERATIONS):
		var rule := (func(state: Array[Array], x: int, y: int):
			return get_neighboars(state, x, y, 1) >= 5 \
				or get_neighboars(state, x, y, 2) <= 2)
		cells = cellular_automata(cells, rule)
	# Path blanking
	make_path(cells, chunk_index, height)
	# Smoothen and eliminate holes
	for _i in range(SMOOTH_ITERATIONS):
		var rule := func(state: Array[Array], x: int, y: int):
			return get_neighboars(state, x, y, 1) >= 5
		cells = cellular_automata(cells, rule)
	# Set cells with result of procgen
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(Vector3(chunk_index.x, chunk_index.y, height))
	for x in range(DUNGEON_SIZE.x):
		for y in range(DUNGEON_SIZE.y):
			var tile := Vector2(x, y)
			# Add interactables
			if cells[x][y] == TileTypes.GROUND:
				var chance := rng.randi() % 200
				if chance < 1:
					interactable.set_cell(tile, Globals.SOURCE_ID, TILES[TileTypes.ENEMY])
				elif chance < 2:
					interactable.set_cell(tile, Globals.SOURCE_ID, TILES[TileTypes.GEM])
			terrain.set_cell(tile, Globals.SOURCE_ID, TILES[cells[x][y]])
	# Add the exit and entrance
	terrain.set_cell(entrance, Globals.SOURCE_ID, TILES[TileTypes.STAIRS_DOWN])
	terrain.set_cell(exit, Globals.SOURCE_ID, TILES[TileTypes.STAIRS_UP])
	# Set boundary walls on the margins
	for x in range(BOUNDARY_SIZE.x):
		for y in range(BOUNDARY_SIZE.y):
			var tile := Vector2(x, y)
			terrain.set_cell(tile - BOUNDARY_SIZE, Globals.SOURCE_ID,
				TILES[TileTypes.BOUNDARY])
			terrain.set_cell(tile + Vector2(-BOUNDARY_SIZE.x, DUNGEON_SIZE.y),
				Globals.SOURCE_ID, TILES[TileTypes.BOUNDARY])
			terrain.set_cell(tile + Vector2(DUNGEON_SIZE.x, -BOUNDARY_SIZE.y),
				Globals.SOURCE_ID, TILES[TileTypes.BOUNDARY])
			terrain.set_cell(tile + DUNGEON_SIZE, Globals.SOURCE_ID,
				TILES[TileTypes.BOUNDARY])
	for x in range(BOUNDARY_SIZE.x):
		for y in range(DUNGEON_SIZE.y):
			var tile := Vector2(x, y)
			terrain.set_cell(tile - Vector2(BOUNDARY_SIZE.x, 0),
				Globals.SOURCE_ID, TILES[TileTypes.BOUNDARY])
			terrain.set_cell(tile + Vector2(DUNGEON_SIZE.x, 0),
				Globals.SOURCE_ID, TILES[TileTypes.BOUNDARY])
	for x in range(DUNGEON_SIZE.x):
		for y in range(BOUNDARY_SIZE.y):
			var tile := Vector2(x, y)
			terrain.set_cell(tile - Vector2(0, BOUNDARY_SIZE.y),
				Globals.SOURCE_ID, TILES[TileTypes.BOUNDARY])
			terrain.set_cell(tile + Vector2(0, DUNGEON_SIZE.y),
				Globals.SOURCE_ID, TILES[TileTypes.BOUNDARY])
#endregion
