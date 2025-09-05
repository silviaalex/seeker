class_name Overworld
extends Node2D


## Chunk constants

const CHUNK = preload("res://scenes/overworld/chunk.tscn")
# Distance where chunks must be already made
const MIN_CHUNK_DISTANCE : = Vector2(20, 12)
# Distance from where chunks can be reused
const MAX_CHUNK_DISTANCE := Vector2(30, 18)


## Chunk arrays and multithreading

var chunks : Dictionary[Vector2, Chunk] = {}
var pending_chunks : Dictionary[Vector2, Chunk] = {}
var pending_threads : Dictionary[Vector2, Thread] = {}
var thread_pool : Array[Thread] = []


## Helper functions

func get_chunk_index(tile: Vector2) -> Vector2:
	return floor(tile / Chunk.CHUNK_SIZE)


## Tile info and modification

#region Tile info and modification
func get_local_tile(tile: Vector2) -> Vector2:
	var local_tile : Vector2
	local_tile.x = fposmod(tile.x, Chunk.CHUNK_SIZE.x)
	local_tile.y = fposmod(tile.y, Chunk.CHUNK_SIZE.y)
	return local_tile

func get_tile_data(tile: Vector2, property: StringName) -> bool:
	var chunk_index := get_chunk_index(tile)
	if chunk_index not in chunks:
		# Chunk doesn't exist
		return false
	# Get local tile out of world tile
	var local_tile := get_local_tile(tile)
	var chunk := chunks[chunk_index]
	var terrain_data := chunk.terrain.get_cell_tile_data(local_tile)
	var interactable_data := chunk.interactable.get_cell_tile_data(local_tile)
	var values := []
	if terrain_data != null and terrain_data.has_custom_data(property):
		values.append(terrain_data.get_custom_data(property))
	if interactable_data != null and interactable_data.has_custom_data(property):
		values.append(interactable_data.get_custom_data(property))
	return values.any(func(value: bool): return value)

func erase_interactable(tile: Vector2) -> void:
	var chunk_index := get_chunk_index(tile)
	if chunk_index not in chunks:
		# Chunk doesn't exist
		return
	var chunk := chunks[chunk_index]
	chunk.interactable.set_cell(get_local_tile(tile))

func pickup(tile: Vector2) -> void:
	erase_interactable(tile)

func attack(tile: Vector2) -> void:
	erase_interactable(tile)
#endregion


## Multithreading

#region Multithreading
func is_thread_finished(chunk_index: Vector2) -> bool:
	var thread := pending_threads[chunk_index]
	return thread.is_started() and not thread.is_alive()

func start_thread(chunk: Chunk, chunk_index: Vector2) -> void:
	chunk.setup(chunk_index)

func finish_thread(chunk_index: Vector2) -> void:
	# Terminate thread and prepare it for reuse
	pending_threads[chunk_index].wait_to_finish()
	thread_pool.append(pending_threads[chunk_index])
	pending_threads.erase(chunk_index)
	# Introduce chunk into view
	chunks[chunk_index] = pending_chunks[chunk_index]
	chunks[chunk_index].position = chunk_index * Globals.TILE_SIZE * Chunk.CHUNK_SIZE
	add_child(chunks[chunk_index])
	pending_chunks.erase(chunk_index)

func _exit_tree():
	for thread : Thread in pending_threads.values():
		if thread.is_started():
			thread.wait_to_finish()
#endregion


## Chunk generation

#region Chunk generation
func get_reusable_chunks(player_tile: Vector2,
		max_upper_left: Vector2, max_lower_right: Vector2) -> Array[Vector2]:
	# Get chunks available to be reused
	var chunk_pool : Array[Vector2] = []
	for chunk_index in chunks:
		if not Globals.is_in_bounds(chunk_index, max_upper_left, max_lower_right):
			chunk_pool.append(chunk_index)
	# Sort unused chunks by distance
	chunk_pool.sort_custom(func(a: Vector2, b: Vector2):
		var b_value := b * Chunk.CHUNK_SIZE + 0.5 * Chunk.CHUNK_SIZE
		var a_value := a * Chunk.CHUNK_SIZE + 0.5 * Chunk.CHUNK_SIZE
		var a_dist := Globals.get_manhattan_distance(player_tile, a_value)
		var b_dist := Globals.get_manhattan_distance(player_tile, b_value)
		return a_dist < b_dist)
	return chunk_pool

