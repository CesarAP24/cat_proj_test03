# GeometryUtils.gd
class_name GeometryUtils

static func get_polygon_bounds(vertices: Array) -> Rect2:
	if vertices.is_empty():
		return Rect2()
	
	var min_x = vertices[0].x
	var max_x = vertices[0].x
	var min_y = vertices[0].y
	var max_y = vertices[0].y
	
	for vertex in vertices:
		min_x = min(min_x, vertex.x)
		max_x = max(max_x, vertex.x)
		min_y = min(min_y, vertex.y)
		max_y = max(max_y, vertex.y)
	
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

static func get_polygon_center(vertices: Array) -> Vector2:
	if vertices.is_empty():
		return Vector2.ZERO
	
	var center = Vector2.ZERO
	for vertex in vertices:
		center += vertex
	return center / vertices.size()

static func create_padded_polygon(vertices: Array, padding: float) -> Array:
	if padding <= 0 or vertices.size() < 3:
		return vertices
	
	var center = get_polygon_center(vertices)
	var result = []
	
	for vertex in vertices:
		var dx = vertex.x - center.x
		var dy = vertex.y - center.y
		var length = sqrt(dx * dx + dy * dy)
		
		if length == 0:
			result.append(vertex)
			continue
		
		var factor = max(0.0, (length - padding) / length)
		result.append(Vector2(
			center.x + dx * factor,
			center.y + dy * factor
		))
	
	return result

static func point_in_polygon(point: Vector2, polygon: Array) -> bool:
	var inside = false
	var j = polygon.size() - 1
	
	for i in range(polygon.size()):
		if ((polygon[i].y > point.y) != (polygon[j].y > point.y)) and \
		   (point.x < (polygon[j].x - polygon[i].x) * (point.y - polygon[i].y) / (polygon[j].y - polygon[i].y) + polygon[i].x):
			inside = !inside
		j = i
	
	return inside

# NUEVA FUNCIÓN: Recorte real de polígonos usando algoritmo Sutherland-Hodgman
static func clip_polygon(subject: Array, clip: Array) -> Array:
	if subject.is_empty() or clip.is_empty() or subject.size() < 3 or clip.size() < 3:
		return []
	
	var output = subject.duplicate()
	
	# Para cada lado del polígono de recorte
	for i in range(clip.size()):
		if output.is_empty():
			break
		
		var clip_start = clip[i]
		var clip_end = clip[(i + 1) % clip.size()]
		var input = output.duplicate()
		output.clear()
		
		if input.is_empty():
			continue
		
		var s = input[input.size() - 1]
		
		for e in input:
			if is_inside(e, clip_start, clip_end):
				if not is_inside(s, clip_start, clip_end):
					var intersection = line_intersection(s, e, clip_start, clip_end)
					if intersection != Vector2.INF:
						output.append(intersection)
				output.append(e)
			elif is_inside(s, clip_start, clip_end):
				var intersection = line_intersection(s, e, clip_start, clip_end)
				if intersection != Vector2.INF:
					output.append(intersection)
			s = e
	
	return output if output.size() >= 3 else []

# Determina si un punto está del lado "interno" de una línea
static func is_inside(point: Vector2, line_start: Vector2, line_end: Vector2) -> bool:
	return ((line_end.x - line_start.x) * (point.y - line_start.y) - 
			(line_end.y - line_start.y) * (point.x - line_start.x)) >= 0

# Encuentra la intersección entre dos líneas
static func line_intersection(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> Vector2:
	var denom = (p1.x - p2.x) * (p3.y - p4.y) - (p1.y - p2.y) * (p3.x - p4.x)
	if abs(denom) < 1e-10:
		return Vector2.INF  # No hay intersección
	
	var t = ((p1.x - p3.x) * (p3.y - p4.y) - (p1.y - p3.y) * (p3.x - p4.x)) / denom
	return Vector2(
		p1.x + t * (p2.x - p1.x),
		p1.y + t * (p2.y - p1.y)
	)
