class_name Chunk
extends Node2D


## Tile and chunk constants

enum TileTypes {
	FIELD, FOREST, ROAD, DUNGEON, SETTLEMENT, APPLE, ENEMY,
}
const TILES : Dictionary[TileTypes, Vector2] = {
	# Terrain
	TileTypes.FIELD : Vector2(-1, -1),
	TileTypes.FOREST : Vector2(3, 1),
	TileTypes.ROAD : Vector2(2, 0),
	TileTypes.DUNGEON : Vector2(3, 6),
	TileTypes.SETTLEMENT : Vector2(0, 19),
	# Interactable
	TileTypes.APPLE : Vector2(33, 18),
	TileTypes.ENEMY : Vector2(21, 7),
}
const CHUNK_SIZE := Vector2(20, 20)


## Procgen constants

const OVERWORLD_NOISE : Noise = preload("res://scenes/overworld/overworld_noise.tres")
const MIN_DUNGEONS := 1
const MAX_DUNGEONS := 1


## Scene nodes

@onready var terrain: TileMapLayer = $Terrain
@onready var interactable: TileMapLayer = $Interactable


## Geometry

#region Geometry
func get_middle_line_parameters(dungeon1: Vector2, dungeon2: Vector2) -> Vector3:
	# Find the equation of the line passing between dungeonss
	# ax = by + c = 0
	var a : float = -2.0 * (dungeon1.x - dungeon2.x) # constant of x
	var b : float = -2.0 * (dungeon1.y - dungeon2.y) # constant of y
	var c : float = dungeon1.y ** 2 - dungeon2.y ** 2 \
		+ dungeon1.x ** 2 - dungeon2.x ** 2 # free constant
	return Vector3(a, b, c)

func line_passes_tile(tile: Vector2, params: Vector3) -> bool:
	# Calculate intersections or give a default value
	# for the case of a horizontal or vertical line
	var upper_intersection := -(params.z + tile.y * params.y) / params.x \
			if params.x != 0 else tile.x - 1.0
	var leftmost_intersection := -(params.z + tile.x * params.x) / params.y \
			if params.y != 0 else tile.y - 1.0
	var lower_intersection := -(params.z + (tile.y + 1.0) * params.y) / params.x \
			if params.x != 0 else tile.x - 1.0
	var rightmost_intersection := -(params.z + (tile.x + 1.0) * params.x) / params.y \
			if params.y != 0 else tile.y - 1.0
	# Filter out intersections with tile rectangle
	var x_values := [upper_intersection, lower_intersection].filter(
		Globals.is_in_between.bind(tile.x, 1.0 + tile.x))
	var y_values := [leftmost_intersection, rightmost_intersection].filter(
		Globals.is_in_between.bind(tile.y, 1.0 + tile.y))
	return x_values.size() + y_values.size() != 0

func lines_intersect(tile: Vector2, params1: Vector3, params2: Vector3) -> bool:
	var x := (params1.y * params2.z - params1.z * params2.y) \
			/ (params1.x * params2.y - params1.y * params2.x) \
			if (params1.x * params2.y - params1.y * params2.x) != 0 \
			else tile.x - 1.0
	var y := (params1.y * params2.z - params1.z * params2.y) \
			/ (params1.x * params2.y - params1.y * params2.x) \
			if (params1.x * params2.y - params1.y * params2.x) != 0 \
			else tile.x - 1.0
	return Globals.is_in_bounds(Vector2(x, y), tile, tile + Vector2(1, 1))
#endregion


## Procedural generation

#region Procedural generation
func generate_dungeons(chunk_index: Vector2) -> Array[Vector2]:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(chunk_index)
	var dungeon_number := MIN_DUNGEONS \
		+ (rng.randi() % (MAX_DUNGEONS - MIN_DUNGEONS + 1))
	var dungeons : Array[Vector2] = []
	for _i in range(dungeon_number):
		var x := rng.randi() % int(CHUNK_SIZE.x)
		var y := rng.randi() % int(CHUNK_SIZE.y)
		var dungeon := Vector2(x, y)
		if dungeon in dungeons:
			continue
		dungeons.append(dungeon)
	return dungeons

