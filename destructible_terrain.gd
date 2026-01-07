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

@export var chunk_size: int = 128

var terrain_details: Image
var is_terrain_dirty: bool = true
var is_chunk_dirty: Array[bool]

func init_terrain() -> void:
	if not is_inside_tree():
		return
	is_terrain_dirty = true
	
	init_chunks()
	
	terrain_details = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	terrain_details.fill(Color.WHITE)
	terrain_details.fill_rect(Rect2i(0, 0, width, sky_height), Color.TRANSPARENT)
	$Graphics.position = Vector2(width / 2.0, height / 2.0)
	$Graphics.texture = ImageTexture.create_from_image(terrain_details)
	update_terrain()
	
func init_chunks() -> void:
	var num_chunks = ceili(width / float(chunk_size)) * ceili(height / float(chunk_size))
	is_chunk_dirty.resize(num_chunks)
	
	for child in $Chunks.get_children():
		child.queue_free()
	
	for chunk in range(num_chunks):
		is_chunk_dirty[chunk] = true
		var body = StaticBody2D.new()
		$Chunks.add_child(body)

func get_chunk_rect(chunk_index: int) -> Rect2i:
	var chunks_per_row = ceili(width / float(chunk_size))
	
	var chunk_x = chunk_index % chunks_per_row
	@warning_ignore("integer_division")
	var chunk_y = chunk_index / chunks_per_row
	
	var x = chunk_x * chunk_size
	var y = chunk_y * chunk_size
	
	# Handle edge chunks that might be smaller
	var w = mini(chunk_size, width - x)
	var h = mini(chunk_size, height - y)
	
	return Rect2i(x, y, w, h)
	
func get_chunk_index(x: int, y: int) -> int:
	if x < 0 or x >= width or y < 0 or y >= height:
		return -1
	
	var chunks_per_row = ceili(width / float(chunk_size))
	
	@warning_ignore("integer_division")
	var chunk_x = x / chunk_size
	@warning_ignore("integer_division")
	var chunk_y = y / chunk_size
	return chunk_y * chunks_per_row + chunk_x
	
func update_terrain() -> void:
	if not is_terrain_dirty:
		return
	is_terrain_dirty = false
	
	if $Graphics.texture:
			$Graphics.texture.update(terrain_details)
		
	for chunk in range(is_chunk_dirty.size()):
		if not is_chunk_dirty[chunk]:
			continue
		is_chunk_dirty[chunk] = false
			
		var chunk_body: StaticBody2D = $Chunks.get_child(chunk)
		for child in chunk_body.get_children():
			child.queue_free()
		
		var collidable = BitMap.new()
		var chunk_rect = get_chunk_rect(chunk)
		collidable.create_from_image_alpha(terrain_details.get_region(chunk_rect))
		
		chunk_body.position = chunk_rect.position
	
		var polygons = collidable.opaque_to_polygons(Rect2(0, 0, chunk_size, chunk_size), 2)
		for polygon in polygons:
			var collision = CollisionPolygon2D.new()
			collision.polygon = polygon
			chunk_body.add_child(collision)
	
func _ready() -> void:
	init_terrain()

func _process(_delta: float) -> void:
	update_terrain()		
	
func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		# Clear the texture before saving so that we don't serialize it.
		$Graphics.texture = null
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		# Regenerate the terrain after saving so it renders again.
		init_terrain()

func _input(event):
	if event is InputEventMouseButton and event.is_pressed():
		carve_circle(to_local(event.position), 20)

func carve_circle(center: Vector2i, radius: int) -> void:
	is_terrain_dirty = true
	var rsq = radius * radius
	for dy in range(-radius, radius + 1):
		var dx_max = int(sqrt(rsq - dy * dy))
		for dx in range(-dx_max, dx_max + 1):
			var x = center.x + dx
			var y = center.y + dy
			if x >= 0 and x < width and y >= 0 and y < height:
				var chunk_index = get_chunk_index(x, y)
				is_chunk_dirty[chunk_index] = true
				terrain_details.set_pixel(x, y, Color.TRANSPARENT)
