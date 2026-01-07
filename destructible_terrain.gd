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
	terrain_details = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	terrain_details.fill(Color.WHITE)
	terrain_details.fill_rect(Rect2i(0, 0, width, sky_height), Color.TRANSPARENT)
	$Graphics.position = Vector2(width / 2.0, height / 2.0)
	$Graphics.texture = ImageTexture.create_from_image(terrain_details)
	update_terrain()
	
func update_terrain() -> void:
	if not is_terrain_dirty:
		return
		
	for child in $StaticBody2D.get_children():
		child.queue_free()
		
	var collidable = BitMap.new()
	collidable.create_from_image_alpha(terrain_details)
	
	var polygons = collidable.opaque_to_polygons(Rect2(0, 0, width, height), 2)
	
	for polygon in polygons:
		var collision = CollisionPolygon2D.new()
		collision.polygon = polygon
		$StaticBody2D.add_child(collision)
		
	$Graphics.texture.update(terrain_details)
	is_terrain_dirty = false
	
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
				terrain_details.set_pixel(x, y, Color.TRANSPARENT)
