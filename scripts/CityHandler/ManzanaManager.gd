class_name ManzanaManager

# Simple registry of stable manzanas
var manzanas_estables: Dictionary = {}
# Structure: "punto_hash": {"es_estable": bool, "malla_generada": bool, "mesh_instance": MeshInstance3D}

# System references
var chunk_manager: SpatialChunkManager
var containers: Dictionary
var mesh_generation_distance: float
var block_padding: float
var lot_size: int

# === INITIALIZATION ===

func initialize(p_chunk_manager: SpatialChunkManager, p_containers: Dictionary, p_mesh_distance: float, p_block_padding: float, p_lot_size: int):
	chunk_manager = p_chunk_manager
	containers = p_containers
	mesh_generation_distance = p_mesh_distance
	block_padding = p_block_padding
	lot_size = p_lot_size

# === MAIN GENERATION LOGIC ===

func generate_manzana_if_stable(punto: Vector2, manzana_polygon: Array) -> bool:
	var punto_hash = get_point_hash(punto)
	
	# 1. Already generated and stable?
	if is_manzana_already_generated(punto_hash):
		return false  # Nothing to do
	
	# 2. Is the point stable?
	if not is_point_stable(punto):
		return false  # Don't generate unstable manzanas
	
	# 3. Generate mesh and mark as stable + generated
	return create_and_register_manzana(punto, punto_hash, manzana_polygon)

func is_manzana_already_generated(punto_hash: String) -> bool:
	if not manzanas_estables.has(punto_hash):
		return false
	
	var manzana_data = manzanas_estables[punto_hash]
	return manzana_data.get("es_estable", false) and manzana_data.get("malla_generada", false)

func is_point_stable(punto: Vector2) -> bool:
	return StabilityChecker.is_street_point_stable(punto, chunk_manager)

func create_and_register_manzana(punto: Vector2, punto_hash: String, manzana_polygon: Array) -> bool:
	var mesh_instances = create_manzana_mesh(punto, manzana_polygon)
	if mesh_instances.is_empty():
		return false
	
	add_meshes_to_scene(mesh_instances)
	register_manzana_as_stable_and_generated(punto_hash, mesh_instances)
	
	return true

# === MESH CREATION ===

func create_manzana_mesh(punto: Vector2, manzana_polygon: Array) -> Array:
	if manzana_polygon.size() < 3:
		return []
	
	var padded_polygon = create_padded_polygon(manzana_polygon)
	if padded_polygon.size() < 3:
		return []
	
	var lots = subdivide_polygon_into_lots(padded_polygon)
	if lots.is_empty():
		return []
	
	return create_buildings_from_lots(lots, punto)

func create_padded_polygon(manzana_polygon: Array) -> Array:
	return GeometryUtils.create_padded_polygon(manzana_polygon, block_padding)

func subdivide_polygon_into_lots(polygon: Array) -> Array:
	# Primero simplificar el polígono antes de subdividir
	var simplified_polygon = simplify_polygon(polygon)
	return PolygonSubdivider.subdivide_polygon(simplified_polygon, lot_size)

func simplify_polygon(polygon: Array) -> Array:
	if polygon.size() < 3:
		return polygon
	
	var current_polygon = polygon.duplicate()
	var max_iterations = 10  # Prevenir loops infinitos
	var iteration = 0
	
	while iteration < max_iterations:
		var simplified = simplify_polygon_iteration(current_polygon)
		
		# Si no cambió nada, converged
		if simplified.size() == current_polygon.size():
			break
		
		current_polygon = simplified
		iteration += 1
		
		# Asegurar que siempre tengamos al menos un triángulo
		if current_polygon.size() < 3:
			break
	
	return current_polygon

func simplify_polygon_iteration(polygon: Array) -> Array:
	if polygon.size() < 4:  # Un triángulo ya es lo más simple posible
		return polygon
	
	# Calcular promedio de longitudes de aristas
	var average_edge_length = calculate_average_edge_length(polygon)
	var merge_threshold = average_edge_length / 3.0
	
	# Encontrar pares de vértices que están muy cerca
	var vertices_to_merge = find_close_vertex_pairs(polygon, merge_threshold)
	
	if vertices_to_merge.is_empty():
		return polygon  # No hay nada que simplificar
	
	# Fusionar vértices y reconstruir polígono
	return merge_vertices_and_reconstruct(polygon, vertices_to_merge)

func calculate_average_edge_length(polygon: Array) -> float:
	if polygon.size() < 2:
		return 0.0
	
	var total_length = 0.0
	var edge_count = polygon.size()
	
	for i in range(polygon.size()):
		var current_vertex = polygon[i] as Vector2
		var next_vertex = polygon[(i + 1) % polygon.size()] as Vector2
		total_length += current_vertex.distance_to(next_vertex)
	
	return total_length / edge_count

func find_close_vertex_pairs(polygon: Array, threshold: float) -> Array:
	var close_pairs = []
	
	for i in range(polygon.size()):
		var current_vertex = polygon[i] as Vector2
		var next_index = (i + 1) % polygon.size()
		var next_vertex = polygon[next_index] as Vector2
		
		var distance = current_vertex.distance_to(next_vertex)
		
		if distance < threshold:
			close_pairs.append({
				"index1": i,
				"index2": next_index,
				"distance": distance
			})
	
	# Ordenar por distancia (más cerca primero) para fusionar los más obvios primero
	close_pairs.sort_custom(func(a, b): return a.distance < b.distance)
	
	return close_pairs

