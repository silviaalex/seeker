extends Node

const TILE_SIZE : Vector2 = preload("res://scenes/tileset/tileset.tres").tile_size
const SOURCE_ID := 0

## Helper functions

func get_euclidean_distance(a: Vector2, b: Vector2) -> float:
	return a.distance_squared_to(b)

func get_manhattan_distance(a: Vector2, b : Vector2) -> float:
	return abs(a.x - b.x) + abs(a.y - b.y)

func get_chebyshev_distance(a: Vector2, b : Vector2) -> float:
	return max(abs(a.x - b.x), abs(a.y - b.y))

func is_in_between(value: float, min_value: float, max_value: float) -> bool:
	return value >= min_value and value <= max_value

func is_in_bounds(point: Vector2, upper_left: Vector2, lower_right: Vector2) -> bool:
	var horizontal_inclusion := is_in_between(point.x, upper_left.x, lower_right.x)
	var vertical_inclusion := is_in_between(point.y, upper_left.y, lower_right.y)
	return horizontal_inclusion and vertical_inclusion