func update_multithreaded(player_tile: Vector2) -> void:
	# Get the distance limits of chunk generation and reuse
	var min_upper_left := get_chunk_index(player_tile - MIN_CHUNK_DISTANCE)
	var min_lower_right := get_chunk_index(player_tile + MIN_CHUNK_DISTANCE)
	var max_upper_left := get_chunk_index(player_tile - MAX_CHUNK_DISTANCE)
	var max_lower_right := get_chunk_index(player_tile + MAX_CHUNK_DISTANCE)
	# Get chunks available to be reused
	var chunk_pool := get_reusable_chunks(player_tile, max_upper_left, max_lower_right)
	# Create the needed threads to setup chunks
	for x in range(max_upper_left.x, max_lower_right.x + 1):
		for y in range(max_upper_left.y, max_lower_right.y + 1):
			var chunk_index := Vector2(x, y)
			if chunk_index in pending_chunks and is_thread_finished(chunk_index):
				# Thread finished execution and can be joined immediately
				finish_thread(chunk_index)
				continue
			if chunk_index in chunks or chunk_index in pending_chunks:
				# Chunk already created or in process of being created
				continue
			# Get the chunk used for generation
			var chunk : Chunk
			if chunk_pool.size() > 0:
				# Reuse far away chunks
				chunk = chunks[chunk_pool[chunk_pool.size() - 1]]
				chunks.erase(chunk_pool[chunk_pool.size() - 1])
				chunk_pool.resize(chunk_pool.size() - 1)
			else:
				# Create new chunk
				chunk = CHUNK.instantiate()
				add_child(chunk)
			# Get the thread used to process
			var thread : Thread
			if thread_pool.size() > 0:
				# Reuse inactive threads
				thread = thread_pool[thread_pool.size() - 1]
				thread_pool.resize(thread_pool.size() - 1)
			else:
				# Create new thread
				thread = Thread.new()
			remove_child(chunk)
			pending_chunks[chunk_index] = chunk
			pending_threads[chunk_index] = thread
			thread.start(start_thread.bind(chunk, chunk_index))
	# Create the needed chunks
	for x in range(min_upper_left.x, min_lower_right.x + 1):
		for y in range(min_upper_left.y, min_lower_right.y + 1):
			var chunk_index := Vector2(x, y)
			if chunk_index in chunks:
				continue
			# Make chunk visible
			finish_thread(chunk_index)
	# Finish remaining pending threads which can be joined immediately
	for chunk_index in pending_chunks:
		if pending_threads[chunk_index].is_started() \
				and not pending_threads[chunk_index].is_alive():
			finish_thread(chunk_index)

func update_singlethreaded(player_tile: Vector2) -> void:
	# Get the distance limits of chunk generation and reuse
	var min_upper_left := get_chunk_index(player_tile - MIN_CHUNK_DISTANCE)
	var min_lower_right := get_chunk_index(player_tile + MIN_CHUNK_DISTANCE)
	var max_upper_left := get_chunk_index(player_tile - MAX_CHUNK_DISTANCE)
	var max_lower_right := get_chunk_index(player_tile + MAX_CHUNK_DISTANCE)
	# Get chunks available to be reused
	var chunk_pool := get_reusable_chunks(player_tile, max_upper_left, max_lower_right)
	# Create the needed chunks
	for x in range(min_upper_left.x, min_lower_right.x + 1):
		for y in range(min_upper_left.y, min_lower_right.y + 1):
			var chunk_index := Vector2(x, y)
			if chunk_index in chunks:
				continue
			var chunk : Chunk
			if chunk_pool.size() > 0:
				# Reuse far away chunks
				chunk = chunks[chunk_pool[chunk_pool.size() - 1]]
				chunks.erase(chunk_pool[chunk_pool.size() - 1])
				chunk_pool.resize(chunk_pool.size() - 1)
			else:
				# Create new chunk
				chunk = CHUNK.instantiate()
				add_child(chunk)
			chunk.setup(chunk_index)
			chunk.position = chunk_index * Globals.TILE_SIZE * Chunk.CHUNK_SIZE
			chunks[chunk_index] = chunk
#endregion
