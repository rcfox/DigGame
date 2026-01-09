class_name TerrainChunk
extends Node2D

var rect: Rect2i
var sprite: Sprite2D
var collision_body: StaticBody2D
var terrain: Image
var noise: FastNoiseLite

var terrain_threshold = -0.3
var terrain_color: Color

static func generate_chunks(
	width: int,
	height: int,
	chunk_size: int,
	noise_src: FastNoiseLite,
	terrain_color: Color
	) -> Array[TerrainChunk]:
	var num_chunks = TerrainChunk.get_num_chunks(width, height, chunk_size)
	var chunks: Array[TerrainChunk] = []
	for chunk_idx in range(num_chunks):
		var chunk_rect = TerrainChunk.get_chunk_rect(width, height, chunk_size, chunk_idx)
		var chunk = TerrainChunk.new(chunk_rect, noise_src, terrain_color)
		chunk.generate_from_noise()
		chunks.append(chunk)
	return chunks
	
static func get_num_chunks(width: int, height: int, chunk_size: int) -> int:
	return ceili(width / float(chunk_size)) * ceili(height / float(chunk_size))
	
static func get_chunk_index(width: int, height: int, chunk_size: int, x: int, y: int) -> int:
	if x < 0 or x >= width or y < 0 or y >= height:
		return -1
	
	var chunks_per_row = ceili(width / float(chunk_size))
	
	@warning_ignore("integer_division")
	var chunk_x = x / chunk_size
	@warning_ignore("integer_division")
	var chunk_y = y / chunk_size
	return chunk_y * chunks_per_row + chunk_x

static func get_chunk_rect(width: int, height: int, chunk_size: int, chunk_index: int) -> Rect2i:
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


func _init(chunk_rect: Rect2i, noise_src: FastNoiseLite, terrain_color: Color) -> void:
	self.rect = chunk_rect
	self.noise = noise_src
	self.terrain_color = terrain_color
	self.terrain = Image.create_empty(self.rect.size[0], self.rect.size[1], false, Image.FORMAT_RGBA8)
	self.position = self.rect.position
	self.collision_body = StaticBody2D.new()
	self.collision_body.visible = false
	self.sprite = Sprite2D.new()
	self.sprite.position = self.rect.size / 2.0
	add_child(self.sprite)
	add_child(self.collision_body)
	
func generate_from_noise() -> void:
	var transparent = Color(terrain_color)
	transparent.a = 0
	for y in rect.size.y:
		for x in rect.size.x:
			var world_pos = rect.position + Vector2i(x, y)
			var noise_val = noise.get_noise_2d(world_pos.x, world_pos.y)
			if noise_val > terrain_threshold:
				terrain.set_pixel(x, y, terrain_color)
			else:
				terrain.set_pixel(x, y, transparent)

func update() -> void:
	if not sprite.texture:
		sprite.texture = ImageTexture.create_from_image(terrain)
	else:
		sprite.texture.update(terrain)
	
	for child in collision_body.get_children():
		child.queue_free()
	
	var collidable = BitMap.new()
	collidable.create_from_image_alpha(terrain)
	
	var polygons = collidable.opaque_to_polygons(Rect2i(Vector2i(0, 0), rect.size), 2)
	for polygon in polygons:
		var collision = CollisionPolygon2D.new()
		collision.polygon = polygon
		collision_body.add_child(collision)
	
