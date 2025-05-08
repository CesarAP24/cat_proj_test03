
extends Node3D

@export var objetivo_path: NodePath
@export var offset_y: float

@onready var objetivo = get_node(objetivo_path)
@onready var t_backL = $metarig/t_backL
@onready var t_backR = $metarig/t_backR
@onready var t_frontL = $metarig/t_frontL
@onready var t_frontR = $metarig/t_frontR
@onready var ik_backL = $metarig/Skeleton3D/ik_backL
@onready var ik_backL2 = $metarig/Skeleton3D/ik_backL2
@onready var ik_backR = $metarig/Skeleton3D/ik_backR
@onready var ik_backR2 = $metarig/Skeleton3D/ik_backR2
@onready var ik_frontL = $metarig/Skeleton3D/ik_frontL
@onready var ik_frontR = $metarig/Skeleton3D/ik_frontR
@export var spring_stiffness: float = 250.0  # Controls how strongly the spring pulls
@export var spring_damping: float = 15  # Controls how quickly oscillations settle
@export var mass: float = 1.0             # Simulated mass of the head
var column_bones = ["spine","spine.001","spine.002","spine.003"]

@onready var helper = 0


@onready var hueso =  $metarig/Skeleton3D

# Añade un nodo ImmediateGeometry como hijo de tu nodo raíz
@onready var debug_geometry = ImmediateMesh.new()
@onready var debug_material = StandardMaterial3D.new()

@onready var basis_pos = []

var velocity = Vector3.ZERO
var current_head_pos = Vector3.ZERO

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
func get_positions_vector3(bones: Array, skeleton: Skeleton3D) -> Array:
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
func update_column(skeleton: Skeleton3D, bones: Array, target: Vector3, delta: float):
	# Spring physics simulation
	var desired_pos = target
	var current_pos = current_head_pos
	
	# Calculate spring force: F = -k * x - b * v
	# where k is spring stiffness, x is displacement, b is damping, v is velocity
	var displacement = current_pos - desired_pos
	var spring_force = -spring_stiffness * displacement - spring_damping * velocity
	
	# Calculate acceleration (F = ma, so a = F/m)
	var acceleration = spring_force / mass
	
	# Update velocity and position using verlet integration
	velocity += acceleration * delta
	current_head_pos += velocity * delta
	
	# Get original positions and generate solution with the spring-affected head position
	var positions = get_positions_vector3(bones, skeleton)
	positions = get_solution_column(current_head_pos, positions)
	
	# Rest of your existing update_column code
	for i in range(positions.size() - 1):
		var current_bone = skeleton.find_bone(bones[i])
		var pos = skeleton.get_bone_global_pose(current_bone)
		
		pos.origin = positions[i]
		
		var basis = pos.basis
		var dir = positions[i+1]-positions[i]
		var dir_proj_zx = Vector3(dir.x, 0, dir.z)
		pos.basis = basis_pos[i].basis * Basis(Vector3.BACK, Vector3(0,0,10).signed_angle_to(dir_proj_zx, Vector3.DOWN))
		
		var vec_plane = pos.basis.x;
		var point_plane = pos.origin;
		var dir_proj_vec_plane = dir - dir.dot(vec_plane.normalized()) * vec_plane.normalized()
		var front_proj_vec_plane = Vector3(dir_proj_vec_plane.x, 0, dir_proj_vec_plane.z)
		
		pos.basis *= Basis(basis_pos[i].basis.x.normalized(), -dir_proj_vec_plane.signed_angle_to(front_proj_vec_plane, pos.basis.x))
		
		skeleton.set_bone_global_pose_override(current_bone, pos, 1, true)

func get_target_pos():
	var patas = objetivo.call("obtener_patas")
	if (patas):
		var out = (patas["frontL"] + patas["frontR"])/2
		out.y += offset_y/2
		return out + objetivo.call("obtener_direccion")*1.5
	return Vector3(0,0,0)
	
func update_magnet_pos():
	ik_backL.magnet = t_frontL.position;
	var vec = t_frontL.position - t_backL.position
	vec = vec.normalized()
	ik_backL2.magnet = t_backL.position - vec*100;
	
	ik_backR.magnet = t_frontR.position;
	vec = t_frontR.position - t_backR.position
	vec = vec.normalized()
	ik_backR2.magnet = t_backR.position - vec*100;
	
	ik_frontL.magnet = t_backL.position;
	ik_frontR.magnet = t_backR.position;
	

func _ready():
	ik_backL.start()
	ik_backR.start()
	ik_frontL.start()
	ik_frontR.start()
	ik_backL2.start()
	ik_backR2.start()
	
	for name in column_bones:
		var current_bone = hueso.find_bone(name)
		var pos = hueso.get_bone_global_pose(current_bone)
		basis_pos.append(pos)
		
	current_head_pos = get_target_pos()

		

func _process(delta):
	if not objetivo:
		return
		
	if Input.is_key_pressed(KEY_P):
		offset_y += 0.1
	if Input.is_key_pressed(KEY_O):
		offset_y -= 0.1
	
	if Input.is_key_pressed(KEY_R):
		helper += 0.1
	if Input.is_key_pressed(KEY_T):
		helper -= 0.1
	
	# Add these controls for spring parameters
	if Input.is_key_pressed(KEY_U):
		spring_stiffness += 0.1
		print("Spring stiffness: ", spring_stiffness)
	if Input.is_key_pressed(KEY_J):
		spring_stiffness = max(0.1, spring_stiffness - 0.1)
		print("Spring stiffness: ", spring_stiffness)
	if Input.is_key_pressed(KEY_I):
		spring_damping += 0.1
		print("Spring damping: ", spring_damping)
	if Input.is_key_pressed(KEY_K):
		spring_damping = max(0.1, spring_damping - 0.1)
		print("Spring damping: ", spring_damping)
		
	# Limpiar geometría anterior
	update_targets_pos()
	update_column(hueso, column_bones, get_target_pos(), delta)
	update_magnet_pos()
	