func merge_vertices_and_reconstruct(polygon: Array, vertices_to_merge: Array) -> Array:
	if vertices_to_merge.is_empty():
		return polygon
	
	# Procesar solo el primer par para evitar conflictos
	var pair = vertices_to_merge[0]
	var index1 = pair.index1
	var index2 = pair.index2
	
	var vertex1 = polygon[index1] as Vector2
	var vertex2 = polygon[index2] as Vector2
	
	# Calcular punto promedio
	var merged_vertex = (vertex1 + vertex2) / 2.0
	
	# Crear nuevo polígono sin uno de los vértices
	var new_polygon = []
	
	for i in range(polygon.size()):
		if i == index1:
			# Reemplazar vertex1 con el punto fusionado
			new_polygon.append(merged_vertex)
		elif i == index2:
			# Saltar vertex2 (ya fusionado)
			continue
		else:
			new_polygon.append(polygon[i])
	
	return new_polygon

func create_buildings_from_lots(lots: Array, punto: Vector2) -> Array:
	if lots.is_empty():
		return []

	var created_buildings = []

	for lot in lots:
		var lot_polygon = lot.get("polygon", [])

		if lot_polygon.size() <= 3:
			continue  # Skip invalid lots

		var building = BuildingMeshGenerator.create_building(lot_polygon, punto)
		
		if building:
			created_buildings.append(building)
	
	return created_buildings

func add_mesh_to_scene(mesh_instance: MeshInstance3D):
	if containers.has("buildings"):
		containers.buildings.add_child(mesh_instance)
		
func add_meshes_to_scene(mesh_instances: Array):
	if containers.has("buildings"):
		for mesh_instance in mesh_instances:
			containers.buildings.add_child(mesh_instance)

func register_manzana_as_stable_and_generated(punto_hash: String, mesh_instances: Array):
	manzanas_estables[punto_hash] = {
		"es_estable": true,
		"malla_generada": true,
		"mesh_instance": mesh_instances
	}

# === UTILITY FUNCTIONS ===

func get_point_hash(punto: Vector2) -> String:
	return StabilityChecker.get_point_hash(punto)

func has_manzana(punto_hash: String) -> bool:
	return manzanas_estables.has(punto_hash)

func is_manzana_stable(punto_hash: String) -> bool:
	if not manzanas_estables.has(punto_hash):
		return false
	return manzanas_estables[punto_hash].get("es_estable", false)

func is_manzana_mesh_generated(punto_hash: String) -> bool:
	if not manzanas_estables.has(punto_hash):
		return false
	return manzanas_estables[punto_hash].get("malla_generada", false)

func get_manzana_mesh(punto_hash: String) -> MeshInstance3D:
	if not manzanas_estables.has(punto_hash):
		return null
	return manzanas_estables[punto_hash].get("mesh_instance", null)

# === CLEANUP & MAINTENANCE ===

func cleanup_invalid_mesh_references():
	var invalid_hashes = []
	
	for punto_hash in manzanas_estables:
		var manzana_data = manzanas_estables[punto_hash]
		var mesh_instance = manzana_data.get("mesh_instance", null)
		
		if mesh_instance and not is_instance_valid(mesh_instance):
			invalid_hashes.append(punto_hash)
	
	for punto_hash in invalid_hashes:
		remove_manzana(punto_hash)

func remove_manzana(punto_hash: String):
	if not manzanas_estables.has(punto_hash):
		return
	
	var manzana_data = manzanas_estables[punto_hash]
	var mesh_instance = manzana_data.get("mesh_instance", null)
	
	if mesh_instance and is_instance_valid(mesh_instance):
		mesh_instance.queue_free()
	
	manzanas_estables.erase(punto_hash)

func clear_all_manzanas():
	for manzana_data in manzanas_estables.values():
		var mesh_instance = manzana_data.get("mesh_instance", null)
		if mesh_instance and is_instance_valid(mesh_instance):
			mesh_instance.queue_free()
	
	manzanas_estables.clear()

# === DEBUG & STATS ===

func get_stats() -> Dictionary:
	var stable_count = 0
	var generated_count = 0
	var total_meshes = 0
	
	for manzana_data in manzanas_estables.values():
		if manzana_data.get("es_estable", false):
			stable_count += 1
		
		if manzana_data.get("malla_generada", false):
			generated_count += 1
			total_meshes += 1
	
	return {
		"stable_count": stable_count,
		"generated_count": generated_count,
		"total_meshes": total_meshes,
		"total_registered": manzanas_estables.size()
	}

func get_debug_info() -> Array:
	var debug_info = []
	
	for punto_hash in manzanas_estables:
		var manzana_data = manzanas_estables[punto_hash]
		
		# Try to reconstruct polygon for debug (expensive but useful)
		var polygon = reconstruct_polygon_for_debug(punto_hash)
		
		debug_info.append({
			"punto_hash": punto_hash,
			"es_estable": manzana_data.get("es_estable", false),
			"malla_generada": manzana_data.get("malla_generada", false),
			"polygon": polygon
		})
	
	return debug_info

func reconstruct_polygon_for_debug(punto_hash: String) -> PackedVector2Array:
	# This is expensive and only for debug purposes
	# Try to reconstruct the point coordinates from hash
	var parts = punto_hash.split("_")
	if parts.size() < 3:
		return PackedVector2Array()
	
	# This is a simplified reconstruction - in real case you might want to store polygons
	var x = float(parts[1])
	var y = float(parts[2])
	
	# Return a simple square around the point for debug visualization
	var size = 20.0
	return PackedVector2Array([
		Vector2(x - size, y - size),
		Vector2(x + size, y - size),
		Vector2(x + size, y + size),
		Vector2(x - size, y + size)
	])

func print_stats():
	var stats = get_stats()
	print("📊 ManzanaManager Stats:")
	print("   Stable: %d" % stats.stable_count)
	print("   Generated: %d" % stats.generated_count)
	print("   Total meshes: %d" % stats.total_meshes)
	print("   Total registered: %d" % stats.total_registered)
