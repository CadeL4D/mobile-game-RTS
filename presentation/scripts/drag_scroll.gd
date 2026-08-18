extends Node
class_name DragScroll

## Makes a ScrollContainer pannable by dragging anywhere inside it, including on
## top of its buttons, for both touch and mouse.
##
## Godot's own touch panning never reached these bars: mouse emulation consumes
## the gesture first, and even without that, a drag starting on a Button is taken
## by the Button. So the gesture is claimed here, ahead of the interface, and only
## once the finger has clearly travelled — below that threshold the press is left
## alone so buttons still work normally.

const DRAG_THRESHOLD := 10.0

var scroll: ScrollContainer
var _pressed := false
var _travelled := 0.0
var _last_position := Vector2.ZERO
var _panning := false

static func attach(target: ScrollContainer) -> DragScroll:
	var helper := DragScroll.new()
	helper.scroll = target
	target.add_child(helper)
	return helper

func _input(event: InputEvent) -> void:
	if scroll == null or not scroll.is_visible_in_tree():
		_reset()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if scroll.get_global_rect().has_point(event.position):
				_pressed = true
				_panning = false
				_travelled = 0.0
				_last_position = event.position
		elif _pressed:
			var was_panning := _panning
			_reset()
			# Swallow the release that ends a pan, otherwise the button under the
			# finger fires as though it had been tapped.
			if was_panning:
				get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _pressed:
		_apply_drag(event.position)
	elif event is InputEventScreenDrag and _pressed:
		_apply_drag(event.position)

func _apply_drag(position: Vector2) -> void:
	var delta := position - _last_position
	_last_position = position
	_travelled += delta.length()
	if _travelled < DRAG_THRESHOLD:
		return
	_panning = true
	if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		scroll.scroll_horizontal -= int(delta.x)
	if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		scroll.scroll_vertical -= int(delta.y)
	get_viewport().set_input_as_handled()

func _reset() -> void:
	_pressed = false
	_panning = false
	_travelled = 0.0
