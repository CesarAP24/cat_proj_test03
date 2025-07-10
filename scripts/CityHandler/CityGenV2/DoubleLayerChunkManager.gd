class_name DoubleLayerChunkManager

var avenue_chunks: Dictionary = {}
var street_chunks: Dictionary = {}

var district_to_points: Dictionary = {}
var point_to_districts: Dictionary = {}

@export var avenue_chunk_size: int = 500
@export var street_chunk_size: int = 100
@export var avenue_render_distance: int = 3
@export var street_render_distance: int = 8
@export var max_avenue_points_per_chunk: int = 4
@export var max_street_points_per_chunk: int = 16
@export var seed_string: String = "ciudad_elegante"

func get_avenue_chunk_coord(world_x: float, world_y: float) -> Vector2i:
	return Vector2i(floor(world_x / avenue_chunk_size), floor(world_y / avenue_chunk_size))

func get_street_chunk_coord(world_x: float, world_y: float) -> Vector2i:
	return Vector2i(floor(world_x / street_chunk_size), floor(world_y / street_chunk_size))

func generate_avenue_chunk(cx: int, cy: int) -> Dictionary:
	var key = "%d,%d" % [cx, cy]
	if avenue_chunks.has(key):
		return avenue_chunks[key]
	
	var points = []
	var start = Vector2(cx * avenue_chunk_size, cy * avenue_chunk_size)
	var step = calculate_step_for_max_points(avenue_chunk_size, max_avenue_points_per_chunk)
	
	var point_id = 0
	for y in range(start.y, start.y + avenue_chunk_size, step):
		for x in range(start.x, start.x + avenue_chunk_size, step):
			var h = hash_coords(x, y, seed_string + "_avenue")
			var jitter_x = (h.fx - 0.5) * step * 0.3
			var jitter_y = (h.fy - 0.5) * step * 0.3
			
			points.append({
				"position": Vector2(x + jitter_x, y + jitter_y),
				"id": "ave_%d_%d_%d" % [cx, cy, point_id],
				"chunk_x": cx,
				"chunk_y": cy,
				"type": "avenue"
			})
			point_id += 1
	
	if points.is_empty():
		var center = Vector2(
			cx * avenue_chunk_size + avenue_chunk_size / 2,
			cy * avenue_chunk_size + avenue_chunk_size / 2
		)
		points.append({
			"position": center,
			"id": "ave_center_%d_%d" % [cx, cy],
			"chunk_x": cx,
			"chunk_y": cy,
			"type": "avenue"
		})
	
	var chunk = {
		"avenue_points": points,
		"chunk_x": cx,
		"chunk_y": cy,
		"type": "avenue",
		"world_bounds": Rect2(start, Vector2(avenue_chunk_size, avenue_chunk_size))
	}
	
	avenue_chunks[key] = chunk
	return chunk

func generate_street_chunk_with_assignment(cx: int, cy: int, current_districts: Array = []) -> Dictionary:
	var key = "%d,%d" % [cx, cy]
	if street_chunks.has(key):
		if current_districts.size() > 0:
			_assign_existing_points_to_districts(street_chunks[key], current_districts)
		return street_chunks[key]
	
	var points = []
	var start = Vector2(cx * street_chunk_size, cy * street_chunk_size)
	var step = calculate_step_for_max_points(street_chunk_size, max_street_points_per_chunk)
	
	var point_id = 0
	for y in range(start.y, start.y + street_chunk_size, step):
		for x in range(start.x, start.x + street_chunk_size, step):
			var h = hash_coords(x, y, seed_string + "_street")
			var jitter_x = (h.fx - 0.5) * step * 0.4
			var jitter_y = (h.fy - 0.5) * step * 0.4
			
			points.append({
				"position": Vector2(x + jitter_x, y + jitter_y),
				"id": "street_%d_%d_%d" % [cx, cy, point_id],
				"chunk_x": cx,
				"chunk_y": cy,
				"type": "street"
			})
			point_id += 1
	
	var chunk = {
		"street_points": points,
		"chunk_x": cx,
		"chunk_y": cy,
		"type": "street",
		"world_bounds": Rect2(start, Vector2(street_chunk_size, street_chunk_size))
	}
	
	street_chunks[key] = chunk
	
	if current_districts.size() > 0:
		_assign_existing_points_to_districts(chunk, current_districts)
	
	return chunk

