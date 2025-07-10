# PolygonSubdivider.gd
class_name PolygonSubdivider

static func distance(p1: Vector2, p2: Vector2) -> float:
	return p1.distance_to(p2)

static func get_two_longest_sides(poly: Array) -> Array:
	var sides = []
	
	for i in range(poly.size()):
		var p1 = poly[i]
		var p2 = poly[(i + 1) % poly.size()]
		sides.append({
			"p1": p1,
			"p2": p2,
			"length": distance(p1, p2)
		})
	
	sides.sort_custom(func(a, b): return a.length > b.length)
	return [sides[0], sides[1]] if sides.size() >= 2 else [sides[0]]

static func lerp_vector2(p1: Vector2, p2: Vector2, t: float) -> Vector2:
	return p1.lerp(p2, t)

static func line_intersection(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> Vector2:
	var denom = (p1.x - p2.x) * (p3.y - p4.y) - (p1.y - p2.y) * (p3.x - p4.x)
	if abs(denom) < 1e-10:
		return Vector2.ZERO # No intersection
	
	var t = ((p1.x - p3.x) * (p3.y - p4.y) - (p1.y - p3.y) * (p3.x - p4.x)) / denom
	var u = -((p1.x - p2.x) * (p1.y - p3.y) - (p1.y - p2.y) * (p1.x - p3.x)) / denom
	
	if u >= 0 and u <= 1:
		return Vector2(p1.x + t * (p2.x - p1.x), p1.y + t * (p2.y - p1.y))
	
	return Vector2.ZERO

static func distance_to_line_segment(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var A = point.x - line_start.x
	var B = point.y - line_start.y
	var C = line_end.x - line_start.x
	var D = line_end.y - line_start.y
	
	var dot = A * C + B * D
	var len_sq = C * C + D * D
	
	if len_sq == 0:
		return distance(point, line_start)
	
	var param = dot / len_sq
	var xx: float
	var yy: float
	
	if param < 0:
		xx = line_start.x
		yy = line_start.y
	elif param > 1:
		xx = line_end.x
		yy = line_end.y
	else:
		xx = line_start.x + param * C
		yy = line_start.y + param * D
	
	return distance(point, Vector2(xx, yy))

static func is_point_on_polygon_edge(point: Vector2, poly: Array, tolerance: float = 2.0) -> bool:
	for i in range(poly.size()):
		var p1 = poly[i]
		var p2 = poly[(i + 1) % poly.size()]
		var dist = distance_to_line_segment(point, p1, p2)
		if dist < tolerance:
			return true
	return false

static func find_street_side(poly: Array, original_poly: Array) -> int:
	for i in range(poly.size()):
		var p1 = poly[i]
		var p2 = poly[(i + 1) % poly.size()]
		
		if is_point_on_polygon_edge(p1, original_poly) and is_point_on_polygon_edge(p2, original_poly):
			return i
	return 0

static func cut_polygon_with_line(poly: Array, line_start: Vector2, line_end: Vector2) -> Array:
	var intersections = []
	
	for i in range(poly.size()):
		var p1 = poly[i]
		var p2 = poly[(i + 1) % poly.size()]
		var intersection = line_intersection(line_start, line_end, p1, p2)
		if intersection != Vector2.ZERO:
			intersections.append({"point": intersection, "edge_index": i})
	
	if intersections.size() != 2:
		return [poly]
	
	var int1 = intersections[0]
	var int2 = intersections[1]
	var poly1 = []
	var poly2 = []
	
	# Build first polygon
	for i in range(int1.edge_index + 1):
		poly1.append(poly[i])
	poly1.append(int1.point)
	poly1.append(int2.point)
	for i in range(int2.edge_index + 1, poly.size()):
		poly1.append(poly[i])
	
	# Build second polygon
	poly2.append(int1.point)
	for i in range(int1.edge_index + 1, int2.edge_index + 1):
		poly2.append(poly[i])
	poly2.append(int2.point)
	
	var result = []
	if poly1.size() >= 3:
		result.append(poly1)
	if poly2.size() >= 3:
		result.append(poly2)
	
	return result

static func subdivide_polygon(polygon: Array, lot_size: int) -> Array:
	if polygon.size() < 3:
		return []
	
	var longest_sides = get_two_longest_sides(polygon)
	var longest = longest_sides[0]
	
	if longest.length < lot_size * 1.5:
		return [{
			"polygon": polygon,
			"street_side": find_street_side(polygon, polygon),
			"id": 1
		}]
	
	var polygons = [{"polygon": polygon, "original": polygon}]
	
	# Cut along longest side
	var num_cuts = max(1, int(floor(longest.length / lot_size)))
	var perp_dir = Vector2(-(longest.p2.y - longest.p1.y), longest.p2.x - longest.p1.x)
	var perp_length = perp_dir.length()
	if perp_length > 0:
		perp_dir = perp_dir / perp_length
	
	for i in range(1, num_cuts + 1):
		var t = float(i) / float(num_cuts + 1)
		var cut_point = lerp_vector2(longest.p1, longest.p2, t)
		var line_start = cut_point - perp_dir * 1000
		var line_end = cut_point + perp_dir * 1000
		
		var new_polygons = []
		for poly_obj in polygons:
			var cut_result = cut_polygon_with_line(poly_obj.polygon, line_start, line_end)
			for cut_poly in cut_result:
				new_polygons.append({"polygon": cut_poly, "original": poly_obj.original})
		polygons = new_polygons
	
	# Cut along second longest if needed
	if longest_sides.size() > 1:
		var second_longest = longest_sides[1]
		if second_longest.length > lot_size:
			var mid_point = lerp_vector2(second_longest.p1, second_longest.p2, 0.5)
			var parallel_dir = Vector2(longest.p2.x - longest.p1.x, longest.p2.y - longest.p1.y)
			var parallel_length = parallel_dir.length()
			if parallel_length > 0:
				parallel_dir = parallel_dir / parallel_length
			
			var line_start = mid_point - parallel_dir * 1000
			var line_end = mid_point + parallel_dir * 1000
			
			var final_polygons = []
			for poly_obj in polygons:
				var cut_result = cut_polygon_with_line(poly_obj.polygon, line_start, line_end)
				for cut_poly in cut_result:
					final_polygons.append({"polygon": cut_poly, "original": poly_obj.original})
			polygons = final_polygons
	
	var result = []
	for i in range(polygons.size()):
		var poly_obj = polygons[i]
		result.append({
			"polygon": poly_obj.polygon,
			"street_side": find_street_side(poly_obj.polygon, poly_obj.original),
			"id": i + 1
		})
	
	return result
