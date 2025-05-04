extends Spatial

export(NodePath) var objetivo_path
export(float) var offset_y = 10

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


func update_targets_pos():
	var patas = objetivo.call("obtener_patas")
	t_backL.global_position = patas["backL"]
	t_backR.global_position = patas["backR"]
	t_frontL.global_position = patas["frontL"]
	t_frontR.global_position = patas["frontR"]

func get_target_pos():
	var patas = objetivo.call("obtener_patas")
	var out = (patas["frontL"] + patas["frontR"])/2
	out.y += offset_y/2
	return out

func update_hips_positions():
	pass

func rotate_something(degrees, name, vector):
	var idx = hueso.find_bone(name)
	var global_pose = hueso.get_bone_global_pose(idx)
	
	# Rotar 15 grados hacia la derecha en eje Y
	var rot = Basis(vector, deg2rad(degrees))
	
	global_pose.basis = rot * global_pose.basis
	
	hueso.set_bone_global_pose_override(idx, global_pose, 1.0, true)

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


func get_lookAt_column_basis(from_pos: Vector3, to_pos: Vector3, curr_basis: Basis, last_targ: Vector3) -> Basis:
	# Proyectamos los vectores al plano XZ para la rotación en Y
	var v1 = last_targ - from_pos
	var v2 = to_pos - from_pos
	
	var v1_proj_zx = Vector2(v1.x, v1.z)
	var v2_proj_zx = Vector2(v2.x, v2.z)
	
	# Calculamos el ángulo entre los vectores (SIN convertir a grados)
	var angle = atan2(v1_proj_zx.x * v2_proj_zx.y - v1_proj_zx.y * v2_proj_zx.x, v1_proj_zx.dot(v2_proj_zx))
	
	# Limitamos la rotación para evitar giros bruscos
	angle = clamp(angle, -0.2, 0.2)  # Ajusta estos valores según necesites
	
	# Creamos la matriz de rotación con el ángulo en radianes
	var matriz_rot = Basis(Vector3.UP, angle)
	return curr_basis * matriz_rot

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
		var pos = skeleton.get_bone_rest(current_bone)
		
		pos.origin = positions[i]  # Establecer la posición de la raíz de la columna
		
		# Obtener la rotación entre el hueso actual y el siguiente
		pos.basis = get_lookAt_column_basis(positions[i], positions[i + 1], pos.basis, positions_no_answer[i+1])
		# Aplicar la nueva pose al hueso
		skeleton.set_bone_global_pose_override(current_bone, pos, 1, true)

	


func _process(delta):
	if not objetivo:
		return
		
		
		
	if Input.is_key_pressed(KEY_P):
		offset_y += 0.1
	if Input.is_key_pressed(KEY_O):
		offset_y -= 0.1
	if Input.is_key_pressed(KEY_Q):
		rotate_something(30*delta, "spine.001", Vector3.UP)
	if Input.is_key_pressed(KEY_E):
		rotate_something(-30*delta, "spine.001", Vector3.UP)
	
	update_targets_pos()
	update_column(hueso, ["spine","spine.001","spine.002","spine.003","spine.004","spine.006"], get_target_pos())



func _ready():
	
	ik_backL.start()
	ik_backR.start()
	ik_frontL.start()
	ik_frontR.start()

