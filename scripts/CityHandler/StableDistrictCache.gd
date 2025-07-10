class_name StableDistrictCache

var stable_districts: Dictionary = {}
var district_meshes: Dictionary = {}

signal district_became_stable(distrito_hash: String)
signal district_became_fully_stable(distrito_hash: String)

func has_stable_district(distrito_hash: String) -> bool:
	return stable_districts.has(distrito_hash)

func save_stable_district(distrito_hash: String, puntos_calle: Array, distrito_data: Dictionary = {}):
	var district_info = {
		"puntos_calle": puntos_calle.duplicate(),
		"manzanas_estables": {},
		"bounds": distrito_data.get("bounds", Rect2()),
		"creation_time": Time.get_ticks_msec(),
		"last_update": Time.get_ticks_msec()
	}
	
	if not stable_districts.has(distrito_hash):
		stable_districts[distrito_hash] = district_info
		district_meshes[distrito_hash] = {}
		district_became_stable.emit(distrito_hash)
	else:
		stable_districts[distrito_hash].merge(district_info)

func get_stable_district(distrito_hash: String) -> Dictionary:
	return stable_districts.get(distrito_hash, {})

func get_cached_points(distrito_hash: String) -> Array:
	if not stable_districts.has(distrito_hash):
		return []
	
	var manzanas = stable_districts[distrito_hash].get("manzanas_estables", {})
	var puntos = []
	
	for punto_hash in manzanas.keys():
		var punto_data = manzanas[punto_hash]
		if punto_data.has("punto"):
			puntos.append(punto_data["punto"])
	
	return puntos

func show_district_meshes(distrito_hash: String) -> bool:
	if not district_meshes.has(distrito_hash):
		return false
	
	var mesh_count = 0
	for manzana_hash in district_meshes[distrito_hash]:
		var meshes = district_meshes[distrito_hash][manzana_hash]
		for mesh in meshes:
			if is_instance_valid(mesh):
				mesh.visible = true
				mesh_count += 1
	
	return mesh_count > 0

func hide_district_meshes(distrito_hash: String) -> bool:
	if not district_meshes.has(distrito_hash):
		return false
	
	for manzana_hash in district_meshes[distrito_hash]:
		var meshes = district_meshes[distrito_hash][manzana_hash]
		for mesh in meshes:
			if is_instance_valid(mesh):
				mesh.visible = false
	
	return true

func add_stable_block_to_district(distrito_hash: String, punto_hash: String, malla_refs: Array, punto: Vector2 = Vector2.ZERO, polygon: PackedVector2Array = PackedVector2Array()):
	if not stable_districts.has(distrito_hash):
		return false
	
	var manzana_data = {
		"punto": punto,
		"polygon": polygon,
		"creation_time": Time.get_ticks_msec()
	}
	
	stable_districts[distrito_hash]["manzanas_estables"][punto_hash] = manzana_data
	
	if not district_meshes.has(distrito_hash):
		district_meshes[distrito_hash] = {}
	
	district_meshes[distrito_hash][punto_hash] = malla_refs
	
	_check_if_fully_stable(distrito_hash)
	return true

func district_has_point(distrito_hash: String, punto_hash: String) -> bool:
	if not stable_districts.has(distrito_hash):
		return false
	
	var manzanas = stable_districts[distrito_hash].get("manzanas_estables", {})
	return manzanas.has(punto_hash)

func show_point_mesh(distrito_hash: String, punto_hash: String) -> bool:
	if not district_meshes.has(distrito_hash) or not district_meshes[distrito_hash].has(punto_hash):
		return false
	
	var meshes = district_meshes[distrito_hash][punto_hash]
	for mesh in meshes:
		if is_instance_valid(mesh):
			mesh.visible = true
	
	return true

func remove_points_from_district(distrito_hash: String, puntos_a_remover: Array):
	if not stable_districts.has(distrito_hash):
		return
	
	var manzanas = stable_districts[distrito_hash]["manzanas_estables"]
	
	for punto in puntos_a_remover:
		var punto_hash = StabilityChecker.get_point_hash(punto)
		
		if manzanas.has(punto_hash):
			manzanas.erase(punto_hash)
		
		if district_meshes.has(distrito_hash) and district_meshes[distrito_hash].has(punto_hash):
			var meshes = district_meshes[distrito_hash][punto_hash]
			for mesh in meshes:
				if is_instance_valid(mesh):
					mesh.queue_free()
			district_meshes[distrito_hash].erase(punto_hash)

func cleanup_invalid_mesh_references():
	for distrito_hash in district_meshes:
		var manzanas_to_remove = []
		
		for manzana_hash in district_meshes[distrito_hash]:
			var valid_meshes = []
			var meshes = district_meshes[distrito_hash][manzana_hash]
			
			for mesh in meshes:
				if is_instance_valid(mesh):
					valid_meshes.append(mesh)
			
			if valid_meshes.is_empty():
				manzanas_to_remove.append(manzana_hash)
				if stable_districts.has(distrito_hash):
					stable_districts[distrito_hash]["manzanas_estables"].erase(manzana_hash)
			else:
				district_meshes[distrito_hash][manzana_hash] = valid_meshes

		for manzana_hash in manzanas_to_remove:
			district_meshes[distrito_hash].erase(manzana_hash)

func get_cache_stats() -> Dictionary:
	var total_districts = stable_districts.size()
	var total_manzanas = 0
	var total_meshes = 0
	
	for distrito_data in stable_districts.values():
		total_manzanas += distrito_data.get("manzanas_estables", {}).size()
	
	for distrito_meshes in district_meshes.values():
		for meshes in distrito_meshes.values():
			total_meshes += meshes.size()
	
	return {
		"stable_districts": total_districts,
		"total_manzanas": total_manzanas,
		"total_meshes": total_meshes,
		"memory_estimate_mb": (total_districts * 5 + total_manzanas * 2 + total_meshes * 1) / 1024.0
	}

func _check_if_fully_stable(distrito_hash: String):
	if not stable_districts.has(distrito_hash):
		return
	
	var distrito_data = stable_districts[distrito_hash]
	var total_puntos = distrito_data["puntos_calle"].size()
	var manzanas_estables = distrito_data["manzanas_estables"].size()
	
	var stability_ratio = float(manzanas_estables) / max(1, total_puntos)
	
	if stability_ratio >= 0.8:
		district_became_fully_stable.emit(distrito_hash)

func clear_all():
	for distrito_meshes in district_meshes.values():
		for meshes in distrito_meshes.values():
			for mesh in meshes:
				if is_instance_valid(mesh):
					mesh.queue_free()
	
	stable_districts.clear()
	district_meshes.clear()
