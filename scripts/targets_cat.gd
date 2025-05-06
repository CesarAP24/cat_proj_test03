
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
export(float) var spring_stiffness = 250.0  # Controls how strongly the spring pulls
export(float) var spring_damping = 15  # Controls how quickly oscillations settle
export(float) var mass = 1.0             # Simulated mass of the head

onready var helper = 0


onready var hueso =  $metarig/Skeleton

# Añade un nodo ImmediateGeometry como hijo de tu nodo raíz
onready var debug_geometry = ImmediateGeometry.new()
onready var debug_material = SpatialMaterial.new()

onready var basis_pos = []

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
func update_column(skeleton: Skeleton, bones: Array, target: Vector3, delta: float):
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
	ik_backR.magnet = t_frontR.position;
	

	ik_frontL.magnet = t_backL.position;
	ik_frontR.magnet = t_backR.position;
	


func _ready():
	add_child(debug_geometry)
	debug_material.flags_unshaded = true
	debug_material.vertex_color_use_as_albedo = true
	

	ik_backL.start()
	ik_backR.start()
	ik_frontL.start()
	ik_frontR.start()
	
	for name in ["spine","spine.001","spine.002","spine.003", "spine.004"]:
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
	debug_geometry.clear()
	update_targets_pos()
	update_column(hueso, ["spine","spine.001","spine.002","spine.003","spine.004"], get_target_pos(), delta)
	update_magnet_pos()
	
	# Optional: Visualize spring target and current head position
	debug_geometry.begin(Mesh.PRIMITIVE_LINES)
	
	# Draw target position in yellow
	debug_geometry.set_color(Color.yellow)
	var target_pos = get_target_pos()
	debug_geometry.add_vertex(target_pos + Vector3(0, 1, 0))
	debug_geometry.add_vertex(target_pos + Vector3(0, -1, 0))
	debug_geometry.add_vertex(target_pos + Vector3(1, 0, 0))
	debug_geometry.add_vertex(target_pos + Vector3(-1, 0, 0))
	debug_geometry.add_vertex(target_pos + Vector3(0, 0, 1))
	debug_geometry.add_vertex(target_pos + Vector3(0, 0, -1))
	
	# Draw current head position in cyan
	debug_geometry.set_color(Color.cyan)
	debug_geometry.add_vertex(current_head_pos + Vector3(0, 0.8, 0))
	debug_geometry.add_vertex(current_head_pos + Vector3(0, -0.8, 0))
	debug_geometry.add_vertex(current_head_pos + Vector3(0.8, 0, 0))
	debug_geometry.add_vertex(current_head_pos + Vector3(-0.8, 0, 0))
	debug_geometry.add_vertex(current_head_pos + Vector3(0, 0, 0.8))
	debug_geometry.add_vertex(current_head_pos + Vector3(0, 0, -0.8))
	
	debug_geometry.end()

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
	debug_geometry.add_vertex(origin + transform.basis.x * scale*5)
	
	# Dibujar eje Y (verde)
	debug_geometry.set_color(Color.green)
	debug_geometry.add_vertex(origin)
	debug_geometry.add_vertex(origin + transform.basis.y * scale*100)
	
	# Dibujar eje Z (azul)
	debug_geometry.set_color(Color.blue)
	debug_geometry.add_vertex(origin)
	debug_geometry.add_vertex(origin + transform.basis.z * scale)
