class_name SpatialChunkManager

var avenue_chunks: Dictionary = {}
var street_chunks: Dictionary = {}
var district_point_assignments: Dictionary = {}
var point_district_assignments: Dictionary = {}

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

func get_avenue_points_in_render_distance(player_pos: Vector2) -> Array:
	var result = []
	var center_chunk = get_avenue_chunk_coord(player_pos.x, player_pos.y)
	
	for dx in range(-avenue_render_distance, avenue_render_distance + 1):
		for dy in range(-avenue_render_distance, avenue_render_distance + 1):
			var chunk_coord = Vector2i(center_chunk.x + dx, center_chunk.y + dy)
			var chunk = generate_avenue_chunk(chunk_coord.x, chunk_coord.y)
			
			for point_data in chunk.avenue_points:
				result.append(point_data.position)
	
	return result

func get_street_points_in_render_distance(player_pos: Vector2) -> Array:
	var result = []
	var center_chunk = get_street_chunk_coord(player_pos.x, player_pos.y)
	
	for dx in range(-street_render_distance, street_render_distance + 1):
		for dy in range(-street_render_distance, street_render_distance + 1):
			var chunk_coord = Vector2i(center_chunk.x + dx, center_chunk.y + dy)
			var chunk = generate_street_chunk(chunk_coord.x, chunk_coord.y)
			
			for point_data in chunk.street_points:
				result.append(point_data.position)
	
	return result

func assign_street_points_to_districts(districts: Array, street_points: Array) -> Array:
	district_point_assignments.clear()
	point_district_assignments.clear()
	
	for punto in street_points:
		var punto_hash = get_point_hash(punto)
		
		for distrito in districts:
			var distrito_hash = get_district_hash(distrito.site)
			
			if GeometryUtils.point_in_polygon(punto, distrito.vertices):
				if not district_point_assignments.has(distrito_hash):
					district_point_assignments[distrito_hash] = []
				district_point_assignments[distrito_hash].append(punto)
				point_district_assignments[punto_hash] = distrito_hash
				break
	
	return [district_point_assignments, point_district_assignments]

func get_points_for_district(distrito_hash: String) -> Array[Vector2]:
	return district_point_assignments.get(distrito_hash, [])

func clear_district_assignments():
	district_point_assignments.clear()
	point_district_assignments.clear()

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

func generate_street_chunk(cx: int, cy: int) -> Dictionary:
	var key = "%d,%d" % [cx, cy]
	if street_chunks.has(key):
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
	return chunk

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

func get_point_hash(point: Vector2) -> String:
	var precision = 5.0
	var x_int = int(round(point.x / precision)) * precision
	var y_int = int(round(point.y / precision)) * precision
	return "point_%d_%d" % [x_int, y_int]

func get_district_hash(avenue_point: Vector2) -> String:
	var precision = 10.0
	var x_int = int(round(avenue_point.x / precision)) * precision
	var y_int = int(round(avenue_point.y / precision)) * precision
	return "district_%d_%d" % [x_int, y_int]

func clear_all():
	avenue_chunks.clear()
	street_chunks.clear()
	clear_district_assignments()

func get_debug_info() -> Dictionary:
	var avenue_point_count = 0
	var street_point_count = 0
	var assigned_points = 0
	
	for chunk in avenue_chunks.values():
		avenue_point_count += chunk.avenue_points.size()
	
	for chunk in street_chunks.values():
		street_point_count += chunk.street_points.size()
	
	for points in district_point_assignments.values():
		assigned_points += points.size()
	
	return {
		"avenue_chunks_loaded": avenue_chunks.size(),
		"street_chunks_loaded": street_chunks.size(),
		"total_avenue_points": avenue_point_count,
		"total_street_points": street_point_count,
		"districts_with_assignments": district_point_assignments.size(),
		"total_assigned_points": assigned_points
	}
