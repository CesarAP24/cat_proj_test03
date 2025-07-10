class_name MeshVisibilityManager

var point_to_meshes: Dictionary = {}
var unstable_meshes: Array[MeshInstance3D] = []
var mesh_containers: Dictionary = {}

func _init(containers: Dictionary):
	mesh_containers = containers

func register_unstable_mesh(punto_hash: String, meshes: Array):
	if not meshes.is_empty():
		point_to_meshes[punto_hash] = meshes
		unstable_meshes.append_array(meshes)

func show_meshes_for_point(punto_hash: String, meshes: Array = []):
	var target_meshes = meshes
	if target_meshes.is_empty() and point_to_meshes.has(punto_hash):
		target_meshes = point_to_meshes[punto_hash]
	
	for mesh in target_meshes:
		if is_instance_valid(mesh):
			mesh.visible = true
	
	if not meshes.is_empty():
		point_to_meshes[punto_hash] = meshes

func hide_meshes_for_point(punto_hash: String):
	if not point_to_meshes.has(punto_hash):
		return
	
	for mesh in point_to_meshes[punto_hash]:
		if is_instance_valid(mesh):
			mesh.visible = false

func hide_all_unstable_meshes():
	for mesh in unstable_meshes:
		if is_instance_valid(mesh):
			mesh.visible = false
	
	_cleanup_invalid_unstable_references()

func cleanup_invalid_references():
	var to_remove = []
	
	for punto_hash in point_to_meshes:
		var valid_meshes = []
		for mesh in point_to_meshes[punto_hash]:
			if is_instance_valid(mesh):
				valid_meshes.append(mesh)
		
		if valid_meshes.is_empty():
			to_remove.append(punto_hash)
		else:
			point_to_meshes[punto_hash] = valid_meshes
	
	for punto_hash in to_remove:
		point_to_meshes.erase(punto_hash)
	
	_cleanup_invalid_unstable_references()

func clear_all_meshes():
	for meshes in point_to_meshes.values():
		for mesh in meshes:
			if is_instance_valid(mesh):
				mesh.queue_free()
	
	point_to_meshes.clear()
	unstable_meshes.clear()

func get_mesh_count() -> Dictionary:
	var total_meshes = 0
	var visible_meshes = 0
	var invalid_meshes = 0
	
	for meshes in point_to_meshes.values():
		for mesh in meshes:
			if is_instance_valid(mesh):
				total_meshes += 1
				if mesh.visible:
					visible_meshes += 1
			else:
				invalid_meshes += 1
	
	return {
		"total_meshes": total_meshes,
		"visible_meshes": visible_meshes,
		"invalid_meshes": invalid_meshes,
		"unstable_tracked": unstable_meshes.size()
	}

func _cleanup_invalid_unstable_references():
	unstable_meshes = unstable_meshes.filter(func(mesh): return is_instance_valid(mesh))
