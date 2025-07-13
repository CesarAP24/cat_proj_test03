class_name StabilityChecker

# Simple cache for stability checks
static var stability_cache: Dictionary = {}
static var cache_expiry_time: int = 30000  # 30 seconds

# === MAIN STABILITY CHECKS ===

static func is_street_point_stable(punto: Vector2, chunk_manager: SpatialChunkManager) -> bool:
	var chunk_coord = chunk_manager.get_street_chunk_coord(punto.x, punto.y)
	var cache_key = "street_%d_%d" % [chunk_coord.x, chunk_coord.y]
	
	if is_cache_valid(cache_key):
		return stability_cache[cache_key]["result"]
	
	var is_stable = check_street_point_stability(punto, chunk_manager)
	cache_stability_result(cache_key, is_stable)
	
	return is_stable

static func is_avenue_point_stable(punto: Vector2, chunk_manager: SpatialChunkManager) -> bool:
	var chunk_coord = chunk_manager.get_avenue_chunk_coord(punto.x, punto.y)
	var cache_key = "avenue_%d_%d" % [chunk_coord.x, chunk_coord.y]
	
	if is_cache_valid(cache_key):
		return stability_cache[cache_key]["result"]
	
	var is_stable = check_avenue_point_stability(punto, chunk_manager)
	cache_stability_result(cache_key, is_stable)
	
	return is_stable

# === STABILITY LOGIC ===

static func check_street_point_stability(punto: Vector2, chunk_manager: SpatialChunkManager) -> bool:
	var chunk_coord = chunk_manager.get_street_chunk_coord(punto.x, punto.y)
	
	# A street point is stable if ALL 8 neighboring chunks are loaded and have points
	return are_all_neighbors_loaded_and_populated(chunk_coord, chunk_manager, "street")

static func check_avenue_point_stability(punto: Vector2, chunk_manager: SpatialChunkManager) -> bool:
	var chunk_coord = chunk_manager.get_avenue_chunk_coord(punto.x, punto.y)
	
	# An avenue point is stable if ALL 8 neighboring chunks are loaded and have points
	return are_all_neighbors_loaded_and_populated(chunk_coord, chunk_manager, "avenue")

static func are_all_neighbors_loaded_and_populated(chunk_coord: Vector2i, chunk_manager: SpatialChunkManager, chunk_type: String) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue  # Skip center chunk
			
			var neighbor_coord = Vector2i(chunk_coord.x + dx, chunk_coord.y + dy)
			
			if not is_neighbor_chunk_valid(neighbor_coord, chunk_manager, chunk_type):
				return false
	
	return true

static func is_neighbor_chunk_valid(chunk_coord: Vector2i, chunk_manager: SpatialChunkManager, chunk_type: String) -> bool:
	var chunk_key = "%d,%d" % [chunk_coord.x, chunk_coord.y]
	
	match chunk_type:
		"street":
			if not chunk_manager.street_chunks.has(chunk_key):
				return false
			var chunk = chunk_manager.street_chunks[chunk_key]
			return chunk.street_points.size() > 0
		
		"avenue":
			if not chunk_manager.avenue_chunks.has(chunk_key):
				return false
			var chunk = chunk_manager.avenue_chunks[chunk_key]
			return chunk.avenue_points.size() > 0
		
		_:
			return false

# === UTILITY FUNCTIONS ===

static func get_point_hash(point: Vector2) -> String:
	var precision = 5.0
	var x_int = int(round(point.x / precision)) * precision
	var y_int = int(round(point.y / precision)) * precision
	return "point_%d_%d" % [x_int, y_int]

static func get_district_hash(avenue_point: Vector2) -> String:
	var precision = 10.0
	var x_int = int(round(avenue_point.x / precision)) * precision
	var y_int = int(round(avenue_point.y / precision)) * precision
	return "district_%d_%d" % [x_int, y_int]

# === CACHE MANAGEMENT ===

static func is_cache_valid(cache_key: String) -> bool:
	if not stability_cache.has(cache_key):
		return false
	
	var entry = stability_cache[cache_key]
	var current_time = Time.get_ticks_msec()
	var age = current_time - entry.timestamp
	
	return age <= cache_expiry_time

