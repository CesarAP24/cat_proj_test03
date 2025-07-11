extends RefCounted
class_name HouseBuilder

var roof_material := preload("res://materials/roof_material.tres")
var wall_material := preload("res://materials/wall2_material.tres")

var rng := RandomNumberGenerator.new()

func _init():
	rng.seed = 24  # Solo una vez

# Escalas UV separadas
var roof_uv_scale := 0.2/6  # Escala para el techo
var wall_uv_scale := 0.25/6  # Escala para las paredes

var eave_size = 0.8*0.25*15

func config(base_quad: Array[Vector3], square_threshold := 0.15) -> Dictionary:
	# Altura de un piso (entre 2.3 y 2.6)
	var scale = 10
	
	var random_floors = rng.randf_range(1, 2)
	var floor_height = rng.randf_range(3, 3.5)  # Altura por piso
	var height = snapped(random_floors * floor_height * scale, 0.01)
	# Altura del techo (60% - 85% de un piso)
	var roof_percent = rng.randf_range(0.2, 0.22)
	var height_roof = snapped(height * roof_percent, 0.01)

	# Tipo de techo (según cantidad de vértices)
	var roof_type: int
	if base_quad.size() == 4:
		roof_type = rng.randi_range(0, 0)
	else:
		roof_type = 3  # Pirámide para polígonos con más de 4 lados

	# Número de buhardillas y porcentaje de ancho
	var num_dormers := 0
	var percentage := 1.0

	if roof_type == 0:
		num_dormers = [0,2,1,1,2,3][rng.randi_range(0, 5)]
		percentage = rng.randf_range(0.8, 1.0)
		

	return {
		"height": height,
		"height_roof": height_roof,
		"roof_type": roof_type,
		"num_dormers": num_dormers,
		"percentage": percentage
	}


func get_new_eave(prota: Vector3, ridge: Vector3, contrario: Vector3, dormer: bool) -> Vector3:
	var v = (ridge - prota).normalized()
	var u = (contrario - prota).normalized()
	var scale = 1
	if dormer:
		scale = 0.4
		
	return prota - v * eave_size*scale - u * eave_size*scale


func get_plane_normal(p0: Vector3, p1: Vector3, p2: Vector3) -> Vector3:
	var v1 = p1 - p0
	var v2 = p2 - p0
	return v1.cross(v2).normalized()

func intersect_plane_line(
	plane_point: Vector3,
	plane_normal: Vector3,
	line_point: Vector3,
	line_dir: Vector3
) -> Variant:
	# Asegurar que el vector dirección no sea paralelo al plano
	var denom = plane_normal.dot(line_dir)
	if abs(denom) < 0.00001:
		return null # La línea es paralela al plano (sin intersección o infinita)

	var t = plane_normal.dot(plane_point - line_point) / denom
	return line_point + line_dir * t

func fix_poly(base_poly: Array[Vector3], door_index: int) -> Array[Vector3]:
	if base_poly.size() != 5:
		return base_poly

	var side_lengths: Array[float] = []
	for i in range(base_poly.size()):
		var a = base_poly[i]
		var b = base_poly[(i + 1) % base_poly.size()]
		side_lengths.append(a.distance_to(b))

	var min_len = INF
	var min_index = -1
	for i in range(5):
		if side_lengths[i] < min_len:
			min_len = side_lengths[i]
			min_index = i

	var others: Array[float] = []
	for i in range(5):
		if i != min_index:
			others.append(side_lengths[i])
	var avg_others = 0.0
	for l in others:
		avg_others += l
	avg_others /= 4.0

	if min_len < 0.6 * avg_others and min_index != door_index:
		var new_poly: Array[Vector3] = []
		for i in range(5):
			if i != min_index:
				new_poly.append(base_poly[i])
		return new_poly

	return base_poly
	
	
