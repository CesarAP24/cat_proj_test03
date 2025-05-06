extends Camera

export(NodePath) var objetivo_path
export(float) var distancia = 200.0
export(float) var altura = 150.0
export(float) var angulo = 45.0
export(float) var sensibilidad_rotacion = 0.3
export(bool) var invertir_x = false
export(bool) var invertir_y = false
# Adding zoom parameters
export(float) var zoom_min = 10.0
export(float) var zoom_max = 700.0
export(float) var zoom_speed = 0.2

var rotacion_y = 0.0
var rotacion_x = 0.0
var clic_derecho_presionado = false

onready var objetivo = get_node(objetivo_path)

func _ready():
	rotacion_y = 0.0
	rotacion_x = deg2rad(angulo)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):
	# Handle right-click for camera rotation
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_RIGHT:
			clic_derecho_presionado = event.pressed
			
			if clic_derecho_presionado:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		# Handle left-click for target movement
		elif event.button_index == BUTTON_LEFT and event.pressed:
			# Create raycast from camera to clicked position
			var from = project_ray_origin(event.position)
			var to = from + project_ray_normal(event.position) * 1000
			
			# Create physics space state to perform the raycast
			var space_state = get_world().direct_space_state
			
			# Perform raycast
			var result = space_state.intersect_ray(from, to, [], 1)
			
			# If raycast hit something
			if result:
				# Move target to hit position
				if objetivo and objetivo.has_method("set_target"):
					objetivo.set_target(result.position)
		
		# NEW CODE: Handle mouse wheel for zoom
		elif event.button_index == BUTTON_WHEEL_UP:
			# Zoom in
			distancia = max(zoom_min, distancia - zoom_speed)
		elif event.button_index == BUTTON_WHEEL_DOWN:
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
	
	global_transform.origin = center + offset
	look_at(center, Vector3.UP)
