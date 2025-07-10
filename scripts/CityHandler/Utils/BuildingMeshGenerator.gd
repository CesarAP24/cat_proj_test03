# BuildingMeshGenerator.gd
class_name BuildingMeshGenerator

static func create_building(polygon: Array, world_position: Vector2, seed: int = 0) -> MeshInstance3D:
	
	if polygon.size() < 3:
		return null
	
	# Crear el MeshInstance3D
	var mesh_instance = MeshInstance3D.new()
	var array_mesh = ArrayMesh.new()
	
	# Generar altura usando hash function con seed
	var building_height = generate_height_from_hash(world_position, seed)
	
	# Arrays para el mesh
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	var vertex_count = 0
	
	# 1. Crear la base (cara inferior)
	var base_center = Vector3(0, 0, 0)
	for i in range(polygon.size()):
		var curr = Vector3(polygon[i].x - world_position.x, 0, polygon[i].y - world_position.y)
		var next = Vector3(polygon[(i + 1) % polygon.size()].x - world_position.x, 0, polygon[(i + 1) % polygon.size()].y - world_position.y)
		
		# Triángulo de la base
		vertices.append(base_center)
		vertices.append(curr)
		vertices.append(next)
		
		# Normales hacia abajo
		normals.append(Vector3.DOWN)
		normals.append(Vector3.DOWN)
		normals.append(Vector3.DOWN)
		
		# UVs básicas
		uvs.append(Vector2(0.5, 0.5))
		uvs.append(Vector2(0, 0))
		uvs.append(Vector2(1, 0))
		
		# Índices
		indices.append(vertex_count)
		indices.append(vertex_count + 1)
		indices.append(vertex_count + 2)
		vertex_count += 3
	
	# 2. Crear el techo (cara superior)
	var roof_center = Vector3(0, building_height, 0)
	for i in range(polygon.size()):
		var curr = Vector3(polygon[i].x - world_position.x, building_height, polygon[i].y - world_position.y)
		var next = Vector3(polygon[(i + 1) % polygon.size()].x - world_position.x, building_height, polygon[(i + 1) % polygon.size()].y - world_position.y)
		
		# Triángulo del techo (mismo orden que la base para normal hacia arriba)
		vertices.append(roof_center)
		vertices.append(curr)
		vertices.append(next)
		
		# Normales hacia arriba
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		
		# UVs básicas
		uvs.append(Vector2(0.5, 0.5))
		uvs.append(Vector2(1, 1))
		uvs.append(Vector2(0, 1))
		
		# Índices
		indices.append(vertex_count)
		indices.append(vertex_count + 1)
		indices.append(vertex_count + 2)
		vertex_count += 3
	
	# 3. Crear las paredes laterales
	for i in range(polygon.size()):
		var curr_bottom = Vector3(polygon[i].x - world_position.x, 0, polygon[i].y - world_position.y)
		var next_bottom = Vector3(polygon[(i + 1) % polygon.size()].x - world_position.x, 0, polygon[(i + 1) % polygon.size()].y - world_position.y)
		var curr_top = Vector3(polygon[i].x - world_position.x, building_height, polygon[i].y - world_position.y)
		var next_top = Vector3(polygon[(i + 1) % polygon.size()].x - world_position.x, building_height, polygon[(i + 1) % polygon.size()].y - world_position.y)
		
		# Calcular normal de la pared
		var edge = next_bottom - curr_bottom
		var wall_normal = Vector3(-edge.z, 0, edge.x).normalized()
		
		# Primer triángulo de la pared
		vertices.append(curr_bottom)
		vertices.append(next_bottom)
		vertices.append(curr_top)
		
		normals.append(wall_normal)
		normals.append(wall_normal)
		normals.append(wall_normal)
		
		uvs.append(Vector2(0, 0))
		uvs.append(Vector2(1, 0))
		uvs.append(Vector2(0, 1))
		
		indices.append(vertex_count)
		indices.append(vertex_count + 1)
		indices.append(vertex_count + 2)
		vertex_count += 3
		
		# Segundo triángulo de la pared
		vertices.append(next_bottom)
		vertices.append(next_top)
		vertices.append(curr_top)
		
		normals.append(wall_normal)
		normals.append(wall_normal)
		normals.append(wall_normal)
		
		uvs.append(Vector2(1, 0))
		uvs.append(Vector2(1, 1))
		uvs.append(Vector2(0, 1))
		
		indices.append(vertex_count)
		indices.append(vertex_count + 1)
		indices.append(vertex_count + 2)
		vertex_count += 3
	
	# Crear el mesh
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = array_mesh
	mesh_instance.position = Vector3(world_position.x, 0, world_position.y)
	
	# Material básico
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1,1,1)
	mesh_instance.set_surface_override_material(0, material)
	
	# Crear collider
	var static_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	
	# Generar shape desde el mesh
	collision_shape.shape = array_mesh.create_trimesh_shape()
	
	# Añadir al grupo "suelo"
	static_body.add_to_group("suelo")
	
	# Estructura: MeshInstance3D -> StaticBody3D -> CollisionShape3D
	static_body.add_child(collision_shape)
	mesh_instance.add_child(static_body)
	
	return mesh_instance

# Función hash para generar altura determinística
static func generate_height_from_hash(world_position: Vector2, seed: int) -> float:
	# Convertir posición a enteros para hash consistente
	var x_int = int(world_position.x * 100) # Multiplicar para más precisión
	var y_int = int(world_position.y * 100)
	
	# Crear valor hash combinando posición y seed
	var hash_value = hash_combine(x_int, hash_combine(y_int, seed))
	
	# Convertir hash a valor entre 0 y 1
	var normalized_hash = float(abs(hash_value) % 1000000) / 1000000.0
	
	# Mapear a rango de alturas deseado (3.0 a 15.0 metros)
	var min_height = 15.0
	var max_height = 30.0
	
	return min_height + (normalized_hash * (max_height - min_height))

# Función auxiliar para combinar valores hash
static func hash_combine(a: int, b: int) -> int:
	# Implementación similar a std::hash en C++
	return a ^ (b + 0x9e3779b9 + (a << 6) + (a >> 2))
