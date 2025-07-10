class_name StableDistrictManager

var stable_districts: Dictionary = {}
var cached_meshes: Dictionary = {}

@export var hash_precision: float = 10.0

signal district_became_stable(district_hash: String)
signal district_became_fully_stable(district_hash: String)

func get_district_hash(avenue_point: Vector2) -> String:
	var x_int = int(round(avenue_point.x / hash_precision)) * hash_precision
	var y_int = int(round(avenue_point.y / hash_precision)) * hash_precision
	return "district_%d_%d" % [x_int, y_int]

func save_stable_district(hash: String, district_data: Dictionary, mesh_refs: Array = []) -> void:
	district_data["last_update_time"] = Time.get_ticks_msec()
	
	if not _validate_district_data(district_data):
		push_error("Datos de distrito inválidos para hash: " + hash)
		return
	
	var was_new = not stable_districts.has(hash)
	stable_districts[hash] = district_data.duplicate(true)
	
	if mesh_refs.size() > 0:
		cached_meshes[hash] = mesh_refs
	
	if was_new:
		district_became_stable.emit(hash)

func load_stable_district(hash: String) -> Dictionary:
	return stable_districts.get(hash, {})

func has_stable_district(hash: String) -> bool:
	return stable_districts.has(hash)

func get_cached_meshes(hash: String) -> Array:
	return cached_meshes.get(hash, [])

func has_cached_meshes(hash: String) -> bool:
	return cached_meshes.has(hash)

func set_district_visibility(hash: String, visible: bool) -> bool:
	if not cached_meshes.has(hash):
		return false
	
	for mesh in cached_meshes[hash]:
		if is_instance_valid(mesh):
			mesh.visible = visible
	
	return true

func update_district_street_points(hash: String, new_street_points: Array) -> bool:
	if not stable_districts.has(hash):
		return false
	
	var district = stable_districts[hash]
	var old_points = district.assigned_street_points
	
	if _points_changed_significantly(old_points, new_street_points):
		district.assigned_street_points = new_street_points.duplicate()
		district.stable_blocks.clear()
		district.is_fully_stable = false
		district.last_update_time = Time.get_ticks_msec()
		return true
	
	return false

func add_stable_block_to_district(district_hash: String, block_hash: String, block_data: Dictionary) -> bool:
	if not stable_districts.has(district_hash):
		return false
	
	var district = stable_districts[district_hash]
	district.stable_blocks[block_hash] = block_data.duplicate(true)
	
	_check_if_district_fully_stable(district_hash)
	return true

func get_stable_block_from_district(district_hash: String, block_hash: String) -> Dictionary:
	if not stable_districts.has(district_hash):
		return {}
	
	return stable_districts[district_hash].stable_blocks.get(block_hash, {})

func cleanup_invalid_meshes():
	var to_remove = []
	
	
	for hash in cached_meshes:
		var valid_meshes = []
		for mesh in cached_meshes[hash]:
			if is_instance_valid(mesh):
				valid_meshes.append(mesh)
		
		if valid_meshes.size() == 0:
			to_remove.append(hash)
		else:
			cached_meshes[hash] = valid_meshes
	
	for hash in to_remove:
		cached_meshes.erase(hash)

func get_memory_usage() -> Dictionary:
	var total_blocks = 0
	var total_districts = stable_districts.size()
	var total_cached_meshes = 0
	
	for district in stable_districts.values():
		total_blocks += district.stable_blocks.size()
	
	for mesh_array in cached_meshes.values():
		total_cached_meshes += mesh_array.size()
	
	return {
		"stable_districts": total_districts,
		"total_stable_blocks": total_blocks,
		"cached_mesh_arrays": cached_meshes.size(),
		"total_cached_meshes": total_cached_meshes,
		"memory_estimate_mb": (total_districts * 5 + total_blocks * 2 + total_cached_meshes * 1) / 1024.0
	}

func _validate_district_data(data: Dictionary) -> bool:
	var required_keys = ["polygon", "avenue_point", "assigned_street_points"]
	for key in required_keys:
		if not data.has(key):
			return false
	
	if data.polygon.size() < 3:
		return false
	
	if not (data.avenue_point is Vector2):
		return false
	
	return true

func _points_changed_significantly(old_points: Array, new_points: Array, threshold: float = 5.0) -> bool:
	if old_points.size() != new_points.size():
		return true
	
	var old_center = _get_center_of_mass(old_points)
	var new_center = _get_center_of_mass(new_points)
	
	return old_center.distance_to(new_center) > threshold

func _get_center_of_mass(points: Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	
	var center = Vector2.ZERO
	for point in points:
		center += point
	return center / points.size()

func _check_if_district_fully_stable(district_hash: String) -> void:
	if not stable_districts.has(district_hash):
		return
	
	var district = stable_districts[district_hash]
	
	if district.is_fully_stable:
		return
	
	var street_points = district.assigned_street_points
	var stable_blocks = district.stable_blocks
	
	var stability_ratio = float(stable_blocks.size()) / max(1, street_points.size())
	
	if stability_ratio >= 0.8:
		district.is_fully_stable = true
		district_became_fully_stable.emit(district_hash)

func get_debug_info() -> Dictionary:
	var info = get_memory_usage()
	info["districts_list"] = []
	
	for hash in stable_districts:
		var district = stable_districts[hash]
		info.districts_list.append({
			"hash": hash,
			"avenue_point": district.avenue_point,
			"street_points_count": district.assigned_street_points.size(),
			"stable_blocks_count": district.stable_blocks.size(),
			"is_fully_stable": district.get("is_fully_stable", false),
			"has_cached_meshes": cached_meshes.has(hash)
		})
	
	return info
