#@tool
extends Node2D

@export var chunk_size: int = 128:
	set(value):
		chunk_size = value
		init_terrain()
		
@export var terrain_color: Color = Color(0x33/255.0, 0x22/255.0, 0x11/255.0, 1): # Hex color: #332211
	set(value):
		terrain_color = value
		init_terrain()
		
@export var load_radius: int = 10  # Chunks to keep loaded around player
@export var unload_radius: int = 15  # Unload beyond this distance

@export var players: Array[Node2D] = []

var noise = FastNoiseLite.new()

var chunks: Dictionary[Vector2i, TerrainChunk] = {}
var dirty_chunks: Dictionary[Vector2i, bool] = {}
var unloaded_chunks: Dictionary[Vector2i, PackedByteArray] = {}

var chunks_to_generate: Array[Vector2i] = []

func get_chunk_coords(world_pos: Vector2i) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / float(chunk_size)),
		floori(world_pos.y / float(chunk_size))
	)
	
func get_or_create_chunk(chunk_coords: Vector2i) -> TerrainChunk:
	if chunk_coords not in chunks:
		var chunk = TerrainChunk.new(chunk_coords, Vector2i(chunk_size, chunk_size), terrain_color)
		
		if chunk_coords in unloaded_chunks:
			chunk.terrain.load_webp_from_buffer(unloaded_chunks[chunk_coords])
			unloaded_chunks.erase(chunk_coords)
		else:
			chunk.generate_from_noise(noise)
		chunk.update()
		$Chunks.add_child(chunk)
		chunks[chunk_coords] = chunk
	return chunks[chunk_coords]

func init_terrain() -> void:
	if not is_inside_tree():
		return
	noise.frequency = 0.001
	
	for child in $Chunks.get_children():
		child.queue_free()
		
	update_terrain()
	update_loaded_chunks()
	
	for coords in chunks_to_generate:
		get_or_create_chunk(coords)
	chunks_to_generate.clear()
	
	for player in players:
		carve_circle(player.global_position, 50)
	
func update_terrain() -> void:
	for chunk_idx in dirty_chunks:
		var chunk = chunks[chunk_idx]
		chunk.update()
		
	dirty_chunks.clear()
	
func update_loaded_chunks() -> void:
	var to_unload: Array[Vector2i] = []
	for player in players:
		var player_chunk = get_chunk_coords(Vector2i(player.global_position))
	
		# Load chunks around player
		for cy in range(player_chunk.y - load_radius, player_chunk.y + load_radius + 1):
			for cx in range(player_chunk.x - load_radius, player_chunk.x + load_radius + 1):
				var coords = Vector2i(cx, cy)
				if coords not in chunks and coords not in chunks_to_generate:
					# Queue chunks to be loaded so they can be spread out over multiple frames.
					chunks_to_generate.append(coords)
		
		# Unload distant chunks
		for chunk_coords in chunks.keys():
			var dist = (chunk_coords - player_chunk).length()
			if dist > unload_radius:
				to_unload.append(chunk_coords)
	
	for coords in to_unload:
		unload_chunk(coords)

func unload_chunk(chunk_coords: Vector2i) -> void:
	if chunk_coords in chunks:
		var chunk = chunks[chunk_coords]
		unloaded_chunks[chunk_coords] = chunk.terrain.save_webp_to_buffer()
		chunk.queue_free()
		chunks.erase(chunk_coords)
	
func _ready() -> void:
	init_terrain()

func _process(_delta: float) -> void:
	update_loaded_chunks()
	
	var chunks_this_frame = 2
	while chunks_this_frame > 0 and chunks_to_generate.size() > 0:
		var coords = chunks_to_generate.pop_back()
		get_or_create_chunk(coords)
		chunks_this_frame -= 1
	
	update_terrain()

func _input(event):
	if event is InputEventMouseButton and event.is_pressed():
		carve_circle(to_local(get_global_mouse_position()), 30)

func carve_circle(center: Vector2i, radius: int) -> void:
	var rsq = radius * radius
	for dy in range(-radius, radius + 1):
		var dx_max = int(sqrt(rsq - dy * dy))
		for dx in range(-dx_max, dx_max + 1):
			var x = center.x + dx
			var y = center.y + dy

			var chunk_coords = get_chunk_coords(Vector2i(x, y))
			var chunk = chunks[chunk_coords]
			var terrain = chunk.terrain
			var cx = x - chunk.position.x
			var cy = y - chunk.position.y
			var color = terrain.get_pixel(cx, cy)
			color.a = 0
			terrain.set_pixel(cx, cy, color)
			dirty_chunks[chunk_coords] = true