func get_equidistant_dungeons(tile: Vector2, dungeons : Array[Vector2]) -> int:
	var closest_dungeons := get_closest_dungeons(tile, dungeons)
	# Check if there at least 2 close dungeons
	if closest_dungeons.size() < 2:
		return 1
	var closest_dungeon := closest_dungeons[0]
	var is_road := false
	var is_settlement := false
	var all_params : Array[Vector3] = []
	for i in range(1, closest_dungeons.size()):
		if is_settlement:
			break
		var dungeon := closest_dungeons[i]
		# Find the intersection of the line
		# passing between dungeons and the tile rectangle edges
		var current_params := get_middle_line_parameters(closest_dungeon, dungeon)
		if line_passes_tile(tile, current_params):
			is_road = true
		# Check the intersection of the lines
		for params in all_params:
			if lines_intersect(tile, current_params, params):
				is_settlement = true
		all_params.append(current_params)
	var equidistant_dungeons = 1
	if is_road:
		equidistant_dungeons += 1
		if is_settlement:
			equidistant_dungeons += 1
	return equidistant_dungeons

func get_closest_dungeons(tile: Vector2, dungeons: Array[Vector2]) -> Array[Vector2]:
	var closest_dungeons : Array[Vector2] = dungeons
	closest_dungeons.sort_custom(func(a, b):
		var a_dist := Globals.get_euclidean_distance(tile, a)
		var b_dist := Globals.get_euclidean_distance(tile, b)
		return a_dist < b_dist)
	return closest_dungeons

func setup(chunk_index: Vector2) -> void:
	var rng = RandomNumberGenerator.new()
	terrain.clear()
	interactable.clear()
	# Generate dungeons
	var dungeons : Array[Vector2] = []
	for i in [-1, 0, 1]:
		for j in [-1, 0, 1]:
			var offset := Vector2(i, j)
			for dungeon in generate_dungeons(chunk_index + offset):
				if i == 0 and j == 0:
					terrain.set_cell(dungeon, Globals.SOURCE_ID, TILES[TileTypes.DUNGEON])
				dungeons.append(dungeon + offset * CHUNK_SIZE)
	# Generate wordmap
	for x in range(CHUNK_SIZE.x):
		for y in range(CHUNK_SIZE.y):
			var tile := Vector2(x, y)
			if terrain.get_cell_atlas_coords(tile) != Vector2i(-1, -1):
				continue
			# Generate roads and settlements around dungeons
			var equidistant_dungeons = get_equidistant_dungeons(tile, dungeons)
			if equidistant_dungeons == 2:
				terrain.set_cell(tile, Globals.SOURCE_ID, TILES[TileTypes.ROAD])
				continue
			elif equidistant_dungeons > 2:
				terrain.set_cell(tile, Globals.SOURCE_ID, TILES[TileTypes.SETTLEMENT])
				continue
			# Generate forest and fields
			var noise := OVERWORLD_NOISE.get_noise_2dv(chunk_index * CHUNK_SIZE + tile)
			if noise < 0.0:
				terrain.set_cell(tile, Globals.SOURCE_ID, TILES[TileTypes.FIELD])
			else:
				terrain.set_cell(tile, Globals.SOURCE_ID, TILES[TileTypes.FOREST])
				rng.seed = hash(chunk_index * CHUNK_SIZE + tile)
				var chance := rng.randi() % 125
				if chance < 1:
					interactable.set_cell(tile, Globals.SOURCE_ID, TILES[TileTypes.APPLE])
				elif chance < 2:
					interactable.set_cell(tile, Globals.SOURCE_ID, TILES[TileTypes.ENEMY])
#endregion