func generate_dormer(plane_normal: Vector3, plane_point: Vector3, depth: Vector3, point_x: Vector3, A: Vector3, B: Vector3, H: float, faces: Array, vertices: Array, eave: bool) -> void:
	var ridge = point_x + Vector3.UP * H
	var p_ridge = intersect_plane_line(plane_point, plane_normal, ridge, depth)
	if p_ridge == null:
		return  # La intersección falló, se omite esta buhardilla

	# Agregar vértices y obtener sus índices
	var A_idx = vertices.size()
	vertices.append(A)

	var B_idx = vertices.size()
	vertices.append(B)

	var p_ridge_idx = vertices.size()
	vertices.append(p_ridge)
	
	var ridge_idx = vertices.size()
	vertices.append(ridge)
	
	#añadie aleros
	var new_A_idx;
	var new_B_idx;
	var new_ridge_idx;
	if eave:
		new_A_idx = vertices.size()
		new_B_idx = new_A_idx+1
		new_ridge_idx = new_A_idx+2
		vertices.append(get_new_eave(A, A+depth.normalized(), ridge, true))
		vertices.append(get_new_eave(B, B+depth.normalized(), ridge, true))
		vertices.append(get_new_eave(ridge, ridge+depth.normalized(), ridge, true))
	else:
		new_A_idx = A_idx
		new_B_idx = B_idx
		new_ridge_idx = ridge_idx
		
	
	# Caras de la buhardilla
	faces.append([0, 3, p_ridge_idx, new_ridge_idx, new_A_idx])  # lateral izquierdo
	faces.append([0, 3, new_ridge_idx, p_ridge_idx, new_B_idx])  # lateral derecho
	faces.append([1, 3, ridge_idx, B_idx,A_idx])        # frente

func generate_n_dormers(depth: Vector3, u: Vector3, v: Vector3, point: Vector3, n: int, percentage: float, faces: Array, vertices: Array,eave: bool) -> void:
	var length = u.length()
	var size_segment = length / (2 * n - 1)
	var real_size = size_segment * percentage
	var u_dir = u.normalized()
	
	for i in range(n):
		var point_x = point + (i * 2 * size_segment + size_segment / 2) * u_dir
		var A = point_x - real_size*0.5 * u_dir
		var B = point_x + real_size*0.5 * u_dir

		# Altura de la buhardilla: que no exceda la altura del techo
		var H = min(real_size, abs(v.y))

		var plane_normal = u.cross(v)  # Normal del plano del techo
		generate_dormer(plane_normal, point, depth, point_x, A, B, H, faces, vertices, eave)



