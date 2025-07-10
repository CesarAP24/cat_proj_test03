class_name GeometryStabilityChecker

static var stability_cache: Dictionary = {}
static var cache_expiry_time: int = 30000

static func is_avenue_chunk_stable(
	chunk_coord: Vector2i, 
	chunk_manager: DoubleLayerChunkManager
) -> bool:
	var cache_key = "avenue_%d_%d" % [chunk_coord.x, chunk_coord.y]
	
	if _is_cache_valid(cache_key):
		return stability_cache[cache_key]["result"]
	
	var is_stable = true
	
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			
			var neighbor_coord = Vector2i(chunk_coord.x + dx, chunk_coord.y + dy)
			var neighbor_chunk = chunk_manager.generate_avenue_chunk(neighbor_coord.x, neighbor_coord.y)
			
			if neighbor_chunk.avenue_points.size() == 0:
				is_stable = false
				break
		
		if not is_stable:
			break
	
	_cache_result(cache_key, is_stable)
	return is_stable

static func is_street_chunk_stable(
	chunk_coord: Vector2i,
	chunk_manager: DoubleLayerChunkManager  
) -> bool:
	var cache_key = "street_%d_%d" % [chunk_coord.x, chunk_coord.y]
	
	if _is_cache_valid(cache_key):
		return stability_cache[cache_key]["result"]
	
	var is_stable = true
	
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			
			var neighbor_coord = Vector2i(chunk_coord.x + dx, chunk_coord.y + dy)
			chunk_manager.generate_street_chunk_with_assignment(neighbor_coord.x, neighbor_coord.y)
	
	_cache_result(cache_key, is_stable)
	return is_stable

static func is_district_geometrically_stable(
	avenue_point: Vector2,
	chunk_manager: DoubleLayerChunkManager
) -> bool:
	var chunk_coord = chunk_manager.get_avenue_chunk_coord(avenue_point.x, avenue_point.y)
	return is_avenue_chunk_stable(chunk_coord, chunk_manager)

static func is_block_geometrically_stable(
	street_point: Vector2,
	chunk_manager: DoubleLayerChunkManager,
	parent_district_stable: bool = false
) -> bool:
	var chunk_coord = chunk_manager.get_street_chunk_coord(street_point.x, street_point.y)
	var chunk_stable = is_street_chunk_stable(chunk_coord, chunk_manager)
	return chunk_stable and parent_district_stable

static func clear_stability_cache():
	stability_cache.clear()

static func get_cache_stats() -> Dictionary:
	return {
		"total_entries": stability_cache.size()
	}

static func _is_cache_valid(cache_key: String) -> bool:
	if not stability_cache.has(cache_key):
		return false
	
	var entry = stability_cache[cache_key]
	var current_time = Time.get_ticks_msec()
	var age = current_time - entry.timestamp
	
	return age <= cache_expiry_time

static func _cache_result(cache_key: String, result: bool):
	stability_cache[cache_key] = {
		"result": result,
		"timestamp": Time.get_ticks_msec()
	}
