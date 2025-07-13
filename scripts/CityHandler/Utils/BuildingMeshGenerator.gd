# BuildingMeshGenerator.gd
class_name BuildingMeshGenerator
static var house_builder = HouseBuilder.new()

static func create_building(polygon: Array, world_position: Vector2, seed: int = 0) -> MeshInstance3D:
	if polygon.size() < 3:
		return null
	
	# Convertir Vector2 array a Vector3 array (Y = 0)
	var base_poly_3d: Array[Vector3] = []
	for point in polygon:
		base_poly_3d.append(Vector3(point.x - world_position.x, 0, point.y - world_position.y))
	
	# Generar la casa CON VENTANAS usando HouseBuilder
	var building_data = house_builder.build_house_with_all_windows(base_poly_3d)
	var mesh_instance = building_data["house"]  # Este sigue siendo MeshInstance3D
	var windows = building_data["windows"]
	
	# Posicionar en el mundo
	mesh_instance.position = Vector3(world_position.x, 0, world_position.y)
	
	# Agregar collider SOLO a la casa (no a las ventanas)
	add_collision_to_building(mesh_instance)
	
	# Agregar las ventanas como hijos del MeshInstance3D de la casa
	for window in windows:
		if window != null:
			mesh_instance.add_child(window)
	
	return mesh_instance

static func generate_deterministic_seed(world_position: Vector2, base_seed: int) -> int:
	# Crear seed determinístico basado en posición y seed base
	var x_int = int(world_position.x * 1000)
	var y_int = int(world_position.y * 1000)
	return hash_combine(x_int, hash_combine(y_int, base_seed))

static func add_collision_to_building(mesh_instance: MeshInstance3D):
	if not mesh_instance or not mesh_instance.mesh:
		return
	
	# Crear collider SOLO para la casa (no para ventanas)
	var static_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	
	# Generar shape desde el mesh de la casa
	collision_shape.shape = mesh_instance.mesh.create_trimesh_shape()
	
	# Añadir al grupo "suelo"
	static_body.add_to_group("suelo")
	
	# Estructura: MeshInstance3D -> StaticBody3D -> CollisionShape3D
	static_body.add_child(collision_shape)
	mesh_instance.add_child(static_body)

# Función auxiliar para combinar valores hash (mantenida para compatibilidad)
static func hash_combine(a: int, b: int) -> int:
	return a ^ (b + 0x9e3779b9 + (a << 6) + (a >> 2))