func _assign_existing_points_to_districts(chunk: Dictionary, districts: Array):
	for point_data in chunk.street_points:
		var point = point_data.position
		var point_hash = get_point_hash(point)
		
		for district in districts:
			if GeometryUtils.point_in_polygon(point, district.vertices):
				var district_hash = get_district_hash(district.site)
				
				if not district_to_points.has(district_hash):
					district_to_points[district_hash] = []
				if not district_to_points[district_hash].has(point):
					district_to_points[district_hash].append(point)
				
				if not point_to_districts.has(point_hash):
					point_to_districts[point_hash] = []
				if not point_to_districts[point_hash].has(district_hash):
					point_to_districts[point_hash].append(district_hash)

func get_avenue_chunks_around(center_pos: Vector2) -> Array:
	var result = []
	var center_chunk = get_avenue_chunk_coord(center_pos.x, center_pos.y)
	
	for dx in range(-avenue_render_distance, avenue_render_distance + 1):
		for dy in range(-avenue_render_distance, avenue_render_distance + 1):
			var chunk_coord = Vector2i(center_chunk.x + dx, center_chunk.y + dy)
			result.append(generate_avenue_chunk(chunk_coord.x, chunk_coord.y))
	
	return result

func get_street_chunks_around_with_assignment(center_pos: Vector2, current_districts: Array = []) -> Array:
	var result = []
	var center_chunk = get_street_chunk_coord(center_pos.x, center_pos.y)
	
	for dx in range(-street_render_distance, street_render_distance + 1):
		for dy in range(-street_render_distance, street_render_distance + 1):
			var chunk_coord = Vector2i(center_chunk.x + dx, center_chunk.y + dy)
			result.append(generate_street_chunk_with_assignment(chunk_coord.x, chunk_coord.y, current_districts))
	
	return result

func get_street_chunks_around(center_pos: Vector2) -> Array:
	return get_street_chunks_around_with_assignment(center_pos, [])

func get_points_for_district(district_hash: String) -> Array:
	return district_to_points.get(district_hash, [])

func get_district_hash(avenue_point: Vector2) -> String:
	var precision = 10.0
	var x_int = int(round(avenue_point.x / precision)) * precision
	var y_int = int(round(avenue_point.y / precision)) * precision
	return "district_%d_%d" % [x_int, y_int]

func get_point_hash(point: Vector2) -> String:
	var precision = 5.0
	var x_int = int(round(point.x / precision)) * precision
	var y_int = int(round(point.y / precision)) * precision
	return "point_%d_%d" % [x_int, y_int]

func clear_district_assignments():
	district_to_points.clear()
	point_to_districts.clear()

func assign_all_current_points_to_districts(districts: Array):
	clear_district_assignments()
	
	for chunk in street_chunks.values():
		_assign_existing_points_to_districts(chunk, districts)

func calculate_step_for_max_points(chunk_size: int, max_points: int) -> int:
	var points_per_axis = int(ceil(sqrt(max_points)))
	var step = max(chunk_size / points_per_axis, 20)
	return int(step)

func hash_coords(x: float, y: float, seed_str: String) -> Dictionary:
	var base = "%s,%d,%d" % [seed_str, int(x), int(y)]
	return {
		"v": float(abs(base.hash()) % 10000) / 10000.0,
		"fx": float(abs((base + "_x").hash()) % 10000) / 10000.0,
		"fy": float(abs((base + "_y").hash()) % 10000) / 10000.0
	}

func clear():
	avenue_chunks.clear()
	street_chunks.clear()
	clear_district_assignments()

func get_debug_info() -> Dictionary:
	var avenue_point_count = 0
	var street_point_count = 0
	
	for chunk in avenue_chunks.values():
		avenue_point_count += chunk.avenue_points.size()
	
	for chunk in street_chunks.values():
		street_point_count += chunk.street_points.size()
	
	return {
		"avenue_chunks_loaded": avenue_chunks.size(),
		"street_chunks_loaded": street_chunks.size(),
		"total_avenue_points": avenue_point_count,
		"total_street_points": street_point_count,
		"districts_with_points": district_to_points.size(),
		"total_assigned_points": district_to_points.values().reduce(func(acc, arr): return acc + arr.size(), 0) if district_to_points.size() > 0 else 0
	}
