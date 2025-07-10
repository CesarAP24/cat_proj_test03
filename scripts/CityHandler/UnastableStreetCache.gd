class_name UnstableStreetCache

var unstable_street_blocks: Dictionary = {}
var max_cache_size: int = 1000

signal cache_cleared()
signal cache_limit_reached(removed_count: int)

func has_cached_block(punto_hash: String) -> bool:
	return unstable_street_blocks.has(punto_hash)

func save_block(punto_hash: String, malla_refs: Array, polygon: PackedVector2Array = PackedVector2Array()) -> bool:
	if unstable_street_blocks.size() >= max_cache_size and not unstable_street_blocks.has(punto_hash):
		cleanup_old_blocks()
	
	if malla_refs.is_empty():
		return false
	
	unstable_street_blocks[punto_hash] = {
		"malla_refs": malla_refs,
		"polygon": polygon,
		"creation_time": Time.get_ticks_msec(),
		"last_access": Time.get_ticks_msec()
	}
	
	return true

func get_block_meshes(punto_hash: String) -> Array:
	if not unstable_street_blocks.has(punto_hash):
		return []
	
	unstable_street_blocks[punto_hash]["last_access"] = Time.get_ticks_msec()
	return unstable_street_blocks[punto_hash]["malla_refs"]

func show_block(punto_hash: String) -> bool:
	if not unstable_street_blocks.has(punto_hash):
		return false
	
	var block_data = unstable_street_blocks[punto_hash]
	block_data["last_access"] = Time.get_ticks_msec()
	
	for mesh in block_data["malla_refs"]:
		if is_instance_valid(mesh):
			mesh.visible = true
	
	return true

func hide_block(punto_hash: String) -> bool:
	if not unstable_street_blocks.has(punto_hash):
		return false
	
	var block_data = unstable_street_blocks[punto_hash]
	
	for mesh in block_data["malla_refs"]:
		if is_instance_valid(mesh):
			mesh.visible = false
	
	return true

func clear_cache():
	var count = unstable_street_blocks.size()
	
	for block_data in unstable_street_blocks.values():
		for mesh in block_data["malla_refs"]:
			if is_instance_valid(mesh):
				mesh.queue_free()
	
	unstable_street_blocks.clear()
	cache_cleared.emit()

func cleanup_old_blocks():
	if unstable_street_blocks.size() < max_cache_size:
		return
	
	var current_time = Time.get_ticks_msec()
	var blocks_with_time = []
	
	for punto_hash in unstable_street_blocks:
		var block_data = unstable_street_blocks[punto_hash]
		var last_access = block_data.get("last_access", 0)
		
		blocks_with_time.append({
			"punto_hash": punto_hash,
			"last_access": last_access
		})
	
	blocks_with_time.sort_custom(func(a, b): return a.last_access < b.last_access)
	
	var to_remove_count = unstable_street_blocks.size() - max_cache_size + 100
	var removed = 0
	
	for i in range(min(to_remove_count, blocks_with_time.size())):
		var block_info = blocks_with_time[i]
		var punto_hash = block_info.punto_hash
		
		if unstable_street_blocks.has(punto_hash):
			var block_data = unstable_street_blocks[punto_hash]
			for mesh in block_data["malla_refs"]:
				if is_instance_valid(mesh):
					mesh.queue_free()
			
			unstable_street_blocks.erase(punto_hash)
			removed += 1
	
	cache_limit_reached.emit(removed)

func cleanup_invalid_references():
	var to_remove = []
	
	for punto_hash in unstable_street_blocks:
		var block_data = unstable_street_blocks[punto_hash]
		var valid_meshes = []
		
		for mesh in block_data["malla_refs"]:
			if is_instance_valid(mesh):
				valid_meshes.append(mesh)
		
		if valid_meshes.is_empty():
			to_remove.append(punto_hash)
		else:
			block_data["malla_refs"] = valid_meshes
	
	for punto_hash in to_remove:
		unstable_street_blocks.erase(punto_hash)

func get_cache_stats() -> Dictionary:
	var total_meshes = 0
	var current_time = Time.get_ticks_msec()
	var avg_age = 0
	
	for block_data in unstable_street_blocks.values():
		total_meshes += block_data["malla_refs"].size()
		avg_age += current_time - block_data["creation_time"]
	
	if unstable_street_blocks.size() > 0:
		avg_age = avg_age / unstable_street_blocks.size()
	
	return {
		"cached_blocks": unstable_street_blocks.size(),
		"total_meshes": total_meshes,
		"cache_usage_percent": (float(unstable_street_blocks.size()) / max_cache_size) * 100.0,
		"average_age_ms": avg_age
	}
