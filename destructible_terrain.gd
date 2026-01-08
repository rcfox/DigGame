@tool
extends Node2D

@export var width: int = 1024:
	set(value):
		width = value
		init_terrain()
		
@export var height: int = 768:
	set(value):
		height = value
		init_terrain()
		
@export var sky_height: int = 200:
	set(value):
		sky_height = value
		init_terrain()

@export var chunk_size: int = 128:
	set(value):
		chunk_size = value
		init_terrain()
		
@export var terrain_color: Color = Color(0x33/255.0, 0x22/255.0, 0x11/255.0, 1): # Hex color: #332211
	set(value):
		terrain_color = value
		init_terrain()

var terrain_details: Image

var dirty_chunks: Array[int]
var chunks: Array[TerrainChunk] = []

func init_terrain() -> void:
	if not is_inside_tree():
		return
	
	var color = Color(terrain_color)
	terrain_details = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	terrain_details.fill(color)
	
	color.a = 0
	terrain_details.fill_rect(Rect2i(0, 0, width, sky_height), color)
	
	init_chunks()
	update_terrain()
	
func init_chunks() -> void:
	for child in $Chunks.get_children():
		child.queue_free()
		
	chunks = TerrainChunk.generate_chunks(width, height, chunk_size)
	for chunk_idx in range(chunks.size()):
		var chunk = chunks[chunk_idx]
		$Chunks.add_child(chunk)
		dirty_chunks.append(chunk_idx)
	
func update_terrain() -> void:
	for chunk_idx in dirty_chunks:
		var chunk = chunks[chunk_idx]
		chunk.update(terrain_details)
		
	dirty_chunks.clear()
	
func _ready() -> void:
	init_terrain()

func _process(_delta: float) -> void:
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
			if x >= 0 and x < width and y >= 0 and y < height:
				var chunk_index = TerrainChunk.get_chunk_index(width, height, chunk_size, x, y)
				# This array should usually be tiny, so the "not in" check should be cheap.
				if chunk_index not in dirty_chunks:
					dirty_chunks.append(chunk_index)
				var color = terrain_details.get_pixel(x, y)
				color.a = 0
				terrain_details.set_pixel(x, y, color)
