# PolygonSubdivider.gd
class_name PolygonSubdivider

# === CONFIGURATION ===
const MAX_ASPECT_RATIO = 2.5  # Máximo ratio width/height permitido
const MIN_LOT_WIDTH = 15.0     # Ancho mínimo absoluto para un lote
const SHAPE_VARIETY_FACTOR = 0.0  # Factor para generar más variación

# === MAIN SUBDIVISION FUNCTION ===
static func subdivide_polygon(polygon: Array, lot_size: int) -> Array:
	if polygon.size() < 3:
		return []
	
	# Calculate target lot area based on lot_size
	var target_area = lot_size * lot_size
	var total_area = calculate_polygon_area(polygon)
	
	# If polygon is already small enough and has good aspect ratio, return as single lot
	if total_area <= target_area * 1.5 and has_good_aspect_ratio(polygon):
		return [{
			"polygon": polygon,
			"street_side": find_street_side(polygon, polygon),
			"id": 1
		}]
	
	# Determine how many lots we need
	var num_lots = max(2, int(round(total_area / target_area)))
	
	# Try different subdivision strategies with aspect ratio validation
	var lots = try_smart_grid_subdivision(polygon, num_lots, target_area)
	
	if lots.is_empty() or not all_lots_have_good_ratios(lots):
		lots = try_adaptive_strip_subdivision(polygon, num_lots, target_area)
	
	if lots.is_empty() or not all_lots_have_good_ratios(lots):
		lots = try_organic_subdivision(polygon, num_lots, target_area)
	
	# If all fails, try to force good ratios
	if lots.is_empty():
		lots = [polygon]
	
	# Balance areas and fix aspect ratios
	lots = fix_aspect_ratios_and_balance(lots, target_area)
	return finalize_lots(lots, polygon)

# === ASPECT RATIO VALIDATION ===
static func has_good_aspect_ratio(polygon: Array) -> bool:
	var bbox = get_bounding_box(polygon)
	if bbox.size.x <= 0 or bbox.size.y <= 0:
		return false
	
	var aspect_ratio = max(bbox.size.x, bbox.size.y) / min(bbox.size.x, bbox.size.y)
	var min_dimension = min(bbox.size.x, bbox.size.y)
	
	return aspect_ratio <= MAX_ASPECT_RATIO and min_dimension >= MIN_LOT_WIDTH

static func all_lots_have_good_ratios(lots: Array) -> bool:
	for lot in lots:
		if not has_good_aspect_ratio(lot):
			return false
	return true

static func calculate_aspect_ratio(polygon: Array) -> float:
	var bbox = get_bounding_box(polygon)
	if bbox.size.x <= 0 or bbox.size.y <= 0:
		return 999.0  # Invalid ratio
	
	return max(bbox.size.x, bbox.size.y) / min(bbox.size.x, bbox.size.y)

# === SMART GRID SUBDIVISION ===
static func try_smart_grid_subdivision(polygon: Array, num_lots: int, target_area: float) -> Array:
	var bbox = get_bounding_box(polygon)
	var polygon_aspect = max(bbox.size.x, bbox.size.y) / min(bbox.size.x, bbox.size.y)
	
	# Calculate optimal grid dimensions considering polygon shape
	var best_lots = []
	var best_score = -1
	
	# Try different grid configurations that respect aspect ratios
	for rows in range(1, max(3, int(sqrt(num_lots)) + 2)):
		for cols in range(1, max(3, int(sqrt(num_lots)) + 2)):
			if rows * cols < max(2, num_lots * 0.7) or rows * cols > num_lots * 1.4:
				continue
			
			# Check if this grid would create good cell ratios
			var cell_aspect = (bbox.size.x / cols) / (bbox.size.y / rows)
			if cell_aspect > MAX_ASPECT_RATIO or cell_aspect < 1.0 / MAX_ASPECT_RATIO:
				continue
			
			var lots = create_adaptive_grid_lots(polygon, rows, cols, bbox, target_area)
			if lots.size() >= 2 and all_lots_have_good_ratios(lots):
				var score = evaluate_subdivision_quality(lots, target_area)
				if score > best_score:
					best_score = score
					best_lots = lots
	
	return best_lots

