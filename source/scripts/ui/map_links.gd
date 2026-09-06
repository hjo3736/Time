class_name MapLinks
extends Control


const SPACING := 2.6


var segments: Array = []


func _draw() -> void:
	for piece in segments:
		_dotted(piece["points"], piece["shade"], piece["width"])


func _dotted(points: PackedVector2Array, shade: Color, width: float) -> void:
	var radius := width * 0.5
	var gap := maxf(width * SPACING, 6.0)
	var walked := 0.0
	var next_dot := 0.0
	for i in range(points.size() - 1):
		var from := points[i]
		var span := points[i + 1] - from
		var reach := span.length()
		if reach <= 0.001:
			continue
		var way := span / reach
		while next_dot <= walked + reach:
			draw_circle(from + way * (next_dot - walked), radius, shade, true, -1.0, true)
			next_dot += gap
		walked += reach
