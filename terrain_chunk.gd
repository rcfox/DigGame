class_name TerrainChunk
extends Node2D

var coords: Vector2i
var size: Vector2i
var sprite: Sprite2D
var collision_body: StaticBody2D
var terrain: Image

var terrain_threshold = -0.3
var terrain_color: Color

func _init(chunk_coords: Vector2i, chunk_size: Vector2i, terrain_color_: Color) -> void:
	self.coords = chunk_coords
	self.position = Vector2(chunk_coords.x * chunk_size.x, chunk_coords.y * chunk_size.y)
	self.size = chunk_size
	self.terrain_color = terrain_color_
	self.terrain = Image.create_empty(self.size[0], self.size[1], false, Image.FORMAT_RGBA8)
	self.collision_body = StaticBody2D.new()
	self.collision_body.visible = false
	self.sprite = Sprite2D.new()
	self.sprite.position = self.size / 2.0
	add_child(self.sprite)
	add_child(self.collision_body)
	
func generate_from_noise(noise: FastNoiseLite) -> void:
	var transparent = Color(terrain_color)
	transparent.a = 0
	for y in size.y:
		for x in size.x:
			var world_pos = Vector2i(int(position.x) + x, int(position.y) + y)
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
	
	var polygons = collidable.opaque_to_polygons(Rect2i(Vector2i(0, 0), size), 2)
	for polygon in polygons:
		if polygon.size() > 2:
			var collision = CollisionPolygon2D.new()
			collision.polygon = polygon
			collision_body.add_child(collision)