static func create_adaptive_grid_lots(polygon: Array, rows: int, cols: int, bbox: Rect2, target_area: float) -> Array:
	var lots = []
	
	# Add some randomness for variety
	var cell_width = bbox.size.x / cols
	var cell_height = bbox.size.y / rows
	
	for row in range(rows):
		for col in range(cols):
			# Add slight variation to avoid perfect grid monotony
			var variance_x = randf_range(-cell_width * SHAPE_VARIETY_FACTOR, cell_width * SHAPE_VARIETY_FACTOR)
			var variance_y = randf_range(-cell_height * SHAPE_VARIETY_FACTOR, cell_height * SHAPE_VARIETY_FACTOR)
			
			var x = bbox.position.x + col * cell_width + variance_x
			var y = bbox.position.y + row * cell_height + variance_y
			
			# Create slightly irregular cells for variety
			var cell_rect = create_varied_cell(x, y, cell_width, cell_height)
			
			# Clip cell with original polygon
			var clipped = clip_polygon_with_polygon(cell_rect, polygon)
			
			for clipped_poly in clipped:
				if clipped_poly.size() >= 4 and calculate_polygon_area(clipped_poly) > target_area * 0.3:
					if has_good_aspect_ratio(clipped_poly):
						lots.append(clipped_poly)
	
	return lots

static func create_varied_cell(x: float, y: float, width: float, height: float) -> Array:
	# Create slightly irregular quadrilateral instead of perfect rectangle
	var corners = [
		Vector2(x, y),
		Vector2(x + width, y),
		Vector2(x + width, y + height),
		Vector2(x, y + height)
	]
	
	# Add small variations to corners (except maintaining general rectangular shape)
	for i in range(corners.size()):
		var variance = min(width, height) * SHAPE_VARIETY_FACTOR * 0.5
		corners[i] += Vector2(
			randf_range(-variance, variance),
			randf_range(-variance, variance)
		)
	
	return corners

# === ADAPTIVE STRIP SUBDIVISION ===
static func try_adaptive_strip_subdivision(polygon: Array, num_lots: int, target_area: float) -> Array:
	var bbox = get_bounding_box(polygon)
	
	# Determine best strip direction to avoid skinny lots
	var horizontal_strips = create_horizontal_strips(polygon, num_lots, target_area)
	var vertical_strips = create_vertical_strips(polygon, num_lots, target_area)
	
	# Choose direction that produces better aspect ratios
	var h_score = evaluate_strips_aspect_ratio(horizontal_strips)
	var v_score = evaluate_strips_aspect_ratio(vertical_strips)
	
	var chosen_strips = horizontal_strips if h_score > v_score else vertical_strips
	
	# Further subdivide strips that are still too stretched
	var final_lots = []
	for strip in chosen_strips:
		if has_good_aspect_ratio(strip):
			final_lots.append(strip)
		else:
			# Subdivide this strip in the other direction
			var sub_lots = subdivide_stretched_strip(strip, target_area)
			final_lots.append_array(sub_lots)
	
	return final_lots

static func create_horizontal_strips(polygon: Array, num_strips: int, target_area: float) -> Array:
	var bbox = get_bounding_box(polygon)
	var strip_height = bbox.size.y / num_strips
	
	var strips = []
	for i in range(num_strips):
		var y_start = bbox.position.y + i * strip_height
		var y_end = y_start + strip_height
		
		var strip_rect = [
			Vector2(bbox.position.x - 1000, y_start),
			Vector2(bbox.position.x + bbox.size.x + 1000, y_start),
			Vector2(bbox.position.x + bbox.size.x + 1000, y_end),
			Vector2(bbox.position.x - 1000, y_end)
		]
		
		var clipped = clip_polygon_with_polygon(polygon, strip_rect)
		if clipped.size() > 0 and clipped[0].size() >= 4:
			strips.append(clipped[0])
	
	return strips

static func create_vertical_strips(polygon: Array, num_strips: int, target_area: float) -> Array:
	var bbox = get_bounding_box(polygon)
	var strip_width = bbox.size.x / num_strips
	
	var strips = []
	for i in range(num_strips):
		var x_start = bbox.position.x + i * strip_width
		var x_end = x_start + strip_width
		
		var strip_rect = [
			Vector2(x_start, bbox.position.y - 1000),
			Vector2(x_end, bbox.position.y - 1000),
			Vector2(x_end, bbox.position.y + bbox.size.y + 1000),
			Vector2(x_start, bbox.position.y + bbox.size.y + 1000)
		]
		
		var clipped = clip_polygon_with_polygon(polygon, strip_rect)
		if clipped.size() > 0 and clipped[0].size() >= 4:
			strips.append(clipped[0])
	
	return strips

static func evaluate_strips_aspect_ratio(strips: Array) -> float:
	var total_score = 0.0
	for strip in strips:
		var aspect = calculate_aspect_ratio(strip)
		if aspect <= MAX_ASPECT_RATIO:
			total_score += (MAX_ASPECT_RATIO - aspect) * 10.0
		else:
			total_score -= aspect  # Penalize bad ratios heavily
	return total_score