func roof_gabled(top_quad: Array[Vector3], height_roof: float, vertices: Array[Vector3], faces: Array[Array], eave: bool, num_dormers: int, percentage: float) -> void:
	var offset = 4
	var d01 = top_quad[0].distance_to(top_quad[1])
	var d12 = top_quad[1].distance_to(top_quad[2])
	var short_side := []
	if d01 < d12:
		short_side = [0, 1]
	else:
		short_side = [1, 2]

	var i0 = short_side[0]
	var i1 = short_side[1]
	var i2 = (i1 + 1) % 4
	var i3 = (i0 - 1 + 4) % 4  # Corrección: asegurar valor positivo

	var ridge_A = (top_quad[i0] + top_quad[i1]) * 0.5 + Vector3(0, height_roof, 0)
	#var ridge_B = (top_quad[i2] + top_quad[i3]) * 0.5 + Vector3(0, height_roof, 0)	var ridge_B = ()
	var first_normal  = get_plane_normal(top_quad[i0], ridge_A, top_quad[i3])
	var second_normal = get_plane_normal(top_quad[i1], top_quad[i2], ridge_A)
	var line_dir = first_normal.cross(second_normal)
	var line_point = ridge_A
	var plane_point = top_quad[i3]
	var plane_normal = get_plane_normal(top_quad[i2], top_quad[i3], top_quad[i2] + Vector3.UP)
	
	var ridge_B = intersect_plane_line(plane_point, plane_normal, line_point, line_dir)
	
	#calcular los aleros
	var new_ridge_A_idx;
	var new_ridge_B_idx;
	
	if eave:
		offset = 8
		if d01 < d12:
			vertices.append(get_new_eave(top_quad[i0], ridge_A, top_quad[i3], false))
			vertices.append(get_new_eave(top_quad[i1], ridge_A, top_quad[i2], false))
			vertices.append(get_new_eave(top_quad[i2], ridge_B, top_quad[i1], false))
			vertices.append(get_new_eave(top_quad[i3], ridge_B, top_quad[i0], false))
		else:
			vertices.append(get_new_eave(top_quad[i3], ridge_B, top_quad[i0], false))
			vertices.append(get_new_eave(top_quad[i0], ridge_A, top_quad[i3], false))
			vertices.append(get_new_eave(top_quad[i1], ridge_A, top_quad[i2], false))
			vertices.append(get_new_eave(top_quad[i2], ridge_B, top_quad[i1], false))

		
		new_ridge_A_idx = vertices.size()
		new_ridge_B_idx = new_ridge_A_idx + 1

		vertices.append(get_new_eave(ridge_A, ridge_A, ridge_B, false))
		vertices.append(get_new_eave(ridge_B, ridge_B, ridge_A, false))
		
	
	var ridge_A_idx = vertices.size()
	var ridge_B_idx = ridge_A_idx + 1
	vertices.append(ridge_A)
	vertices.append(ridge_B)
	
	if not eave:
		new_ridge_A_idx = ridge_A_idx
		new_ridge_B_idx = ridge_B_idx
		
	# Caras del techo (tipo 0)
	faces.append([0, 4, new_ridge_A_idx, new_ridge_B_idx, i3 + offset, i0 + offset]) # superior A
	faces.append([0, 4, new_ridge_B_idx, new_ridge_A_idx, i1 + offset, i2 + offset]) # superior B
	faces.append([1, 3, i0 + 4, i1 + 4, ridge_A_idx])              # lateral A
	faces.append([1, 3, i2 + 4, i3 + 4, ridge_B_idx])              # lateral B
	
	var u = top_quad[i3] - top_quad[i0]
	var v = ridge_A - top_quad[i0]
	var d = top_quad[i1] - top_quad[i0]
	
	
	generate_n_dormers(d, u, v, top_quad[i0], num_dormers, percentage, faces, vertices, eave)

func roof_one_slope(top_quad: Array[Vector3], height_roof: float, vertices: Array[Vector3], faces: Array[Array], eave: bool) -> void:
	var offset = 4
	var d01 = top_quad[0].distance_to(top_quad[1])
	var d12 = top_quad[1].distance_to(top_quad[2])

	var i0 = 0
	var i1 = 1
	var i2 = (i1 + 1) % 4
	var i3 = (i0 - 1 + 4) % 4  # Corrección: asegurar valor positivo
	
	var ridge_A = top_quad[i0] + Vector3(0, height_roof, 0)
	#var ridge_B = top_quad[i1] + Vector3(0, height_roof, 0)

	var plane_normal = get_plane_normal(top_quad[i0], top_quad[i3], ridge_A)
	var plane_point = top_quad[i0]
	var line_dir = Vector3.UP
	var line_point = top_quad[i1]
	
	var ridge_B = intersect_plane_line(plane_point, plane_normal, line_point, line_dir)

	if ridge_B == null:
		ridge_B = top_quad[i1] + Vector3(0, height_roof, 0)
		
	# calcular los aleros
	var new_ridge_A_idx;
	var new_ridge_B_idx;
	if eave:
		offset = 6
		vertices.append(get_new_eave(top_quad[i2], ridge_B, top_quad[i3], false))
		vertices.append(get_new_eave(top_quad[i3], ridge_A, top_quad[i2], false))
		
		new_ridge_A_idx = vertices.size()
		new_ridge_B_idx = new_ridge_A_idx + 1

		vertices.append(get_new_eave(ridge_A, top_quad[i3], ridge_B, false))
		vertices.append(get_new_eave(ridge_B, top_quad[i2], ridge_A, false))

	var ridge_A_idx = vertices.size()
	var ridge_B_idx = ridge_A_idx + 1
	vertices.append(ridge_A)
	vertices.append(ridge_B)
	
		
	if not eave:
		new_ridge_A_idx = ridge_A_idx
		new_ridge_B_idx = ridge_B_idx
	
	# Caras del techo (tipo 0)
	faces.append([0, 4, new_ridge_A_idx, new_ridge_B_idx, i2 + offset, i3 + offset])  # cara inclinada (invertida) techo
	faces.append([1, 4, i0 + 4, i1 + 4, ridge_B_idx, ridge_A_idx])  # cara trasera (invertida)
	faces.append([1, 3, i3 + 4, i0 + 4, ridge_A_idx])               # lateral A (invertida)
	faces.append([1, 3, i1 + 4, i2 + 4, ridge_B_idx])  # orientación invertida (horaria desde fuera)

