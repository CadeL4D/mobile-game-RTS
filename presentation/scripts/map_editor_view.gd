class_name MapEditorView
extends Control

signal blueprint_changed
signal status_changed(message: String)

const TILE_COLORS := {
	RegionGenerator.Tile.DEEP_WATER: Color("0b4169"), RegionGenerator.Tile.GRASS: Color("4b7c22"),
	RegionGenerator.Tile.FOREST_FLOOR: Color("185c25"), RegionGenerator.Tile.ROCKY: Color("777972"),
	RegionGenerator.Tile.CRYSTAL_GROUND: Color("1b9fae"), RegionGenerator.Tile.FERTILE: Color("8e9d2e"),
	RegionGenerator.Tile.SAND: Color("b58b42"), RegionGenerator.Tile.MARSH: Color("36594a"),
	RegionGenerator.Tile.CORRUPTION: Color("681052"),
}

var blueprint: RegionBlueprint
var image: Image
var texture: ImageTexture
var paint_tile := RegionGenerator.Tile.GRASS
var brush_radius := 3
var painting := false

func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	gui_input.connect(_on_gui_input)

func set_blueprint(value: RegionBlueprint) -> void:
	blueprint = value
	_rebuild_image()

func set_paint_tile(value: int) -> void:
	paint_tile = value

func set_brush_radius(value: int) -> void:
	brush_radius = clampi(value, 1, 12)

func _rebuild_image() -> void:
	if blueprint == null:
		return
	image = Image.create(blueprint.width, blueprint.height, false, Image.FORMAT_RGBA8)
	for y in blueprint.height:
		for x in blueprint.width:
			image.set_pixel(x, y, TILE_COLORS.get(blueprint.get_tile(Vector2i(x, y)), Color.MAGENTA))
	texture = ImageTexture.create_from_image(image)
	queue_redraw()

func _draw() -> void:
	if texture:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)

func _on_gui_input(event: InputEvent) -> void:
	if blueprint == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		painting = event.pressed
		if painting:
			_paint_at(event.position)
		accept_event()
	elif event is InputEventMouseMotion and painting:
		_paint_at(event.position)
		accept_event()
	elif event is InputEventScreenTouch:
		painting = event.pressed
		if painting:
			_paint_at(event.position)
		accept_event()
	elif event is InputEventScreenDrag:
		_paint_at(event.position)
		accept_event()

func _paint_at(local_position: Vector2) -> void:
	var cell := Vector2i(floori(local_position.x / maxf(1.0, size.x) * blueprint.width), floori(local_position.y / maxf(1.0, size.y) * blueprint.height))
	for y in range(cell.y - brush_radius + 1, cell.y + brush_radius):
		for x in range(cell.x - brush_radius + 1, cell.x + brush_radius):
			var candidate := Vector2i(x, y)
			if Vector2(candidate - cell).length() > brush_radius or candidate.x < 0 or candidate.y < 0 or candidate.x >= blueprint.width or candidate.y >= blueprint.height:
				continue
			blueprint.set_tile(candidate, paint_tile)
			image.set_pixel(candidate.x, candidate.y, TILE_COLORS[paint_tile])
	texture.update(image)
	blueprint_changed.emit()
	queue_redraw()
