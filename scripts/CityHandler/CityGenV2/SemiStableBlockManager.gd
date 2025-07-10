class_name SemiStableBlockManager

var aux_blocks: Dictionary = {}
var cached_meshes: Dictionary = {}

@export var hash_precision: float = 5.0
@export var max_aux_cache_size: int = 1000

signal block_cached(block_hash: String)
signal cache_cleared()
signal cache_limit_reached(removed_count: int)

func get_block_hash(street_point: Vector2) -> String:
	var x_int = int(round(street_point.x / hash_precision)) * hash_precision
	var y_int = int(round(street_point.y / hash_precision)) * hash_precision
	return "block_%d_%d" % [x_int, y_int]

func save_semi_stable_block(hash: String, block_data: Dictionary, mesh_refs: Array = []) -> bool:
	if aux_blocks.size() >= max_aux_cache_size and not aux_blocks.has(hash):
		_cleanup_old_blocks()
	
	if not _validate_block_data(block_data):
		push_error("Datos de manzana inválidos para hash: " + hash)
		return false
	
	var cache_data = block_data.duplicate(true)
	cache_data["creation_time"] = Time.get_ticks_msec()
	cache_data["last_access_time"] = Time.get_ticks_msec()
	
	aux_blocks[hash] = cache_data
	
	if mesh_refs.size() > 0:
		cached_meshes[hash] = mesh_refs
	
	block_cached.emit(hash)
	return true

func load_semi_stable_block(hash: String) -> Dictionary:
	if aux_blocks.has(hash):
		aux_blocks[hash]["last_access_time"] = Time.get_ticks_msec()
		return aux_blocks[hash].duplicate(true)
	
	return {}

func has_semi_stable_block(hash: String) -> bool:
	return aux_blocks.has(hash)

func has_cached_meshes(hash: String) -> bool:
	return cached_meshes.has(hash)

func get_cached_meshes(hash: String) -> Array:
	return cached_meshes.get(hash, [])

func set_block_visibility(hash: String, visible: bool) -> bool:
	if not cached_meshes.has(hash):
		return false
	
	for mesh in cached_meshes[hash]:
		if is_instance_valid(mesh):
			mesh.visible = visible
	
	if aux_blocks.has(hash):
		aux_blocks[hash]["is_currently_visible"] = visible
	
	return true

func clear_aux_cache() -> void:
	var count = aux_blocks.size()
	
	for hash in cached_meshes:
		for mesh in cached_meshes[hash]:
			if is_instance_valid(mesh):
				mesh.queue_free()
	
	aux_blocks.clear()
	cached_meshes.clear()
	cache_cleared.emit()

func cleanup_invalid_meshes():
	var to_remove = []
	
	for hash in cached_meshes:
		var valid_meshes = []
		for mesh in cached_meshes[hash]:
			if is_instance_valid(mesh):
				valid_meshes.append(mesh)
		
		if valid_meshes.size() == 0:
			to_remove.append(hash)
			if aux_blocks.has(hash):
				aux_blocks.erase(hash)
		else:
			cached_meshes[hash] = valid_meshes
	
	for hash in to_remove:
		cached_meshes.erase(hash)

func get_memory_usage() -> Dictionary:
	var total_size = aux_blocks.size()
	var stable_count = 0
	var with_mesh_count = 0
	var total_cached_meshes = 0
	
	for block_data in aux_blocks.values():
		if block_data.get("is_stable", false):
			stable_count += 1
	
	for mesh_array in cached_meshes.values():
		with_mesh_count += 1
		total_cached_meshes += mesh_array.size()
	
	return {
		"total_aux_blocks": total_size,
		"stable_blocks": stable_count,
		"unstable_blocks": total_size - stable_count,
		"blocks_with_mesh": with_mesh_count,
		"total_cached_meshes": total_cached_meshes,
		"cache_usage_percent": (float(total_size) / max_aux_cache_size) * 100.0,
		"memory_estimate_mb": (total_size * 3 + total_cached_meshes * 1) / 1024.0
	}

func _validate_block_data(data: Dictionary) -> bool:
	var required_keys = ["point", "polygon"]
	for key in required_keys:
		if not data.has(key):
			return false
	
	if not (data.point is Vector2):
		return false
	
	if data.polygon.size() < 3:
		return false
	
	return true

func _cleanup_old_blocks() -> void:
	if aux_blocks.size() < max_aux_cache_size:
		return
	
	var current_time = Time.get_ticks_msec()
	var blocks_with_time = []
	
	for hash in aux_blocks:
		var block_data = aux_blocks[hash]
		var last_access = block_data.get("last_access_time", 0)
		var is_stable = block_data.get("is_stable", false)
		
		blocks_with_time.append({
			"hash": hash,
			"last_access": last_access,
			"is_stable": is_stable
		})
	
	blocks_with_time.sort_custom(func(a, b):
		if a.is_stable and not b.is_stable:
			return false
		if not a.is_stable and b.is_stable:
			return true
		return a.last_access < b.last_access
	)
	
	var to_remove_count = aux_blocks.size() - max_aux_cache_size + 100
	var removed = 0
	
	for i in range(min(to_remove_count, blocks_with_time.size())):
		var block_info = blocks_with_time[i]
		if not block_info.is_stable:
			var hash = block_info.hash
			
			if cached_meshes.has(hash):
				for mesh in cached_meshes[hash]:
					if is_instance_valid(mesh):
						mesh.queue_free()
				cached_meshes.erase(hash)
			
			if aux_blocks.has(hash):
				aux_blocks.erase(hash)
				removed += 1
	
	cache_limit_reached.emit(removed)

func get_debug_info() -> Dictionary:
	return get_memory_usage()
