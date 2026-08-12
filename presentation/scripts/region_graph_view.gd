class_name RegionGraphView
extends Control

var regions: Array = []
var region_by_id: Dictionary = {}

func configure(definitions: Array) -> void:
	regions = definitions
	region_by_id.clear()
	for region in regions:
		region_by_id[String(region.id)] = region
	queue_redraw()

func _draw() -> void:
	var drawn: Dictionary = {}
	for region in regions:
		var from := _point(region)
		for neighbor_id in region.get("adjacent", []):
			var pair := [String(region.id), String(neighbor_id)]
			pair.sort()
			var edge_key := "%s:%s" % pair
			if drawn.has(edge_key) or not region_by_id.has(String(neighbor_id)):
				continue
			drawn[edge_key] = true
			var to := _point(region_by_id[String(neighbor_id)])
			draw_line(from, to, Color(0.03, 0.05, 0.06, 0.82), 6.0, true)
			draw_line(from, to, Color(0.35, 0.88, 0.72, 0.72), 2.0, true)

func _point(region: Dictionary) -> Vector2:
	var coordinates: Array = region.position
	return Vector2(float(coordinates[0]) * size.x, float(coordinates[1]) * size.y)
