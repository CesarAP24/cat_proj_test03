
extends Spatial

export(NodePath) var objetivo_path
export(float) var offset_y

onready var objetivo = get_node(objetivo_path)
onready var t_backL = $metarig/t_backL
onready var t_backR = $metarig/t_backR
onready var t_frontL = $metarig/t_frontL
onready var t_frontR = $metarig/t_frontR
onready var ik_backL = $metarig/Skeleton/ik_backL
onready var ik_backR = $metarig/Skeleton/ik_backR
onready var ik_frontL = $metarig/Skeleton/ik_frontL
onready var ik_frontR = $metarig/Skeleton/ik_frontR


onready var hueso =  $metarig/Skeleton

# Añade un nodo ImmediateGeometry como hijo de tu nodo raíz
onready var debug_geometry = ImmediateGeometry.new()
onready var debug_material = SpatialMaterial.new()

onready var basis_pos = []

func update_root_pos_rot():
	var center = objetivo.call("obtener_centro")
	center.y = center.y - offset_y
	global_transform.origin = center

	var dir = objetivo.call("obtener_direccion")
	
	var angle_y = atan2(dir.x, dir.z)
	global_transform.basis = Basis(Vector3.UP, angle_y)

func update_targets_pos():
	var patas = objetivo.call("obtener_patas")
	t_backL.global_position = patas["backL"]
	t_backR.global_position = patas["backR"]
	t_frontL.global_position = patas["frontL"]
	t_frontR.global_position = patas["frontR"]



# Función que obtiene la posición global de los huesos
func get_positions_vector3(bones: Array, skeleton: Skeleton) -> Array:
	var positions = []
	for bone_name in bones:
		var idx = skeleton.find_bone(bone_name)
		var bone_pose = skeleton.get_bone_global_pose(idx)
		positions.append(bone_pose.origin)
		
	
	var idx = skeleton.find_bone(bones[-1])
	var bone_pose = skeleton.get_bone_global_pose(idx)
	
	positions.append(bone_pose.origin+objetivo.call("obtener_direccion"))
	return positions

func get_solution_column(target: Vector3, puntos: Array) -> Array:
	var new_puntos := []
	new_puntos.resize(puntos.size())
	new_puntos[puntos.size() - 1] = target

	for i in range(puntos.size() - 2, -1, -1):
		var dir = target - puntos[i]
		var dir_u = dir.normalized()
		var distancia = puntos[i + 1].distance_to(puntos[i])
		new_puntos[i] = new_puntos[i + 1] + dir_u * -1.0 * distancia
		target = new_puntos[i]

	return new_puntos


# Función para actualizar la columna
func update_column(skeleton: Skeleton, bones: Array, target: Vector3):
	# Obtener las posiciones actuales de los huesos
	var positions = get_positions_vector3(bones, skeleton)
	
	# Obtener la solución de la columna IK
	var positions_no_answer = positions
	positions = get_solution_column(target, positions)
	
	# Actualizar la posición y rotación de los huesos
	for i in range(positions.size() - 1):
		var current_bone = skeleton.find_bone(bones[i])
		var pos = skeleton.get_bone_global_pose(current_bone)
		var rest = skeleton.get_bone_rest(current_bone)
		
		pos.origin = positions[i]  # Establecer la posición de la raíz de la columna
		
		var basis = pos.basis
		var dir = positions[i+1]-positions[i]
		var dir_proj_zx = Vector2(dir.x, dir.z)
		pos.basis = basis_pos[i].basis * Basis(Vector3.BACK, Vector2(0,10).angle_to(dir_proj_zx))
		

		
		skeleton.set_bone_global_pose_override(current_bone, pos, 1, true)

func get_target_pos():
	var patas = objetivo.call("obtener_patas")
	var out = (patas["frontL"] + patas["frontR"])/2
	out.y += offset_y/2
	return out


func _ready():
	add_child(debug_geometry)
	debug_material.flags_unshaded = true
	debug_material.vertex_color_use_as_albedo = true
	

	ik_backL.start()
	ik_backR.start()
	ik_frontL.start()
	ik_frontR.start()
	
	for name in ["spine","spine.001","spine.002","spine.003"]:
		var current_bone = hueso.find_bone(name)
		var pos = hueso.get_bone_global_pose(current_bone)
		basis_pos.append(pos)
		
	

func _process(_delta):
	# Limpiar geometría anterior
	debug_geometry.clear()
	
	# Empezar a dibujar
	debug_geometry.begin(Mesh.PRIMITIVE_LINES, debug_material)
	
	# Dibujar ejes para cada hueso que quieras visualizar
	var bone_names = ["spine", "spine.001", "spine.002", "spine.003"]
	for bone_name in bone_names:
		draw_bone_axes(bone_name)
	
	# Terminar de dibujar
	debug_geometry.end()
	
	if not objetivo:
		return
		
	if Input.is_key_pressed(KEY_P):
		offset_y += 0.1
	if Input.is_key_pressed(KEY_O):
		offset_y -= 0.1
	
		
	update_targets_pos()
	update_column(hueso, ["spine","spine.001","spine.002","spine.003"], get_target_pos())

func draw_bone_axes(bone_name: String):
	var bone_idx = $metarig/Skeleton.find_bone(bone_name)
	if bone_idx == -1:
		return
		
	var transform = $metarig/Skeleton.get_bone_global_pose(bone_idx)
	var origin = transform.origin
	var scale = 2  # Escala de las líneas
	
	# Dibujar eje X (rojo)
	debug_geometry.set_color(Color.red)
	debug_geometry.add_vertex(origin)
	debug_geometry.add_vertex(origin + transform.basis.x * scale)
	
	# Dibujar eje Y (verde)
	debug_geometry.set_color(Color.green)
	debug_geometry.add_vertex(origin)
	debug_geometry.add_vertex(origin + transform.basis.y * scale)
	
	# Dibujar eje Z (azul)
	debug_geometry.set_color(Color.blue)
	debug_geometry.add_vertex(origin)
	debug_geometry.add_vertex(origin + transform.basis.z * scale)