static func subdivide_stretched_strip(strip: Array, target_area: float) -> Array:
	var bbox = get_bounding_box(strip)
	var strip_area = calculate_polygon_area(strip)
	
	# Determine how to subdivide based on which dimension is longer
	if bbox.size.x > bbox.size.y:
		# Strip is too wide, subdivide vertically
		var num_parts = max(2, int(ceil(bbox.size.x / (bbox.size.y * MAX_ASPECT_RATIO))))
		return create_vertical_strips(strip, num_parts, target_area)
	else:
		# Strip is too tall, subdivide horizontally
		var num_parts = max(2, int(ceil(bbox.size.y / (bbox.size.x * MAX_ASPECT_RATIO))))
		return create_horizontal_strips(strip, num_parts, target_area)

# === ORGANIC SUBDIVISION ===
static func try_organic_subdivision(polygon: Array, num_lots: int, target_area: float) -> Array:
	# Create more natural, varied lot shapes using Voronoi-like approach
	var bbox = get_bounding_box(polygon)
	var seed_points = generate_good_seed_points(polygon, num_lots, bbox)
	
	if seed_points.size() < 2:
		return []
	
	var lots = create_voronoi_lots(polygon, seed_points)
	
	# Filter out lots with bad aspect ratios
	var good_lots = []
	for lot in lots:
		if has_good_aspect_ratio(lot) and calculate_polygon_area(lot) > target_area * 0.3:
			good_lots.append(lot)
	
	return good_lots

static func generate_good_seed_points(polygon: Array, num_points: int, bbox: Rect2) -> Array:
	var points = []
	var max_attempts = num_points * 5
	
	# Try to place seed points that would create reasonable lot shapes
	for attempt in range(max_attempts):
		if points.size() >= num_points:
			break
		
		var candidate = Vector2(
			randf_range(bbox.position.x + bbox.size.x * 0.1, bbox.position.x + bbox.size.x * 0.9),
			randf_range(bbox.position.y + bbox.size.y * 0.1, bbox.position.y + bbox.size.y * 0.9)
		)
		
		# Check if point is inside polygon and has good spacing
		if point_in_polygon(candidate, polygon) and has_good_spacing(candidate, points, bbox):
			points.append(candidate)
	
	return points

static func has_good_spacing(point: Vector2, existing_points: Array, bbox: Rect2) -> bool:
	var min_distance = min(bbox.size.x, bbox.size.y) / 4.0
	
	for existing in existing_points:
		if point.distance_to(existing) < min_distance:
			return false
	
	return true

static func create_voronoi_lots(polygon: Array, seed_points: Array) -> Array:
	# Simplified Voronoi diagram creation
	var lots = []
	var bbox = get_bounding_box(polygon)
	
	# Create a grid and assign each cell to nearest seed
	var grid_resolution = 20
	var cell_size_x = bbox.size.x / grid_resolution
	var cell_size_y = bbox.size.y / grid_resolution
	
	var voronoi_regions = {}
	
	for i in range(grid_resolution):
		for j in range(grid_resolution):
			var cell_center = Vector2(
				bbox.position.x + (i + 0.5) * cell_size_x,
				bbox.position.y + (j + 0.5) * cell_size_y
			)
			
			if point_in_polygon(cell_center, polygon):
				var nearest_seed = find_nearest_seed(cell_center, seed_points)
				if nearest_seed >= 0:
					if not voronoi_regions.has(nearest_seed):
						voronoi_regions[nearest_seed] = []
					
					var cell_poly = [
						Vector2(bbox.position.x + i * cell_size_x, bbox.position.y + j * cell_size_y),
						Vector2(bbox.position.x + (i + 1) * cell_size_x, bbox.position.y + j * cell_size_y),
						Vector2(bbox.position.x + (i + 1) * cell_size_x, bbox.position.y + (j + 1) * cell_size_y),
						Vector2(bbox.position.x + i * cell_size_x, bbox.position.y + (j + 1) * cell_size_y)
					]
					voronoi_regions[nearest_seed].append(cell_poly)
	
	# Merge cells belonging to same region
	for region_cells in voronoi_regions.values():
		var merged_region = merge_adjacent_cells(region_cells)
		if merged_region.size() >= 4:
			lots.append(merged_region)
	
	return lots

