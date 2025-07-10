class_name StabilityChecker

static var avenue_stability_cache: Dictionary = {}
static var street_stability_cache: Dictionary = {}
static var district_stability_cache: Dictionary = {}
static var cache_expiry_time: int = 30000

static func is_avenue_point_stable(punto: Vector2, chunk_manager: SpatialChunkManager) -> bool:
	var chunk_coord = chunk_manager.get_avenue_chunk_coord(punto.x, punto.y)
	var cache_key = "ave_%d_%d" % [chunk_coord.x, chunk_coord.y]
	
	if _is_cache_valid(avenue_stability_cache, cache_key):
		return avenue_stability_cache[cache_key]["result"]
	
	var is_stable = true
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			
			var neighbor_coord = Vector2i(chunk_coord.x + dx, chunk_coord.y + dy)
			
			# VERIFICAR: ¿El chunk vecino existe en el área cargada?
			var neighbor_key = "%d,%d" % [neighbor_coord.x, neighbor_coord.y]
			if not chunk_manager.avenue_chunks.has(neighbor_key):
				# Si el chunk no está cargado, no es estable
				is_stable = false
				break
			
			var neighbor_chunk = chunk_manager.avenue_chunks[neighbor_key]
			
			# VERIFICAR: ¿El chunk vecino tiene puntos?
			if neighbor_chunk.avenue_points.size() == 0:
				is_stable = false
				break
		
		if not is_stable:
			break
	
	_cache_result(avenue_stability_cache, cache_key, is_stable)
	return is_stable

static func is_street_point_stable(punto: Vector2, chunk_manager: SpatialChunkManager) -> bool:
	var chunk_coord = chunk_manager.get_street_chunk_coord(punto.x, punto.y)
	var cache_key = "str_%d_%d" % [chunk_coord.x, chunk_coord.y]
	
	return false
	
	if _is_cache_valid(street_stability_cache, cache_key):
		return street_stability_cache[cache_key]["result"]
	
	# Un punto de calle es estable SOLO SI está completamente rodeado por 8 chunks con puntos
	# Y todos esos chunks están dentro del área de renderizado actual
	var is_stable = true
	
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			
			var neighbor_coord = Vector2i(chunk_coord.x + dx, chunk_coord.y + dy)
			
			# VERIFICAR: ¿El chunk vecino existe en el área cargada?
			var neighbor_key = "%d,%d" % [neighbor_coord.x, neighbor_coord.y]
			if not chunk_manager.street_chunks.has(neighbor_key):
				# Si el chunk no está cargado, no es estable
				is_stable = false
				break
			
			var neighbor_chunk = chunk_manager.street_chunks[neighbor_key]
			
			# VERIFICAR: ¿El chunk vecino tiene puntos?
			if neighbor_chunk.street_points.size() == 0:
				is_stable = false
				break
		
		if not is_stable:
			break
	
	_cache_result(street_stability_cache, cache_key, is_stable)
	return is_stable

static func is_district_stable(distrito_hash: String, avenue_point: Vector2, chunk_manager: SpatialChunkManager) -> bool:
	if _is_cache_valid(district_stability_cache, distrito_hash):
		return district_stability_cache[distrito_hash]["result"]
	
	var is_stable = is_avenue_point_stable(avenue_point, chunk_manager)
	_cache_result(district_stability_cache, distrito_hash, is_stable)
	return is_stable

static func get_stability_map_for_points(puntos: Array, chunk_manager: SpatialChunkManager) -> Dictionary:
	var resultado = {}
	
	for punto in puntos:
		var punto_hash = get_point_hash(punto)
		resultado[punto_hash] = is_street_point_stable(punto, chunk_manager)
	
	return resultado

static func get_point_hash(point: Vector2) -> String:
	var precision = 5.0
	var x_int = int(round(point.x / precision)) * precision
	var y_int = int(round(point.y / precision)) * precision
	return "point_%d_%d" % [x_int, y_int]

static func clear_stability_caches():
	avenue_stability_cache.clear()
	street_stability_cache.clear()
	district_stability_cache.clear()

static func _is_cache_valid(cache: Dictionary, cache_key: String) -> bool:
	if not cache.has(cache_key):
		return false
	
	var entry = cache[cache_key]
	var current_time = Time.get_ticks_msec()
	var age = current_time - entry.timestamp
	
	return age <= cache_expiry_time

static func _cache_result(cache: Dictionary, cache_key: String, result: bool):
	cache[cache_key] = {
		"result": result,
		"timestamp": Time.get_ticks_msec()
	}

# FUNCIONES DE DEBUG PARA VERIFICAR ESTABILIDAD
static func debug_chunk_stability(punto: Vector2, chunk_manager: SpatialChunkManager) -> Dictionary:
	var chunk_coord = chunk_manager.get_street_chunk_coord(punto.x, punto.y)
	var neighbors_info = []
	var loaded_neighbors = 0
	var neighbors_with_points = 0
	
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var neighbor_coord = Vector2i(chunk_coord.x + dx, chunk_coord.y + dy)
			var is_center = (dx == 0 and dy == 0)
			
			var neighbor_key = "%d,%d" % [neighbor_coord.x, neighbor_coord.y]
			var is_loaded = chunk_manager.street_chunks.has(neighbor_key)
			var has_points = false
			var point_count = 0
			
			if is_loaded:
				var neighbor_chunk = chunk_manager.street_chunks[neighbor_key]
				has_points = neighbor_chunk.street_points.size() > 0
				point_count = neighbor_chunk.street_points.size()
				
				if not is_center:
					loaded_neighbors += 1
					if has_points:
						neighbors_with_points += 1
			
			neighbors_info.append({
				"coord": neighbor_coord,
				"is_center": is_center,
				"is_loaded": is_loaded,
				"has_points": has_points,
				"point_count": point_count
			})
	
	var is_stable = loaded_neighbors == 8 and neighbors_with_points == 8
	
	return {
		"center_chunk": chunk_coord,
		"is_stable": is_stable,
		"loaded_neighbors": loaded_neighbors,
		"neighbors_with_points": neighbors_with_points,
		"neighbors_info": neighbors_info,
		"stability_requirements": "Necesita 8 vecinos cargados con puntos"
	}