func roof_pyramid(top_quad: Array[Vector3], height_roof: float, vertices: Array[Vector3], faces: Array[Array], eave: bool) -> void:
	var n := top_quad.size()
	var offset = 1

	# Calcular el centroide como el promedio de todos los puntos del top_quad
	var center := Vector3.ZERO
	for pt in top_quad:
		center += pt
	center /= n

	# Crear el pico
	var pyramid_peak := center + Vector3(0, height_roof, 0)

	# Generar una cara por cada lado del polígono superior (caras del techo tipo 0)
	for i in range(n):
		var next_i = (i + 1) % n
		if eave:
			vertices.append(get_new_eave(top_quad[i], pyramid_peak, top_quad[next_i], false))
			offset = 2
			
	var peak_idx := vertices.size()
	vertices.append(pyramid_peak)

	for i in range(n):
		var next_i = (i + 1) % n
		faces.append([0, 3, i + n*offset, next_i + n*offset, peak_idx])

func generate_mesh_instance(vertices: Array[Vector3], faces: Array[Array]) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var mesh = ArrayMesh.new()
	
	# Separar caras
	var roof_faces: Array[Array] = []
	var other_faces: Array[Array] = []
	for face in faces:
		match face[0]:
			0: roof_faces.append(face)  # techo
			_: other_faces.append(face)  # paredes y piso
	
	# Agregar superficies
	add_faces_to_mesh(mesh, vertices, roof_faces, true)
	add_faces_to_mesh(mesh, vertices, other_faces, false)
	mesh_instance.mesh = mesh
	mesh_instance.transform = Transform3D.IDENTITY
	return mesh_instance

# Proyecta un punto 3D en coordenadas UV usando un sistema local de ejes
func project_to_uv(pos: Vector3, origin: Vector3, tangent: Vector3, bitangent: Vector3, uv_scale: float) -> Vector2:
	var local = pos - origin
	var u = local.dot(tangent)
	var v = local.dot(bitangent)
	return Vector2(u, v) * uv_scale

func calculate_tangent(p0: Vector3, p1: Vector3, p2: Vector3, uv0: Vector2, uv1: Vector2, uv2: Vector2) -> Plane:
	var edge1 = p1 - p0
	var edge2 = p2 - p0
	var delta_uv1 = uv1 - uv0
	var delta_uv2 = uv2 - uv0

	var f = 1.0 / (delta_uv1.x * delta_uv2.y - delta_uv2.x * delta_uv1.y)
	var tangent = (edge1 * delta_uv2.y - edge2 * delta_uv1.y) * f
	var bitangent_uv = (edge2 * delta_uv1.x - edge1 * delta_uv2.x) * f  # Bitangent derivado de UVs
	
	tangent = tangent.normalized()
	var normal = edge1.cross(edge2).normalized()
	var bitangent_cross = normal.cross(tangent)
	
	# Handedness correcta usando el bitangent derivado de UVs
	var handedness = 1.0 if bitangent_cross.dot(bitangent_uv) >= 0.0 else -1.0
	return Plane(tangent.x, tangent.y, tangent.z, handedness)