static func find_nearest_seed(point: Vector2, seeds: Array) -> int:
	var nearest_index = -1
	var min_distance = INF
	
	for i in range(seeds.size()):
		var distance = point.distance_to(seeds[i])
		if distance < min_distance:
			min_distance = distance
			nearest_index = i
	
	return nearest_index

static func merge_adjacent_cells(cells: Array) -> Array:
	# Simplified cell merging - return convex hull of all cell centers
	if cells.is_empty():
		return []
	
	var all_points = []
	for cell in cells:
		for point in cell:
			all_points.append(point)
	
	return convex_hull(all_points)

# === ASPECT RATIO FIXING ===
static func fix_aspect_ratios_and_balance(lots: Array, target_area: float) -> Array:
	var fixed_lots = []
	
	for lot in lots:
		if has_good_aspect_ratio(lot):
			fixed_lots.append(lot)
		else:
			# Try to fix bad aspect ratio by reshaping or subdividing
			var fixed = fix_single_lot_aspect_ratio(lot, target_area)
			fixed_lots.append_array(fixed)
	
	# Balance areas after fixing ratios
	return balance_lot_areas(fixed_lots, target_area)

static func fix_single_lot_aspect_ratio(lot: Array, target_area: float) -> Array:
	var bbox = get_bounding_box(lot)
	var aspect = max(bbox.size.x, bbox.size.y) / min(bbox.size.x, bbox.size.y)
	
	if aspect <= MAX_ASPECT_RATIO:
		return [lot]
	
	# If lot is too stretched, subdivide it
	var lot_area = calculate_polygon_area(lot)
	var num_parts = max(2, int(ceil(aspect / MAX_ASPECT_RATIO)))
	
	if bbox.size.x > bbox.size.y:
		return create_vertical_strips(lot, num_parts, target_area)
	else:
		return create_horizontal_strips(lot, num_parts, target_area)

# === UTILITY FUNCTIONS ===
static func calculate_polygon_area(polygon: Array) -> float:
	if polygon.size() < 3:
		return 0.0
	
	var area = 0.0
	for i in range(polygon.size()):
		var j = (i + 1) % polygon.size()
		area += polygon[i].x * polygon[j].y
		area -= polygon[j].x * polygon[i].y
	
	return abs(area) / 2.0

