extends Camera

export(NodePath) var objetivo_path
export(float) var distancia = 200.0
export(float) var altura = 150.0
export(float) var angulo = 45.0 # grados desde arriba (isométrico)

onready var objetivo = get_node(objetivo_path)

func _process(delta):
	if not objetivo:
		return

	var center = objetivo.call("obtener_centro")
	var radians = deg2rad(angulo)
	
	var offset = Vector3(0, altura, -distancia).rotated(Vector3(1, 0, 0), radians)
	global_transform.origin = center + offset
	look_at(center, Vector3.UP)