# Agrega caras a la malla y asigna materiales y UVs correctos
func add_faces_to_mesh(mesh: ArrayMesh, vertices: Array[Vector3], faces: Array[Array], es_techo: bool) -> void:
	if faces.is_empty():
		return
		
	var all_vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	var uvs = PackedVector2Array()
	var tangents = PackedFloat32Array()
	var vertex_index = 0
	# Usar la escala UV apropiada
	var uv_scale = roof_uv_scale if es_techo else wall_uv_scale
	
	
	for face in faces:
		var num_vertices = face[1]
		if num_vertices == 3:
			var v1 = vertices[face[2]]
			var v2 = vertices[face[3]]
			var v3 = vertices[face[4]]
			all_vertices.append_array([v1, v2, v3])
			indices.append_array([vertex_index, vertex_index + 1, vertex_index + 2])
			vertex_index += 3

			# Proyección UV coherente basada en sistema local
			var tangent = (v2 - v1).normalized()
			var normal = ((v2 - v1).cross(v3 - v1)).normalized()
			var bitangent = normal.cross(tangent)
			var origin = v1
			
			tangent = -tangent
			bitangent = -bitangent
			
			var uv1 = project_to_uv(v1, origin, tangent, bitangent, uv_scale)
			var uv2 = project_to_uv(v2, origin, tangent, bitangent, uv_scale)
			var uv3 = project_to_uv(v3, origin, tangent, bitangent, uv_scale)
						
			uvs.append_array([uv1, uv2, uv3])
			
			# Tangente real usando UVs
			var tangent_plane = calculate_tangent(v1, v2, v3, uv1, uv2, uv3)
			for _i in range(3):
				tangents.append_array([tangent_plane.x, tangent_plane.y, tangent_plane.z, tangent_plane.d])

				
		elif num_vertices == 4:
			var v1 = vertices[face[2]]
			var v2 = vertices[face[3]]
			var v3 = vertices[face[4]]
			var v4 = vertices[face[5]]
			
			# Agregar los vértices de los dos triángulos que forman el cuadrilátero
			all_vertices.append_array([v1, v2, v3, v1, v3, v4])
			indices.append_array([vertex_index, vertex_index + 1, vertex_index + 2])
			indices.append_array([vertex_index + 3, vertex_index + 4, vertex_index + 5])
			vertex_index += 6
			
			# Proyección UV coherente para los 4 vértices
			var tangent = (v2 - v1).normalized()
			var normal = ((v2 - v1).cross(v3 - v1)).normalized()
			var bitangent = normal.cross(tangent)
			var origin = v1

			
			var uv1 = project_to_uv(v1, origin, tangent, bitangent, uv_scale)
			var uv2 = project_to_uv(v2, origin, tangent, bitangent, uv_scale)
			var uv3 = project_to_uv(v3, origin, tangent, bitangent, uv_scale)
			var uv4 = project_to_uv(v4, origin, tangent, bitangent, uv_scale)

			# Agregar UVs para los dos triángulos (v1,v2,v3) y (v1,v3,v4)
			uvs.append_array([uv1, uv2, uv3, uv1, uv3, uv4])
			
			# Primer triángulo (v1, v2, v3)
			var tangent1 = calculate_tangent(v1, v2, v3, uv1, uv2, uv3)
			tangents.append_array([tangent1.x, tangent1.y, tangent1.z, tangent1.d])
			tangents.append_array([tangent1.x, tangent1.y, tangent1.z, tangent1.d])
			tangents.append_array([tangent1.x, tangent1.y, tangent1.z, tangent1.d])

			# Segundo triángulo (v1, v3, v4)
			var tangent2 = calculate_tangent(v1, v3, v4, uv1, uv3, uv4)
			tangents.append_array([tangent2.x, tangent2.y, tangent2.z, tangent2.d])
			tangents.append_array([tangent2.x, tangent2.y, tangent2.z, tangent2.d])
			tangents.append_array([tangent2.x, tangent2.y, tangent2.z, tangent2.d])

			
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = all_vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TANGENT] = tangents
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	# Asignar material adecuado
	var material: Material = roof_material if es_techo else wall_material

	mesh.surface_set_material(mesh.get_surface_count() - 1, material)