static func cache_stability_result(cache_key: String, result: bool):
	stability_cache[cache_key] = {
		"result": result,
		"timestamp": Time.get_ticks_msec()
	}

static func clear_stability_cache():
	stability_cache.clear()

static func cleanup_expired_cache():
	var current_time = Time.get_ticks_msec()
	var expired_keys = []
	
	for cache_key in stability_cache:
		var entry = stability_cache[cache_key]
		var age = current_time - entry.timestamp
		
		if age > cache_expiry_time:
			expired_keys.append(cache_key)
	
	for key in expired_keys:
		stability_cache.erase(key)

# === DEBUG FUNCTIONS ===

static func debug_point_stability(punto: Vector2, chunk_manager: SpatialChunkManager, chunk_type: String = "street") -> Dictionary:
	var chunk_coord: Vector2i
	
	match chunk_type:
		"street":
			chunk_coord = chunk_manager.get_street_chunk_coord(punto.x, punto.y)
		"avenue":
			chunk_coord = chunk_manager.get_avenue_chunk_coord(punto.x, punto.y)
		_:
			chunk_coord = chunk_manager.get_street_chunk_coord(punto.x, punto.y)
	
	var neighbors_info = []
	var loaded_neighbors = 0
	var neighbors_with_points = 0
	
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var neighbor_coord = Vector2i(chunk_coord.x + dx, chunk_coord.y + dy)
			var is_center = (dx == 0 and dy == 0)
			
			var neighbor_info = get_neighbor_debug_info(neighbor_coord, chunk_manager, chunk_type)
			neighbors_info.append(neighbor_info)
			
			if not is_center:
				if neighbor_info.is_loaded:
					loaded_neighbors += 1
				if neighbor_info.has_points:
					neighbors_with_points += 1
	
	var is_stable = loaded_neighbors == 8 and neighbors_with_points == 8
	
	return {
		"center_chunk": chunk_coord,
		"chunk_type": chunk_type,
		"is_stable": is_stable,
		"loaded_neighbors": loaded_neighbors,
		"neighbors_with_points": neighbors_with_points,
		"neighbors_info": neighbors_info,
		"stability_requirements": "Needs 8 loaded neighbors with points"
	}

static func get_neighbor_debug_info(chunk_coord: Vector2i, chunk_manager: SpatialChunkManager, chunk_type: String) -> Dictionary:
	var chunk_key = "%d,%d" % [chunk_coord.x, chunk_coord.y]
	var is_loaded = false
	var has_points = false
	var point_count = 0
	
	match chunk_type:
		"street":
			is_loaded = chunk_manager.street_chunks.has(chunk_key)
			if is_loaded:
				var chunk = chunk_manager.street_chunks[chunk_key]
				point_count = chunk.street_points.size()
				has_points = point_count > 0
		
		"avenue":
			is_loaded = chunk_manager.avenue_chunks.has(chunk_key)
			if is_loaded:
				var chunk = chunk_manager.avenue_chunks[chunk_key]
				point_count = chunk.avenue_points.size()
				has_points = point_count > 0
	
	return {
		"coord": chunk_coord,
		"is_loaded": is_loaded,
		"has_points": has_points,
		"point_count": point_count
	}

# === TESTING FUNCTIONS ===

static func force_point_stable_for_testing(punto: Vector2) -> bool:
	# Temporary function for testing - always returns true
	# Remove this in production
	return true

static func get_cache_stats() -> Dictionary:
	var current_time = Time.get_ticks_msec()
	var valid_entries = 0
	var expired_entries = 0
	
	for entry in stability_cache.values():
		var age = current_time - entry.timestamp
		if age <= cache_expiry_time:
			valid_entries += 1
		else:
			expired_entries += 1
	
	return {
		"total_cached": stability_cache.size(),
		"valid_entries": valid_entries,
		"expired_entries": expired_entries,
		"cache_hit_potential": float(valid_entries) / max(1, stability_cache.size())
	}
