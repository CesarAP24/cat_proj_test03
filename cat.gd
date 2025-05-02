extends Spatial

export(NodePath) var objetivo_path

onready var objetivo = get_node(objetivo_path)

func _process(delta):
	if not objetivo:
		return

	var center = objetivo.call("obtener_centro")
	global_transform.origin = center

	var dir = objetivo.call("obtener_direccion")
	
	var angle_y = atan2(dir.x, dir.z)
	global_transform.basis = Basis(Vector3.UP, angle_y)
	rotate_y(deg2rad(-90)) # modelo mira a -X