func build_house(base_poly: Array[Vector3], door_index: int = 4) -> MeshInstance3D:
	base_poly = fix_poly(base_poly, door_index)
	door_index = door_index%base_poly.size()
	var parameters = config(base_poly)
	print(parameters)
	
	var height = parameters["height"]
	var height_roof = parameters["height_roof"]
	var roof_type = parameters["roof_type"]
	var num_dormers = parameters["num_dormers"]
	var percentage = parameters["percentage"]
	var vertices: Array[Vector3] = []
	var faces: Array[Array] = []

	var n := base_poly.size()
	if n < 3:
		push_error("Se requieren al menos 3 puntos para construir una casa.")
		return MeshInstance3D.new()

	# DESFASE HACIA ABAJO - Agregar offset negativo en Y
	var y_offset = generate_y_offset_from_noise(base_poly) - 50
	
	# Aplicar desfase a base_poly
	for i in range(base_poly.size()):
		base_poly[i].y += y_offset

	# Reordenar base_poly solo si el techo será one slope
	if roof_type == 2:
		var first := ((door_index + n) - 2) % n
		if first != 0:
			var rotated: Array[Vector3] = []
			for i in range(n):
				rotated.append(base_poly[(first + i) % n])
			base_poly = rotated

	# Crear top_polygon elevando en Y (ya con el offset aplicado)
	var top_poly: Array[Vector3] = []
	for point in base_poly:
		top_poly.append(point + Vector3(0, height, 0))

	# El resto del código permanece igual...
	vertices.append_array(base_poly)
	vertices.append_array(top_poly)

	for i in range(n):
		var next = (i + 1) % n
		faces.append([1, 4, i, next, next + n, i + n])
		
	for i in range(1, n - 1):
		faces.append([1, 3, i + 1, i, 0])

	match roof_type:
		0:
			roof_gabled(top_poly, height_roof, vertices, faces, true, num_dormers, percentage)
		1:
			for i in range(1, n - 1):
				faces.append([0, 3, n, n + i, n + i + 1])
		2:
			roof_one_slope(top_poly, height_roof, vertices, faces, true)
		3:
			roof_pyramid(top_poly, height_roof, vertices, faces, true)

	return generate_mesh_instance(vertices, faces)
	

# Agregar esta función en tu clase
static var terrain_noise: FastNoiseLite

func generate_y_offset_from_noise(base_poly: Array[Vector3]) -> float:
	# Inicializar noise si no existe
	if not terrain_noise:
		terrain_noise = FastNoiseLite.new()
		terrain_noise.noise_type = FastNoiseLite.TYPE_PERLIN
		terrain_noise.seed = 54321
		terrain_noise.frequency = 0.005  # Más bajo = transiciones más suaves
	
	# Calcular centro del polígono
	var center = Vector3.ZERO
	for point in base_poly:
		center += point
	center /= base_poly.size()
	
	# Obtener valor noise (-1 a 1)
	var noise_value = terrain_noise.get_noise_2d(center.x, center.z)
	
	# Mapear a rango de offset (-30 a -10 metros por ejemplo)
	var min_offset = 100.0
	var max_offset = -100.0
	return min_offset + (noise_value + 1.0) * 0.5 * (max_offset - min_offset)
