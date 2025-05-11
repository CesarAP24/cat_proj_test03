extends Camera3D

@export var objetivo_path: NodePath
@export var distancia: float = 200.0
@export var altura: float = 150.0
@export var angulo: float = 45.0
@export var sensibilidad_rotacion: float = 0.08
@export var invertir_x: bool = false
@export var invertir_y: bool = false
@export var zoom_min: float = 10.0
@export var zoom_max: float = 700.0
@export var zoom_speed: float = 0.2
@export var velocidad_suavizado: float = 10


var rotacion_y = 0.0
var rotacion_x = 0.0
var clic_derecho_presionado = false

@onready var objetivo = get_node(objetivo_path)

func _ready():
	rotacion_y = 0.0
	rotacion_x = deg_to_rad(angulo)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):
	# Handle right-click for camera rotation
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			clic_derecho_presionado = event.pressed
			
			if clic_derecho_presionado:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		# Handle left-click for target movement
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Create raycast from camera to clicked position
			var from = project_ray_origin(event.position)
			var to = from + project_ray_normal(event.position) * 1000
			
			# Create PhysicsRayQueryParameters
			var ray_query = PhysicsRayQueryParameters3D.new()
			ray_query.from = from
			ray_query.to = to
			
			# Create physics space state to perform the raycast
			var space_state = get_world_3d().direct_space_state
			
			# Perform raycast
			var result = space_state.intersect_ray(ray_query)
			
			# If raycast hit something
			if result:
				# Move target to hit position
				if objetivo and objetivo.has_method("set_target"):
					objetivo.set_target(result.position)
		
		# NEW CODE: Handle mouse wheel for zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Zoom in
			distancia = max(zoom_min, distancia - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Zoom out
			distancia = min(zoom_max, distancia + zoom_speed)
	
	# Handle mouse motion for camera rotation
	elif event is InputEventMouseMotion and clic_derecho_presionado:
		var factor_x = -1.0 if invertir_x else 1.0
		var factor_y = -1.0 if invertir_y else 1.0
		
		rotacion_y += event.relative.x * sensibilidad_rotacion * 0.01 * factor_x
		rotacion_x += event.relative.y * sensibilidad_rotacion * 0.01 * factor_y
		
		rotacion_x = clamp(rotacion_x, 0.1, PI/2.0)


func _process(delta):
	if not objetivo:
		return
	
	var center = objetivo.call("obtener_centro")
	
	var offset = Vector3()
	offset.x = sin(rotacion_y) * distancia * cos(rotacion_x)
	offset.y = sin(rotacion_x) * distancia
	offset.z = cos(rotacion_y) * distancia * cos(rotacion_x)
	
	# Suavizado de posición
	var target_position = center + offset
	var direction = target_position - global_transform.origin
	global_transform.origin += direction * delta * 5
	
	# Suavizado de rotación
	# Creamos una transformación temporal hacia el objetivo
	var target_transform = global_transform.looking_at(center, Vector3.UP)
	
	# Obtenemos la rotación actual y la objetivo como quaterniones
	var current_quat = global_transform.basis.get_rotation_quaternion()
	var target_quat = target_transform.basis.get_rotation_quaternion()
	
	# Interpolamos entre las rotaciones usando slerp
	var new_quat = current_quat.slerp(target_quat, delta * velocidad_suavizado)
	
	# Aplicamos la nueva rotación
	global_transform.basis = Basis(new_quat)
