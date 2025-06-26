# ChunkManager.gd - Optimizado con estabilidad geométrica
class_name ChunkManager

var chunks = {}
var stable_geometry = {} # Cache de geometría estable
@export var stability_threshold: float = 0.5 # Threshold para considerar cambios mínimos

func get_chunk_coord(world_x: float, world_y: float, chunk_size: int) -> Vector2i:
	return Vector2i(floor(world_x / chunk_size), floor(world_y / chunk_size))

func generate_chunk(cx: int, cy: int, seed_str: String, density: float, chunk_size: int) -> Dictionary:
	var key = "%d,%d" % [cx, cy]
	if chunks.has(key): return chunks[key]
	
	var points = []
	var start = Vector2(cx * chunk_size, cy * chunk_size)
	var step = chunk_size / 2
	
	for y in range(start.y, start.y + chunk_size, step):
		for x in range(start.x, start.x + chunk_size, step):
			var h = hash_coords(x, y, seed_str)
			if h.v < density:
				points.append({
					"position": Vector2(x + h.fx, y + h.fy),
					"hash": h.v, "id": "%d,%d" % [x, y],
					"chunk_x": cx, "chunk_y": cy
				})
	
	var chunk = {"points": points, "chunk_x": cx, "chunk_y": cy}
	chunks[key] = chunk
	return chunk

func get_nearby_chunks(player_chunk: Vector2i, seed_str: String, density: float, chunk_size: int, render_distance: int) -> Array:
	var result = []
	for dx in range(-render_distance, render_distance + 1):
		for dy in range(-render_distance, render_distance + 1):
			if max(abs(dx), abs(dy)) <= render_distance:
				result.append(generate_chunk(player_chunk.x + dx, player_chunk.y + dy, seed_str, density, chunk_size))
	return result

func hash_coords(x: float, y: float, seed_str: String) -> Dictionary:
	var base = "%s,%s,%s" % [x, y, seed_str]
	return {
		"v": float(abs(base.hash()) % 10000) / 10000.0,
		"fx": float(abs((base + "_2").hash()) % 10000) / 10000.0,
		"fy": float(abs((base + "_3").hash()) % 10000) / 10000.0
	}

# NUEVA FUNCIONALIDAD: Verificar si la geometría cambió significativamente
func geometry_needs_update(geometry_id: String, new_points: Array) -> bool:
	if not stable_geometry.has(geometry_id): return true
	
	var old_points = stable_geometry[geometry_id].points
	if old_points.size() != new_points.size(): return true
	
	# Calcular centro de masa y comparar desplazamiento
	var old_center = get_center_of_mass(old_points)
	var new_center = get_center_of_mass(new_points)
	var displacement = old_center.distance_to(new_center)
	
	return displacement > stability_threshold

func get_center_of_mass(points: Array) -> Vector2:
	if points.is_empty(): return Vector2.ZERO
	var center = Vector2.ZERO
	for point in points:
		var pos = point.position if point.has("position") else point
		center += pos
	return center / points.size()

# Cache de geometría estable
func cache_stable_geometry(geometry_id: String, points: Array, geometry_data: Dictionary):
	stable_geometry[geometry_id] = {
		"points": points.duplicate(),
		"geometry": geometry_data.duplicate(),
		"timestamp": Time.get_ticks_msec()
	}

func get_stable_geometry(geometry_id: String) -> Dictionary:
	return stable_geometry.get(geometry_id, {})

func clear():
	chunks.clear()
	stable_geometry.clear()