static func get_bounding_box(polygon: Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	
	var min_x = polygon[0].x
	var max_x = polygon[0].x
	var min_y = polygon[0].y
	var max_y = polygon[0].y
	
	for vertex in polygon:
		min_x = min(min_x, vertex.x)
		max_x = max(max_x, vertex.x)
		min_y = min(min_y, vertex.y)
		max_y = max(max_y, vertex.y)
	
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

static func evaluate_subdivision_quality(lots: Array, target_area: float) -> float:
	if lots.is_empty():
		return 0.0
	
	var score = 0.0
	
	for lot in lots:
		var area = calculate_polygon_area(lot)
		var aspect = calculate_aspect_ratio(lot)
		
		# Reward good aspect ratios heavily
		if aspect <= MAX_ASPECT_RATIO:
			score += (MAX_ASPECT_RATIO - aspect + 1.0) * 50.0
		else:
			score -= aspect * 100.0  # Heavy penalty for bad ratios
		
		# Reward areas close to target
		var area_ratio = area / target_area
		if area_ratio >= 0.5 and area_ratio <= 2.0:
			score += 30.0
		else:
			score -= abs(area_ratio - 1.0) * 20.0
		
		# Bonus for variety in vertex count
		if lot.size() == 4:
			score += 15.0
		elif lot.size() == 5:
			score += 20.0
		elif lot.size() == 6:
			score += 10.0
		else:
			score += 5.0
	
	return score

static func balance_lot_areas(lots: Array, target_area: float) -> Array:
	# Only merge/split if it maintains good aspect ratios
	var balanced_lots = []
	
	for lot in lots:
		var area = calculate_polygon_area(lot)
		
		if area < target_area * 0.4:
			# Try to merge with neighbor, but only if result has good ratio
			# For now, just keep small lots as they might be necessary for good ratios
			balanced_lots.append(lot)
		elif area > target_area * 2.5 and has_good_aspect_ratio(lot):
			# Split large lot if possible while maintaining good ratios
			var split_lots = try_split_large_lot(lot, target_area)
			balanced_lots.append_array(split_lots)
		else:
			balanced_lots.append(lot)
	
	return balanced_lots

static func try_split_large_lot(lot: Array, target_area: float) -> Array:
	var bbox = get_bounding_box(lot)
	var area = calculate_polygon_area(lot)
	var num_parts = int(ceil(area / target_area))
	
	# Try to split while maintaining good ratios
	if bbox.size.x > bbox.size.y:
		var split_lots = create_vertical_strips(lot, num_parts, target_area)
		if all_lots_have_good_ratios(split_lots):
			return split_lots
	else:
		var split_lots = create_horizontal_strips(lot, num_parts, target_area)
		if all_lots_have_good_ratios(split_lots):
			return split_lots
	
	# If splitting creates bad ratios, keep original
	return [lot]

# === GEOMETRIC UTILITY FUNCTIONS ===
static func point_in_polygon(point: Vector2, polygon: Array) -> bool:
	var inside = false
	var j = polygon.size() - 1
	
	for i in range(polygon.size()):
		if ((polygon[i].y > point.y) != (polygon[j].y > point.y)) and \
		   (point.x < (polygon[j].x - polygon[i].x) * (point.y - polygon[i].y) / (polygon[j].y - polygon[i].y) + polygon[i].x):
			inside = not inside
		j = i
	
	return inside

static func convex_hull(points: Array) -> Array:
	if points.size() < 3:
		return points
	
	# Simple gift wrapping algorithm
	var hull = []
	var leftmost = 0
	
	for i in range(1, points.size()):
		if points[i].x < points[leftmost].x:
			leftmost = i
	
	var current = leftmost
	
	while true:
		hull.append(points[current])
		var next_point = (current + 1) % points.size()
		
		for i in range(points.size()):
			if orientation(points[current], points[i], points[next_point]) == 2:
				next_point = i
		
		current = next_point
		if current == leftmost:
			break
	
	return hull

static func orientation(p: Vector2, q: Vector2, r: Vector2) -> int:
	var val = (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y)
	if val == 0:
		return 0
	return 1 if val > 0 else 2

static func clip_polygon_with_polygon(subject: Array, clip: Array) -> Array:
	# Simplified Sutherland-Hodgman clipping algorithm
	if subject.is_empty() or clip.is_empty():
		return []
	
	var output_list = subject.duplicate()
	
	for i in range(clip.size()):
		if output_list.is_empty():
			break
		
		var clip_edge_start = clip[i]
		var clip_edge_end = clip[(i + 1) % clip.size()]
		
		var input_list = output_list.duplicate()
		output_list.clear()
		
		if input_list.is_empty():
			continue
		
		var last_vertex = input_list[-1]
		
		for vertex in input_list:
			if is_inside_edge(vertex, clip_edge_start, clip_edge_end):
				if not is_inside_edge(last_vertex, clip_edge_start, clip_edge_end):
					var intersection = line_intersection(last_vertex, vertex, clip_edge_start, clip_edge_end)
					if intersection != Vector2.ZERO:
						output_list.append(intersection)
				output_list.append(vertex)
			elif is_inside_edge(last_vertex, clip_edge_start, clip_edge_end):
				var intersection = line_intersection(last_vertex, vertex, clip_edge_start, clip_edge_end)
				if intersection != Vector2.ZERO:
					output_list.append(intersection)
			
			last_vertex = vertex
	
	return [output_list] if output_list.size() >= 3 else []

static func is_inside_edge(point: Vector2, edge_start: Vector2, edge_end: Vector2) -> bool:
	return (edge_end.x - edge_start.x) * (point.y - edge_start.y) - (edge_end.y - edge_start.y) * (point.x - edge_start.x) >= 0

static func line_intersection(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> Vector2:
	var denom = (p1.x - p2.x) * (p3.y - p4.y) - (p1.y - p2.y) * (p3.x - p4.x)
	if abs(denom) < 1e-10:
		return Vector2.ZERO
	
	var t = ((p1.x - p3.x) * (p3.y - p4.y) - (p1.y - p3.y) * (p3.x - p4.x)) / denom
	return Vector2(p1.x + t * (p2.x - p1.x), p1.y + t * (p2.y - p1.y))

static func find_street_side(poly: Array, original_poly: Array) -> int:
	# Find the side that's most likely to be facing the street
	var longest_side_index = 0
	var longest_length = 0.0
	
	for i in range(poly.size()):
		var p1 = poly[i]
		var p2 = poly[(i + 1) % poly.size()]
		var length = p1.distance_to(p2)
		
		if length > longest_length:
			longest_length = length
			longest_side_index = i
	
	return longest_side_index

static func finalize_lots(lots: Array, original_polygon: Array) -> Array:
	var result = []
	
	for i in range(lots.size()):
		result.append({
			"polygon": lots[i],
			"street_side": find_street_side(lots[i], original_polygon),
			"id": i + 1
		})
	
	return result
