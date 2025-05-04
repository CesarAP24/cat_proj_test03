extends Camera

export(NodePath) var objetivo_path
export(float) var distancia = 200.0
export(float) var altura = 150.0
export(float) var angulo = 45.0
export(float) var sensibilidad_rotacion = 0.3 
export(bool) var invertir_x = false
export(bool) var invertir_y = false

var rotacion_y = 0.0 
var rotacion_x = 0.0 
var clic_derecho_presionado = false

onready var objetivo = get_node(objetivo_path)

func _ready():
	rotacion_y = 0.0
	rotacion_x = deg2rad(angulo)
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_RIGHT:
			clic_derecho_presionado = event.pressed
			
			if clic_derecho_presionado:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
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
