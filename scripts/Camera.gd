extends Camera

export(NodePath) var objetivo_path
export(float) var distancia = 200.0
export(float) var altura = 150.0
export(float) var angulo = 45.0 # grados desde arriba (isométrico)
export(float) var sensibilidad_rotacion = 0.3 # Sensibilidad del giro de la cámara
export(bool) var invertir_x = false
export(bool) var invertir_y = false

# Variables para el movimiento de la cámara
var rotacion_y = 0.0 # Rotación horizontal (alrededor del eje Y)
var rotacion_x = 0.0 # Rotación vertical (alrededor del eje X)
var clic_derecho_presionado = false

onready var objetivo = get_node(objetivo_path)

func _ready():
	# Inicializar rotación inicial
	rotacion_y = 0.0
	rotacion_x = deg2rad(angulo)
	
	# Configurar captura del mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):
	# Detectar cuando se presiona y suelta el botón derecho del mouse
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_RIGHT:
			clic_derecho_presionado = event.pressed
			
			# Cambiar el modo del cursor cuando se presiona el botón derecho
			if clic_derecho_presionado:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Rotar la cámara cuando se mueve el mouse y el botón derecho está presionado
	elif event is InputEventMouseMotion and clic_derecho_presionado:
		# Aplicar sensibilidad e inversión si es necesario
		var factor_x = -1.0 if invertir_x else 1.0
		var factor_y = -1.0 if invertir_y else 1.0
		
		# Calcular la rotación
		rotacion_y += event.relative.x * sensibilidad_rotacion * 0.01 * factor_x
		rotacion_x += event.relative.y * sensibilidad_rotacion * 0.01 * factor_y
		
		# Limitar la rotación vertical para evitar invertir la cámara
		rotacion_x = clamp(rotacion_x, 0.1, PI/2.0)

func _process(delta):
	if not objetivo:
		return
	
	var center = objetivo.call("obtener_centro")
	
	# Calcular la posición basada en distancia, altura y rotación
	var offset = Vector3()
	offset.x = sin(rotacion_y) * distancia * cos(rotacion_x)
	offset.y = sin(rotacion_x) * distancia
	offset.z = cos(rotacion_y) * distancia * cos(rotacion_x)
	
	# Actualizar posición y orientación de la cámara
	global_transform.origin = center + offset
	look_at(center, Vector3.UP)
